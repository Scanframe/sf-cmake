#!/usr/bin/env python3
"""Report dynamic library dependencies.

Supported options:
  -h, --help    Show help
  -c, --check   Resolve each dependency to a directory (LD_LIBRARY_PATH/RUNPATH/ldconfig or PATH)
  -r, --recurse When a dependency is found on disk, inspect its dependencies too
  -a, --app     Windows-only: executable providing the base directory for the lookup

The binaries themselves are parsed directly (pyelftools/pefile) so no 'objdump' is
needed. Resolving does rely on the same external information as the shell script:
the loader configuration cache ('ldconfig -p') on Linux and 'wine'/'winepath' when
inspecting a PE/COFF file from Linux.
"""

from __future__ import annotations
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple
from elftools.elf.elffile import ELFFile
import pefile

# Separator used to build the table rows before they are formatted.
SEPARATOR = "→"
# Marker reported when a dependency could not be resolved.
MISSING = "Missing"


def _init_colors() -> Dict[str, str]:
	"""Create the foreground color map like 'WriteLog.sh' does."""
	term = os.environ.get("TERM", "")
	if not term or term in ("dumb", "unknown") or os.environ.get("CI"):
		return {key: "" for key in ("red", "green", "yellow", "blue", "cyan", "magenta", "reset")}
	return {
		"red": "\x1b[31m",
		"green": "\x1b[32m",
		"yellow": "\x1b[33m\x1b[1m",
		"blue": "\x1b[34m\x1b[1m",
		"cyan": "\x1b[36m",
		"magenta": "\x1b[35m",
		"reset": "\x1b[0m",
	}


# Foreground colors which are empty when coloring is not wanted.
col_fg = _init_colors()
# Colors selected by the first character of a logged line like 'WriteLog' does.
_LOG_COLORS = {"-": "cyan", "~": "blue", "#": "yellow", "=": "green", ":": "magenta", "!": "red"}


def write_log(message: str) -> None:
	"""Write a colorized line to stderr like the 'WriteLog' shell function."""
	stripped = message.lstrip()
	name = _LOG_COLORS.get(stripped[:1] if stripped else "")
	if message.endswith("!"):
		name = "red"
	color = col_fg.get(name, "") if name else ""
	sys.stderr.write(f"{color}{message}{col_fg['reset'] if color else ''}\n")
	sys.stderr.flush()

def is_windows_host() -> bool:
	"""Check whether this script itself runs on Windows or Cygwin."""
	return sys.platform in ("win32", "cygwin") or sys.platform.startswith("msys")


def is_pe_file(path: Path) -> bool:
	"""Check if the file is PE/COFF (Windows) by signature."""
	with open(path, "rb") as stream:
		return stream.read(2) == b"MZ"


def read_runpath(path: Path) -> List[str]:
	"""Return the RUNPATH or when absent the deprecated RPATH entries of an ELF binary."""
	runpath: Optional[str] = None
	rpath: Optional[str] = None
	with open(path, "rb") as stream:
		elf = ELFFile(stream)
		dynamic = elf.get_section_by_name(".dynamic")
		if not dynamic:
			return []
		for tag in dynamic.iter_tags():
			if tag.entry.d_tag == "DT_RUNPATH" and runpath is None:
				runpath = tag.runpath
			elif tag.entry.d_tag == "DT_RPATH" and rpath is None:
				rpath = tag.rpath
	raw = runpath if runpath is not None else rpath
	# Only the first of both entries is used just like the shell script does.
	return [entry for entry in raw.split(":") if entry] if raw else []


def resolve_origin(origin: str, entry: str) -> str:
	"""Replace the ORIGIN place holders with the directory of the inspected binary."""
	return entry.replace("${ORIGIN}", origin).replace("$ORIGIN", origin)


def list_needed(path: Path, dll_mode: bool) -> List[str]:
	"""List the shared library dependencies of an ELF or PE/COFF target."""
	deps: List[str] = []
	if dll_mode:
		image = pefile.PE(str(path), fast_load=True)
		image.parse_data_directories(directories=[
			pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"],
			pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT"],
		])
		for attribute in ("DIRECTORY_ENTRY_IMPORT", "DIRECTORY_ENTRY_DELAY_IMPORT"):
			for entry in getattr(image, attribute, []) or []:
				name = entry.dll.decode("utf-8", "replace") if entry.dll else ""
				if name and name not in deps:
					deps.append(name)
		image.close()
		return deps
	with open(path, "rb") as stream:
		elf = ELFFile(stream)
		dynamic = elf.get_section_by_name(".dynamic")
		if not dynamic:
			return []
		for tag in dynamic.iter_tags():
			if tag.entry.d_tag == "DT_NEEDED":
				deps.append(tag.needed)
	return deps


# Cached mapping of the loader configuration of library name to full path.
_ld_cache: Optional[Dict[str, str]] = None


def ld_config_lookup(name: str) -> Optional[Path]:
	"""Resolve a library name using the loader configuration cache like 'ldconfig -p' reports it."""
	global _ld_cache
	if _ld_cache is None:
		_ld_cache = {}
		executable = shutil.which("ldconfig") or "/sbin/ldconfig"
		try:
			output = subprocess.run([executable, "-p"], capture_output=True, text=True, check=False).stdout
		except OSError:
			output = ""
		for line in output.splitlines():
			# A line looks like: '\tlibc.so.6 (libc6,x86-64) => /lib/x86_64-linux-gnu/libc.so.6'.
			match = re.match(r"^\s*(\S+)\s.*=>\s*(\S.*?)\s*$", line)
			if match and match.group(1) not in _ld_cache:
				_ld_cache[match.group(1)] = match.group(2)
	found = _ld_cache.get(name)
	return Path(found) if found else None


def processed_key(path: Path | str) -> str:
	"""Create the key identifying an already processed file.

	Symbolic links are resolved and the case is normalized so Windows names
	like 'KERNEL32.dll' and 'kernel32.dll' are recognized as the same file.
	"""
	return os.path.normcase(os.path.realpath(str(path)))


def find_case_insensitive(directory: str, name: str) -> Optional[str]:
	"""Look for a file in a directory ignoring the case of its name."""
	wanted = name.lower()
	try:
		with os.scandir(directory) as entries:
			for entry in entries:
				if entry.name.lower() == wanted and entry.is_file():
					return entry.name
	except OSError:
		return None
	return None


def format_table(rows: Sequence[str], columns: Sequence[str]) -> str:
	"""Format the collected rows like 'column --table --separator ... --table-columns ...' does."""
	cells: List[List[str]] = [list(columns)]
	for row in rows:
		fields = row.split(SEPARATOR)
		# Pad up to the amount of columns since a row may hold less fields.
		fields += [""] * (len(columns) - len(fields))
		cells.append(fields[:len(columns)])
	widths = [max(len(row[idx]) for row in cells) for idx in range(len(columns))]
	lines = []
	for row in cells:
		# The last column is not padded by the 'column' command either.
		lines.append("  ".join([field.ljust(widths[idx]) for idx, field in enumerate(row[:-1])] + [row[-1]]))
	text = "\n".join(lines)
	if col_fg["red"]:
		# Colorize after formatting since escape sequences would break the alignment.
		text = re.sub(rf"(^|\s){MISSING}($|\s)", rf"\1{col_fg['red']}{MISSING}{col_fg['reset']}\2", text)
	return text


def table_columns(flag_check: bool) -> Tuple[str, ...]:
	"""Return the table columns which depend on the check flag."""
	return ("Library", "Via", "Directory") if flag_check else ("Library",)


def wine_paths() -> Tuple[List[str], List[str]]:
	"""Return the Wine 'PATH' and 'WINEPATH' directories translated to Unix paths."""

	def to_unix(win_dirs: List[str]) -> List[str]:
		"""Translate Windows directories using 'winepath'."""
		win_dirs = [entry.strip() for entry in win_dirs if entry.strip()]
		if not win_dirs:
			return []
		try:
			result = subprocess.run(["winepath", "-u", *win_dirs], capture_output=True, text=True, check=False)
		except OSError:
			return []
		return [line.rstrip("/") or "/" for line in result.stdout.splitlines() if line.strip()]

	try:
		# Get the default system path from the Wine environment.
		default = subprocess.run(
			["wine", "cmd", "/c", "echo %PATH%"], capture_output=True, text=True, check=False
		).stdout.strip()
	except OSError:
		default = ""
	sys_dirs = to_unix(default.split(";"))
	path_dirs = to_unix(os.environ.get("WINEPATH", "").split(";"))
	return path_dirs, sys_dirs


def handle_windows(
	targets: Sequence[Path],
	flag_check: bool,
	flag_recurse: bool,
	app_bin: Optional[str],
) -> None:
	"""Handle dependency reporting for PE/COFF targets on Windows/Cygwin or through Wine."""
	app_dir = ""
	# When an application is passed get its executable directory.
	if app_bin:
		app_dir = str(Path(app_bin).resolve().parent)
		write_log(f"# Executable path app: {app_bin}")
		write_log(f"- {app_dir}")
	if is_windows_host():
		# Get the PATH as a list of directories.
		path_dirs = [entry for entry in os.environ.get("PATH", "").split(os.pathsep) if entry]
		sys_dirs: List[str] = []
	else:
		path_dirs, sys_dirs = wine_paths()
	if flag_check:
		write_log("# Paths:")
		for directory in path_dirs:
			write_log(f"- {directory}")
	# Keys of the files reported on to prevent endless recursion on circular dependencies.
	processed: set = set()

	def process(files: Sequence[Path]) -> None:
		"""Report the dependencies of the passed files in a single table and recurse when requested."""
		rows: List[str] = []
		recurse_queue: List[str] = []
		for target in files:
			# Skip the ones already reported on.
			key = processed_key(target)
			if key in processed:
				continue
			processed.add(key)
			write_log(f"# Checking: {target}")
			for dep in list_needed(target, dll_mode=True):
				if not flag_check:
					rows.append(dep)
					continue
				found = 0
				if app_dir:
					candidate = os.path.join(app_dir, dep)
					if os.path.isfile(candidate):
						rows.append(f"{dep}{SEPARATOR}EXE_DIR{SEPARATOR}{app_dir}")
						found = 1
						if flag_recurse:
							recurse_queue.append(candidate)
				# When not found continue...
				if found == 0:
					for directory in path_dirs:
						candidate = os.path.join(directory, dep)
						if os.path.isfile(candidate):
							rows.append(f"{dep}{SEPARATOR}PATH{SEPARATOR}{directory}")
							found = 2
							if flag_recurse:
								recurse_queue.append(candidate)
							break
				# When not found continue...
				if found == 0:
					for directory in sys_dirs:
						if os.path.isfile(os.path.join(directory, dep)):
							rows.append(f"{dep}{SEPARATOR}SYS_PATH{SEPARATOR}{directory}")
							found = 3
							# Not recursing into system libraries on purpose.
							break
				# When not found continue by ignoring the case of the name...
				if found == 0:
					for directory in sys_dirs:
						result = find_case_insensitive(directory, dep)
						if result:
							rows.append(
								f"{dep}{SEPARATOR}SYS_PATH{SEPARATOR}{directory}"
								f" [{col_fg['yellow']}{result}{col_fg['reset']}]"
							)
							found = 4
							break
				if found == 0:
					rows.append(f"{dep}{SEPARATOR}{MISSING}{SEPARATOR}")
		if rows:
			print(format_table(rows, table_columns(flag_check)))
		# When recursing is requested.
		if flag_recurse:
			for dep_path in recurse_queue:
				# Skip the ones already reported on.
				if processed_key(dep_path) in processed:
					continue
				write_log(f"# Recursing through: {dep_path}")
				process([Path(dep_path)])

	process(targets)


def handle_linux(
	targets: Sequence[Path],
	flag_check: bool,
	flag_recurse: bool,
) -> None:
	"""Handle dependency reporting for ELF targets on Linux."""
	ld_path_dirs: List[str] = []
	# Check if the environment variable 'LD_LIBRARY_PATH' was set.
	if flag_check and os.environ.get("LD_LIBRARY_PATH"):
		entries = [entry for entry in os.environ["LD_LIBRARY_PATH"].split(":") if entry]
		if entries:
			write_log("# Loader Paths:")
		for entry in entries:
			# Check if the path directory is absolute.
			if os.path.isabs(entry):
				write_log(f"- {entry}")
				ld_path_dirs.append(entry)
			else:
				# Prepend the working directory.
				resolved = os.path.join(os.getcwd(), entry)
				write_log(f"- {entry} => {resolved}")
				ld_path_dirs.append(resolved)
	# Keys of the files reported on to prevent endless recursion on circular dependencies.
	processed: set = set()

	def process_one(bin_path: Path) -> None:
		"""Report the dependencies of a single ELF file and recurse when requested."""
		# Skip the ones already reported on.
		key = processed_key(bin_path)
		if key in processed:
			return
		processed.add(key)
		write_log(f"# File RUNPATH: {bin_path}")
		origin = str(Path(bin_path).resolve().parent)
		run_path_dirs: List[str] = []
		for entry in read_runpath(bin_path):
			resolved = resolve_origin(origin, entry)
			if resolved == entry:
				write_log(f"- {entry}")
			else:
				write_log(f"- {entry} => {resolved}")
			run_path_dirs.append(resolved)
		write_log("# Paths:")
		for directory in [*ld_path_dirs, *run_path_dirs]:
			write_log(f"- {directory}")
		# Report which file is checked.
		write_log(f"# Checking: {bin_path}")
		rows: List[str] = []
		recurse_queue: List[str] = []
		for dep in list_needed(bin_path, dll_mode=False):
			if not flag_check:
				rows.append(dep)
				continue
			found = 0
			for directory in ld_path_dirs:
				candidate = os.path.join(directory, dep)
				if os.path.isfile(candidate):
					rows.append(f"{dep}{SEPARATOR}LD_PATH{SEPARATOR}{os.path.dirname(candidate)}")
					found = 1
					if flag_recurse:
						recurse_queue.append(candidate)
					break
			# When not found continue...
			if found == 0:
				for directory in run_path_dirs:
					candidate = os.path.join(directory, dep)
					if os.path.isfile(candidate):
						rows.append(f"{dep}{SEPARATOR}RUNPATH{SEPARATOR}{os.path.dirname(candidate)}")
						found = 2
						if flag_recurse:
							recurse_queue.append(candidate)
						break
			# When not found continue...
			if found == 0:
				candidate_path = ld_config_lookup(dep)
				if candidate_path:
					rows.append(f"{dep}{SEPARATOR}LD_CONF{SEPARATOR}{candidate_path.parent}")
					found = 3
					# Not recursing into system libraries on purpose.
			if found == 0:
				rows.append(f"{dep}{SEPARATOR}{MISSING}{SEPARATOR}")
		if rows:
			print(format_table(rows, table_columns(flag_check)))
		# When recursing is requested.
		if flag_recurse:
			for dep_path in recurse_queue:
				# Skip the ones already reported on.
				if processed_key(dep_path) in processed:
					continue
				write_log(f"# Recursing through: {dep_path}")
				process_one(Path(dep_path))

	for target in targets:
		process_one(target)


def parse_args(argv: Sequence[str]) -> Optional[argparse.Namespace]:
	"""Parse the CLI arguments."""
	parser = argparse.ArgumentParser(add_help=False)
	parser.add_argument("files", nargs="*")
	parser.add_argument("-h", "--help", action="store_true", default=False, help="Shows the command's help.")
	parser.add_argument("-c", "--check", action="store_true", help="Check if the DLLs can be found in the path.")
	parser.add_argument("-r", "--recurse", action="store_true", help="Do a recursive check on all libraries.")
	parser.add_argument("-a", "--app", metavar="APP", help="Application or library which provides Windows executable directory (Windows targets only).")
	args = parser.parse_args(argv)
	if args.help:
		parser.print_help()
		sys.exit(0)
	if not args.files:
		parser.print_help()
		return None
	return args


def main(argv: Sequence[str]) -> int:
	"""CLI entry point."""
	args = parse_args(argv)
	if args is None:
		return 1
	targets = [Path(file) for file in args.files]
	for target in targets:
		if not target.exists():
			write_log(f"File '{target}' not found!")
			return 1
	# Determine if Windows or Linux is targeted.
	flag_win = is_windows_host() or is_pe_file(targets[0])
	if flag_win:
		handle_windows(targets, args.check, args.recurse, args.app)
	else:
		handle_linux(targets, args.check, args.recurse)
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))

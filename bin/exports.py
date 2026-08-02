#!/usr/bin/env python3
"""
List the exported symbols of any binary file.
It determines what kind of file it is based on extension and a magic number when needed.

Usage:
  exports.py <lib-file>
"""

import sys
import subprocess
import os
import re
import pefile


def get_file_type(file_path: str) -> str:
	"""
	Detect the type of executable file based on its magic number.
	:param file_path: Path to the file to be checked.
	:return: A string indicating the type of the file, or an error message.
	"""
	try:
		with open(file_path, "rb") as f:
			magic = f.read(8)
			if magic.startswith(b"MZ"):
				# Windows binary.
				return "PE"
			elif magic.startswith(b"\x7fELF"):
				# Linux binary.
				return "ELF"
			elif magic.startswith(b"!<arch>\n"):
				return "ARC"
			elif magic.startswith(b"\x00\x00\xFF\xFF"):
				# Windows library file.
				return "LIB"
			else:
				return None;
	except IOError:
		return None


def run_command(cmd_list):
	"""Run a command and return its standard output as text.

	Args:
			cmd_list: Command and arguments as a list, passed to subprocess.

	Returns:
			The decoded standard output, or an empty string when the command
			exits with a non-zero status. Standard error is discarded.
	"""
	try:
		return subprocess.check_output(cmd_list, stderr=subprocess.DEVNULL).decode('utf-8')
	except subprocess.CalledProcessError:
		return ""


def main():
	"""List the exported symbols of the library or executable given on the command line.

	Exits with status 1 when the argument is missing, the file does not exist,
	or a required external command is unavailable.
	"""
	if len(sys.argv) < 2:
		print(f"Usage: {sys.argv[0]} <lib-file>")
		sys.exit(1)

	lib_file = sys.argv[1]
	if not os.path.exists(lib_file):
		print(f"File not found: {lib_file}")
		sys.exit(1)

	# Detect extension
	match = re.search(r'\.([a-zA-Z0-9]+)$', lib_file)
	ext = match.group(1) if match else ""

	file_type = get_file_type(lib_file)
	print(f"Exports of file ({file_type}): {lib_file}")

	# Detect executable if no extension
	if not ext:
		if file_type == "ELF":
			ext = "bin"
		else:
			file_mime = subprocess.check_output(["file", "-bi", lib_file]).decode('utf-8').strip()
			if "application/x-pie-executable" in file_mime:
				ext = "bin"

	if ext == 'a':
		nm_out = run_command(["nm", "--extern-only", "--demangle", lib_file])
		# Sort and filter.
		lines = sorted(list(set(nm_out.splitlines())), reverse=True)
		for line in lines:
			# Only print exported global/external (T) functions.
			if match := re.match(r'^[0-9a-f]* T (.*$)', line):
				print(match.group(1))

	if ext == 'lib':
		nm_out = run_command(["x86_64-w64-mingw32-nm", "--defined-only", "--demangle", lib_file])
		# Sort and filter.
		lines = sorted(list(set(nm_out.splitlines())), reverse=True)
		for line in lines:
			# Only print exported global/external (T) functions.
			if match := re.match(r'^[0-9a-f]* T (.*$)', line):
				print(match.group(1))

	elif ext in ['so', 'bin']:
		cmd = ["nm", "--demangle", "--dynamic", "--defined-only", "--extern-only", lib_file]
		nm_out = run_command(cmd)
		lines = sorted(list(set(nm_out.splitlines())), reverse=True)
		for line in lines:
			# Only print exported non-weak (W) functions resulting in global/external (T) only.
			if match := re.match(r'^[0-9a-f]* [^W] (.*$)', line):
				print(match.group(1))

	elif ext in ['dll', 'exe']:
		# An option is to use when 'pefile' is not available.
		# print(run_command(["winedump", "-C", "-j", "export", lib_file]))
		pe = pefile.PE(lib_file)
		if hasattr(pe, 'DIRECTORY_ENTRY_EXPORT'):
			for exp in pe.DIRECTORY_ENTRY_EXPORT.symbols:
				if exp.name:
					print(exp.name.decode('utf-8'))
		else:
			print("No export table found in this file.")

	else:
		print(f"Extension '.{ext}' not implemented.")


if __name__ == "__main__":
	main()

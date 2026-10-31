#!/usr/bin/env python3
# coding=utf-8
"""
Test subcommand for build.py.

Executes a matrix of build and run tests across toolchains, build types,
and applications.  Configuration is read from the [test-cmd] section of
build.ini.  The command is only available at the top level — it does not
register when running inside Docker or Wine.
"""

import argparse
import hashlib
import os
import sys
import time
from typing import Dict, List
from pathlib import Path

# Use the already-loaded 'build' module from sys.modules to avoid re-importing
# the module-level code (which would create a second config and separate registry).
# When run as './build.py', the module key is '__main__', not 'build'.
build_module = sys.modules.get("build") or sys.modules.get("__main__")
if build_module is None:
	raise ImportError(
		"build-test requires 'build' to be imported first. "
		"This module should only be loaded via _load_subcommand_modules()."
	)
# Fake import to trick IDE.
if build_module is None:
	import build as main
else:
	main = build_module


class SubCommandTest(main.SubCommand):
	"""Subcommand handler for the 'test' command — matrix build & run tests."""

	# The log file is named after this module, placed in main.RUN_DIR.
	_log_file = Path(os.path.join(main.RUN_DIR, str(os.path.splitext(os.path.basename(__file__))[0]) + ".log"))

	# Configuration variables populated in handle() from [config-test] section.
	build_types: List[str] = []
	apps_linux: List[str] = []
	apps_windows: List[str] = []
	build_arguments: str = ""
	run_arguments: str = ""
	wine_arguments: str = ""
	docker_arguments: str = ""

	# Cached matrix tuple: (matrix, descriptions, platforms).
	_cached_matrix: tuple = None

	def __init__(self):
		super().__init__("test")

	@staticmethod
	def _parse_matrix_kv(kv: Dict[str, str], source: str) -> tuple:
		"""
		Parse a flat key-value dict into the matrix structure, profile descriptions, and platforms.

		Key formats:
		  `<profile>/<index>/<attribute>=<value>` for group configs (e.g., win/0/wrapper=native)
		  `<profile>/description=<value>` for profile-level descriptions
		  `<profile>/platform=<value>` for profile-level platform requirements

		:param kv: A dict mapping matrix keys to their string values.
		:param source: A label for logging (e.g., '[config-test-matrix]' or 'hardcoded defaults').
		:return: A tuple (matrix, descriptions, platforms) where matrix maps profile to group configs,
			descriptions maps profile to its description string, and platforms maps profile to its required platform.
		"""
		matrix: Dict[str, List[dict]] = {}
		descriptions: Dict[str, str] = {}
		platforms: Dict[str, str] = {}
		for key, value in kv.items():
			parts = key.split("/")
			if len(parts) == 2 and parts[1] == "description":
				# Profile-level description (e.g., "lnx/description").
				descriptions[parts[0]] = value
				continue
			if len(parts) == 2 and parts[1] == "platform":
				# Profile-level platform requirement (e.g., "dck/platform").
				platforms[parts[0]] = value
				continue
			if len(parts) != 3:
				main.logger.warning(f"! Skipping malformed matrix key: {key}")
				continue
			profile, idx_str, attr = parts
			try:
				idx = int(idx_str)
			except ValueError:
				main.logger.warning(f"! Invalid index in matrix key {key}: {idx_str}")
				continue

			matrix.setdefault(profile, [])
			# Ensure the group list is long enough.
			while len(matrix[profile]) <= idx:
				matrix[profile].append({"wrapper": "", "toolchain": "", "build_types": []})

			group = matrix[profile][idx]
			if attr == "build_types":
				group[attr] = [v.strip() for v in value.split(",") if v.strip()]
			else:
				group[attr] = value

		# Validate that all required attributes are present.
		for profile, groups in matrix.items():
			for idx, group in enumerate(groups):
				for required_attr in ("wrapper", "toolchain", "build_types"):
					if not group.get(required_attr):
						main.logger.warning(
							f"! Missing '{required_attr}' for {profile}/{idx} in {source}"
						)
		return matrix, descriptions, platforms

	@staticmethod
	def _build_matrix() -> tuple:
		"""
		Build the configuration matrix for all profiles, caching the result.

		If the matrix has already been built, return the cached tuple.
		Otherwise, build and cache it.
		"""
		if SubCommandTest._cached_matrix is not None:
			return SubCommandTest._cached_matrix

		result = SubCommandTest._build_matrix_uncached()
		SubCommandTest._cached_matrix = result
		return result

	@staticmethod
	def _build_matrix_uncached() -> tuple:
		"""
		Build the configuration matrix for all profiles.

		If `[config-test-matrix]` section exists in build.ini, parse the full
		matrix from it.  Otherwise, fall back to hardcoded defaults stored
		as a flat Dict[str, str] — both paths use the same parser.

		Returns a tuple (matrix, descriptions, platforms) where matrix maps profile name
		to a list of group configurations, descriptions maps profile name to its description
		string, and platforms maps profile name to its required platform.
		"""
		# Try to read the full matrix from '[config-test-matrix]'.
		sec_name = "config-test-matrix"
		if main.CONFIG.has_section(sec_name):
			sec = main.get_config_section(sec_name, fail=False)
			main.logger.info(f"# Matrix configuration loaded from ini-section '{sec_name}'.")
			return SubCommandTest._parse_matrix_kv(dict(sec), sec_name)
		# Hardcoded defaults as flat Dict[str, str], parsed the same way.
		defaults: Dict[str, str] = {
			# Linux profile – native + cross-compile + Wine.
			"lnx/platform": "linux",
			"lnx/description": "Linux native builds including Windows using Wine.",
			#---
			"lnx/0/toolchain": "gnu",
			"lnx/0/wrapper": "native",
			"lnx/0/build_types": "debug,release,coverage",
			#---
			"lnx/1/toolchain": "gw",
			"lnx/1/wrapper": "native",
			"lnx/1/build_types": "debug,release,coverage",
			#---
			"lnx/2/wrapper": "wine",
			"lnx/2/toolchain": "mingw",
			"lnx/2/build_types": "debug,release",
			#---
			"lnx/3/toolchain": "msvc",
			"lnx/3/wrapper": "wine",
			"lnx/3/build_types": "debug,release",

			# Docker profile – only available on Linux.
			"dck/platform": "linux",
			"dck/description": "All Docker possible Linux builds including Windows using Wine and arm64 builds.",
			#---
			"dck/0/toolchain": "gnu",
			"dck/0/wrapper": "docker",
			"dck/0/build_types": "debug,release,coverage",
			#---
			"dck/1/toolchain": "gw",
			"dck/1/wrapper": "docker",
			"dck/1/build_types": "debug,release,coverage",
			#---
			"dck/2/toolchain": "ga",
			"dck/2/wrapper": "docker",
			"dck/2/build_types": "debug,release",
			#---
			"dck/3/wrapper": "docker_wine",
			"dck/3/toolchain": "mingw",
			"dck/3/build_types": "debug,release",
			#---
			"dck/4/wrapper": "docker_wine",
			"dck/4/toolchain": "msvc",
			"dck/4/build_types": "debug,release",

			# Windows profile – native builds.
			"win/platform": "win32",
			"win/description": "All Windows only builds.",
			#---
			"win/0/wrapper": "native",
			"win/0/toolchain": "msvc",
			"win/0/build_types": "debug,release",
			#---
			"win/1/wrapper": "native",
			"win/1/toolchain": "mingw",
			"win/1/build_types": "debug,release",
		}
		main.logger.info(f"# Matrix configuration loaded from hardcoded defaults")
		return SubCommandTest._parse_matrix_kv(defaults, "hardcoded defaults")

	@staticmethod
	def detect_profile() -> List[str]:
		"""Return all profiles whose platform matches the current system."""
		_, _, platforms = SubCommandTest._build_matrix()
		matching = [profile for profile, required in platforms.items() if sys.platform == required]
		return matching if matching else ["unknown"]

	def load_log(self) -> set:
		"""Load previously successful command hashes from the log file."""
		if not self._log_file.exists():
			return set()
		try:
			text = self._log_file.read_text(encoding="utf-8")
			return {line.strip() for line in text.splitlines() if line.strip()}
		except OSError:
			return set()

	def save_log(self, hash_value: str, cmd_str: str, elapsed: float) -> None:
		"""Append a timed comment line and a successful command hash to the log file, then flush to disk."""
		hours, remainder = divmod(int(elapsed), 3600)
		minutes, seconds = divmod(remainder, 60)
		time_str = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
		try:
			with open(self._log_file, "a", encoding="utf-8") as f:
				f.write(f"# {time_str} | {cmd_str}\n")
				f.write(f"{hash_value}\n")
				f.flush()
				os.fsync(f.fileno())
		except OSError as e:
			main.logger.error(f"! Could not write to log file: {e}")

	@staticmethod
	def command_hash(cmd: List[str]) -> str:
		"""Generate a stable hash string for a command."""
		cmd_str = " ".join(cmd)
		return hashlib.sha256(cmd_str.encode("utf-8")).hexdigest()

	@staticmethod
	def split_arguments(args: str) -> List[str]:
		"""Split an arguments string into a list."""
		return args.split(' ') if args else []

	def write_matrix_file(self, filepath: str) -> int:
		"""Write the current matrix configuration to a new INI file with a header.

		Returns 0 on success, 1 if the file already exists or cannot be written.
		"""
		from pathlib import Path
		out_path = Path(filepath)
		if out_path.exists():
			main.logger.error(f"! File already exists: {filepath}")
			return 1
		# Read the current [config-test] section.
		test_config = main.get_config_section("config-test", fail=False)
		# Build the matrix from the current configuration or defaults.
		matrix, descriptions, platforms = self._build_matrix()
		# Collect all matrix keys in a deterministic order.
		lines = []
		lines.append("# Test matrix configuration for build.py")
		lines.append("# Generated by: build.py test --file <filename>")
		lines.append("#")
		lines.append("# This file contains two sections:")
		lines.append("#   [config-test]       - Test command configuration (build types, apps, arguments)")
		lines.append("#   [config-test-matrix] - Build matrix definition (profiles, wrappers, toolchains)")
		lines.append("")
		# [config-test] section.
		lines.append("[config-test]")
		if test_config:
			for key, value in test_config.items():
				lines.append(f"{key} = {value}")
		else:
			lines.append("build_types = debug,release,coverage")
			lines.append("apps_linux = ./hello-world.bin")
			lines.append("apps_windows = hello-world.exe")
			lines.append("build_arguments = native --build")
			lines.append("run_arguments = --preset")
			lines.append("wine_arguments = ")
			lines.append("docker_arguments = --build-dir prj")
		lines.append("")
		# [config-test-matrix] section.
		lines.append("[config-test-matrix]")
		lines.append("# Profile configurations: <profile>/<index>/<attribute> = <value>")
		lines.append("# Profiles are groups of build configurations for a specific platform.")
		# Sort profiles for deterministic output.
		for profile in sorted(matrix.keys()):
			# Profile-level metadata.
			if profile in descriptions:
				lines.append(f"{profile}/description = {descriptions[profile]}")
			if profile in platforms:
				lines.append(f"{profile}/platform = {platforms[profile]}")
			# Group configurations.
			for idx, group in enumerate(matrix[profile]):
				lines.append(f"{profile}/{idx}/wrapper = {group['wrapper']}")
				lines.append(f"{profile}/{idx}/toolchain = {group['toolchain']}")
				lines.append(f"{profile}/{idx}/build_types = {','.join(group['build_types'])}")
		lines.append("")
		try:
			out_path.write_text("\n".join(lines), encoding="utf-8")
			main.logger.info(f"= Matrix configuration written to: {filepath}")
			return 0
		except OSError as e:
			main.logger.error(f"! Could not write to file: {e}")
			return 1

	def create_parser(self, subparsers):
		"""Create the parser for the test subcommand."""
		self.parser = subparsers.add_parser(
			self.command,
			aliases=self.aliases,
			add_help=False,
			formatter_class=argparse.RawTextHelpFormatter,
			help="Execute a matrix of build and run tests.",
			description="Builds and runs applications across toolchains, build types, and profiles."
		)
		self.parser.epilog = f"""
examples:

  Run tests for the auto-detected profile:
    {main.SubCommand.script} {self.command} -r

  Show all commands for all profiles:
    {main.SubCommand.script} {self.command} -r -i

  Run in Docker profile (Linux only):
    {main.SubCommand.script} {self.command} -r --profile dck

  Stop on first failure:
    {main.SubCommand.script} {self.command} -r -x

  Configuration is read from the [config-test] section of build.ini.
  The build matrix is defined in the [config-test-matrix] section.
"""
		if self.parser is None:
			raise ValueError("Parser cannot be None")
		return self.parser

	def options(self, parser):
		"""Add options to the test subcommand parser."""
		super().options(parser)
		parser.add_argument("-r", "--run", action="store_true",
			help="Execute the build and test matrix (default: show help).")
		parser.add_argument("-V", "--verbose", action="store_true", help="Enable verbose output.")
		parser.add_argument("-i", "--info", action="store_true",
			help="Display information on all commands for all profiles.")
		# Derive available profiles dynamically from the matrix configuration.
		matrix, descriptions, _ = SubCommandTest._build_matrix()
		# Build help text with profile descriptions, one per line.
		profile_help_lines = ["Override auto-detected profile:"]
		for profile_key in matrix.keys():
			desc = descriptions.get(profile_key, profile_key)
			profile_help_lines.append(f"  {profile_key} - {desc}")
		profile_help = "\n".join(profile_help_lines)
		parser.add_argument("-p", "--profile", choices=list(matrix.keys()), default=None, help=profile_help)
		parser.add_argument("-f", "--file", default=None,
			help="Write the current matrix configuration to a new ini-file (will not overwrite).")
		parser.add_argument("-x", "--stop-on-fail", action="store_true", dest="stop_on_fail",
			help="Stop execution on the first failure."
		)
		return parser

	def handle(self, args: argparse.Namespace, args_left: List[str], args_right: List[str] | None) -> int:
		"""Handle the 'test' subcommand execution."""
		super().handle(args, args_left, args_right)

		# If --file is passed, write the matrix configuration and exit.
		if args.file:
			return self.write_matrix_file(args.file)
		# If --run is not passed, show short help and exit.
		if not args.run:
			self.print_help()
			return 0
		# Verbose mode.
		if args.verbose:
			main.logger.setLevel(main.logging.DEBUG)
		# Read configuration from '[config-test]' section.
		test_config = main.get_config_section("config-test", fail=True)
		# Parse configuration values into instance variables.
		self.build_types = [t.strip() for t in test_config.get("build_types", "debug,release,coverage").split(",")
			if t.strip()]
		self.apps_linux = [a.strip() for a in test_config.get("apps_linux", "./hello-world.bin").split(",") if a.strip()]
		self.apps_windows = [a.strip() for a in test_config.get("apps_windows", "hello-world.exe").split(",") if a.strip()]
		self.build_arguments = test_config.get("build_arguments", "native --build")
		self.run_arguments = test_config.get("run_arguments", "--preset")
		self.wine_arguments = test_config.get("wine_arguments", "")
		self.docker_arguments = test_config.get("docker_arguments", "--build-dir prj")
		# Determine the active profile(s).
		if args.profile:
			profiles = [args.profile]
		else:
			profiles = self.detect_profile()
		#
		if profiles == ["unknown"]:
			main.logger.error("! Unsupported platform. Use -e to specify a profile.")
			return 1
		# Build the configuration matrix from [config-test-matrix] or hardcoded defaults.
		matrix, _, platforms = self._build_matrix()
		# Validate that the current system matches each profile's required platform.
		for profile in profiles:
			required_platform = platforms.get(profile)
			if required_platform and sys.platform != required_platform:
				main.logger.error(
					f"! Profile '{profile}' requires platform '{required_platform}', but current is '{sys.platform}'.")
				return 1
		# --info mode: show all profiles.
		if args.info:
			matrix, descriptions, platforms = self._build_matrix()
			return self.show_info("all", matrix, descriptions, platforms)
		# Load the success log.
		successful = self.load_log()
		# Execute the matrix for each selected profile.
		failed_count = 0
		skipped_count = 0
		success_count = 0
		start_time = time.time()
		#
		for profile in profiles:
			main.logger.info(f"# Executing matrix for profile: {profile}")
			groups = matrix[profile]
			for idx_g, group in enumerate(groups, 1):
				wrapper = group["wrapper"]
				toolchain = group["toolchain"]
				group_build_types = group["build_types"]
				# Determine apps based on toolchain.
				apps = self._select_apps(toolchain)
				main.logger.info(f"# === Group {idx_g}: toolchain={toolchain} wrapper='{wrapper}'")
				# Iterate over the intersection of group build types and configured build types.
				for bt in list(set(group_build_types).intersection(self.build_types)):
					preset = f"{toolchain}-{bt}"
					# --- Build step ---
					bcmd_str = f"{self.build_arguments} {preset}"
					bhash = self.command_hash([bcmd_str])
					main.logger.info(f"# [{preset}] BUILD hash: {bhash}")
					if bhash in successful:
						main.logger.info(f"~ [{preset}] BUILD: Skipping (already succeeded).")
						main.logger.info(f"- {bcmd_str}")
						skipped_count += 1
					else:
						main.logger.info(f"# [{preset}] Building with preset '{preset}'...")
						t0 = time.time()
						rc = self._do_build(wrapper, preset)
						if rc == 0:
							self.save_log(bhash, bcmd_str, time.time() - t0)
							success_count += 1
							main.logger.info(f"# [{preset}] Build succeeded.")
						else:
							main.logger.error(f"! [{preset}] Build failed with exit code {rc}.")
							failed_count += 1
							if args.stop_on_fail:
								return 1
							continue
					# --- Run step for each application ---
					for app in apps:
						rcmd_str = f"run -p {preset} -- {app}"
						rhash = self.command_hash([rcmd_str])
						main.logger.info(f"# [{preset}] RUN hash: {rhash}")
						if rhash in successful:
							main.logger.info(f"# [{preset}] RUN: Skipping (already succeeded).")
							main.logger.info(f"= {rcmd_str}")
							skipped_count += 1
						else:
							main.logger.info(f"# [{preset}] Running application '{app}'...")
							t0 = time.time()
							rc = self._do_run(wrapper, preset, app)
							if rc == 0:
								self.save_log(rhash, rcmd_str, time.time() - t0)
								success_count += 1
								main.logger.info(f"= [{preset}] Run '{app}' succeeded.")
							else:
								main.logger.error(f"! [{preset}] Run '{app}' failed with exit code {rc}.")
								failed_count += 1
								if args.stop_on_fail:
									return 1
		# Summary.
		main.logger.info(f"= Summary: {success_count} succeeded, {skipped_count} skipped, {failed_count} failed.")
		elapsed = time.time() - start_time
		main.logger.info(f"= Elapsed time: {elapsed:.1f}s")
		return 1 if failed_count > 0 else 0

	def _select_apps(self, toolchain: str) -> List[str]:
		"""Select the appropriate app list based on the toolchain."""
		# Windows-targeting toolchains use Windows apps.
		windows_toolchains = {"msvc", "mingw", "gw"}
		if toolchain in windows_toolchains:
			return self.apps_windows
		return self.apps_linux

	def _do_build(self, wrapper: str, preset: str) -> int:
		"""
		Invoke a build step using the appropriate subcommand class.
		Wrappers: 'native', 'wine', 'docker', 'docker_wine'.
		"""
		args = self.split_arguments(self.build_arguments)
		if wrapper == "native":
			return self._build_native(preset, args)
		elif wrapper == "wine":
			return self._build_wine(preset, args)
		elif wrapper == "docker":
			return self._build_docker(preset, args)
		elif wrapper == "docker_wine":
			return self._build_docker_wine(preset, args)
		else:
			main.logger.error(f"! Unknown wrapper: {wrapper}")
			return 1

	def _build_native(self, preset: str, build_arguments: List[str]) -> int:
		"""Build using SubCommandNative."""
		native_cmd = main.SubCommandNative()
		if build_arguments[0] in [native_cmd.command] + self.aliases:
			build_arguments = build_arguments[1:]
		args_list = list(build_arguments) + [preset]
		cmd_args = native_cmd.parse_args(args_list, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse native build args for preset '{preset}'.")
			return 1
		return native_cmd.handle(cmd_args, args_list, None)

	def _build_wine(self, preset: str, build_arguments: List[str]) -> int:
		"""Build using SubCommandWine wrapping SubCommandNative."""
		wine_cmd = main.SubCommandWine()
		# Wine options go in args_left; the build command goes in args_right.
		args_left = self.split_arguments(self.wine_arguments)
		args_right = list(build_arguments) + [preset]
		cmd_args = wine_cmd.parse_args(args_left, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse wine build args for preset '{preset}'.")
			return 1
		return wine_cmd.handle(cmd_args, args_left, args_right)

	def _build_docker(self, preset: str, build_arguments: List[str]) -> int:
		"""Build using SubCommandDocker."""
		docker_cmd = main.SubCommandDocker()
		args_left = self.split_arguments(self.docker_arguments)
		# Docker subcommand passes args_right to the container.
		args_list = list(build_arguments) + [preset]
		cmd_args = docker_cmd.parse_args(args_left, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse docker build args for preset '{preset}'.")
			return 1
		return docker_cmd.handle(cmd_args, args_left, args_list)

	def _build_docker_wine(self, preset: str, build_arguments: List[str]) -> int:
		"""Build using SubCommandDocker wrapping Wine."""
		docker_cmd = main.SubCommandDocker()
		# Docker options go in args_left; Wine + build command go in args_right.
		args_left = self.split_arguments(self.docker_arguments)
		args_right = ["wine", "--"] + list(build_arguments) + [preset]
		cmd_args = docker_cmd.parse_args(args_left, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse docker+wine build args for preset '{preset}'.")
			return 1
		return docker_cmd.handle(cmd_args, args_left, args_right)

	def _do_run(self, wrapper: str, preset: str, app: str) -> int:
		"""
		Invoke a run step using the appropriate subcommand class.
		Wrappers: 'native', 'wine', 'docker', 'docker_wine'.
		"""
		if wrapper == "native":
			return self._run_native(preset, app)
		elif wrapper == "wine":
			return self._run_wine(preset, app)
		elif wrapper == "docker":
			return self._run_docker(preset, app)
		elif wrapper == "docker_wine":
			return self._run_docker_wine(preset, app)
		else:
			main.logger.error(f"! Unknown wrapper: {wrapper}")
			return 1

	def _run_native(self, preset: str, app: str) -> int:
		"""Run using SubCommandRun."""
		run_cmd = main.SubCommandRun()
		args_list = ["run"] + self.split_arguments(self.run_arguments) + [preset]
		args_list += ["--", app]
		cmd_args = run_cmd.parse_args(args_list, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse run args for preset '{preset}' app '{app}'.")
			return 1
		# Split on '--' for args_left / args_right.
		args_left, args_right = main.split_arguments(args_list)
		return run_cmd.handle(cmd_args, args_left, args_right if args_right else None)

	def _run_wine(self, preset: str, app: str) -> int:
		"""Run using SubCommandWine wrapping SubCommandRun."""
		wine_cmd = main.SubCommandWine()
		# Wine options go in args_left; the run command goes in args_right.
		args_left = self.split_arguments(self.wine_arguments)
		args_list = ["run"] + self.split_arguments(self.run_arguments) + [preset, "--", app]
		cmd_args = wine_cmd.parse_args(args_left, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse wine run args for preset '{preset}' app '{app}'.")
			return 1
		return wine_cmd.handle(cmd_args, args_left, args_list)

	def _run_docker(self, preset: str, app: str) -> int:
		"""Run using SubCommandDocker."""
		docker_cmd = main.SubCommandDocker()
		args_left = self.split_arguments(self.docker_arguments)
		args_list = ["run"] + self.split_arguments(self.run_arguments) + [preset, "--", app]
		cmd_args = docker_cmd.parse_args(args_left, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse docker run args for preset '{preset}' app '{app}'.")
			return 1
		return docker_cmd.handle(cmd_args, args_left, args_list)

	def _run_docker_wine(self, preset: str, app: str) -> int:
		"""Run using SubCommandDocker wrapping Wine."""
		docker_cmd = main.SubCommandDocker()
		# Docker options go in args_left; Wine + run command go in args_right.
		args_left = self.split_arguments(self.docker_arguments)
		args_right = ["wine"] + self.split_arguments(self.wine_arguments) + ["--"]
		args_right += ["run"] + self.split_arguments(self.run_arguments) + [preset, "--", app]
		cmd_args = docker_cmd.parse_args(args_left, False)
		if cmd_args is None:
			main.logger.error(f"! Failed to parse docker+wine run args for preset '{preset}' app '{app}'.")
			return 1
		return docker_cmd.handle(cmd_args, args_left, args_right)

	def show_info(self, profile_filter: str, matrix: Dict[str, List[dict]], descriptions: Dict[str, str],
		platforms: Dict[str, str]) -> int:
		"""Display all commands that would be executed."""
		profiles = [profile_filter] if profile_filter != "all" else list(matrix.keys())
		#
		for profile_name in profiles:
			if profile_name not in matrix:
				main.logger.error(f": Profile not configured: {profile_name}")
				continue
			desc = descriptions.get(profile_name, profile_name)
			plat = platforms.get(profile_name, "?")
			main.logger.info(f"# Profile: '{profile_name}/{plat}': {desc}")
			groups = matrix[profile_name]
			for idx_g, group in enumerate(groups, 1):
				wrapper = group["wrapper"]
				toolchain = group["toolchain"]
				group_build_types = group["build_types"]
				apps = self._select_apps(toolchain)
				main.logger.info(f"- Group {idx_g}: toolchain={toolchain} wrapper={wrapper}")
				for bt in list(set(group_build_types).intersection(self.build_types)):
					preset = f"{toolchain}-{bt}"
					main.logger.info(f"~ [{preset}] BUILD: {self.build_arguments} {preset}")
					for app in apps:
						main.logger.info(f"~ [{preset}] RUN: {self.run_arguments} {preset} -- {app}")
		return 0


# Register the subcommand only at the top level (not inside Docker or Wine).
if not main.is_docker() and not main.is_wine():
	SubCommandTest().register()

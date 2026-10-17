#!/usr/bin/env python3
# coding=utf-8
"""
Fix subcommand for build.py.

This subcommand downloads patched DLLs from a Nexus raw repository and
installs them into a Wine prefix's system32 directory, after backing up
the original DLLs which are required as runtime dependencies.
"""

import argparse
import os
import sys
import tempfile
from typing import List
from pathlib import Path

# Use the already-loaded 'build' module from sys.modules to avoid re-importing
# the module-level code (which would create a second config and separate registry).
# When run as './build.py', the module key is '__main__', not 'build'.
build_module = sys.modules.get("build") or sys.modules.get("__main__")
if build_module is None:
	raise ImportError(
		"build-fixes requires 'build' to be imported first. "
		"This module should only be loaded via _load_subcommand_modules()."
	)
# Fake import to trick IDE.
if build_module is None:
	import build as main
else:
	main = build_module


class SubCommandFix(main.SubCommand):
	"""Subcommand handler for the 'fix' command."""

	def __init__(self):
		super().__init__("fix")

	def create_parser(self, subparsers):
		"""Create the parser for the fix subcommand."""
		self.parser = subparsers.add_parser(
			self.command,
			aliases=self.aliases,
			add_help=False,
			formatter_class=argparse.RawTextHelpFormatter,
			help="Apply fixes to Wine prefix components.",
			description="Downloads patched libraries from Nexus and installs them into a Wine prefix."
		)
		self.parser.epilog = f"""
examples:

  Apply the mscms.dll fix to the default Wine prefix:
    {main.SubCommand.script} fix mscms

  Apply the mscms.dll fix to a custom Wine prefix:
    {main.SubCommand.script} fix mscms -p /path/to/wineprefix

  Dry-run to preview actions:
    {main.SubCommand.script} fix mscms -d

  Restore the original mscms.dll:
    {main.SubCommand.script} fix mscms --restore

  Template ini-file for '.nexus-credentials.ini':

[nexus-credentials]
NEXUS_USER=your-username
NEXUS_PASSWORD=your-password
NEXUS_SERVER_URL=https://nexus.example.com
NEXUS_RAW_REPO=shared
"""
		if self.parser is None:
			raise ValueError("Parser cannot be None")
		return self.parser

	def options(self, parser):
		"""Add options to the fix subcommand parser."""
		super().options(parser)
		parser.add_argument(
			"action",
			type=str,
			choices=["mscms"],
			help="The fix action to perform (e.g., 'mscms')."
		)
		parser.add_argument(
			"-p", "--wineprefix",
			type=str,
			default=None,
			metavar="<dir>",
			help="Override the WINEPREFIX environment variable for the Wine prefix directory."
		)
		parser.add_argument(
			"-S", "--section",
			type=str,
			default="credentials",
			metavar="<section>",
			help="Configuration section suffix for Nexus (default: 'credentials', forms 'nexus-credentials')."
		)
		parser.add_argument(
			"-r", "--restore",
			action="store_true",
			help="Restore the fix."
		)
		parser.add_argument(
			"-V", "--verbose",
			action="store_true",
			help="Enable verbose output for download and extraction operations."
		)
		return parser

	def handle(self, args: argparse.Namespace, args_left: List[str], args_right: List[str] | None) -> int:
		"""Handle the 'fix' subcommand execution."""
		super().handle(args, args_left, args_right)

		# Only support 'mscms' action for now
		if args.action != "mscms":
			main.logger.error(f"! Unsupported fix action: {args.action}")
			self.print_help()
			return 1

		return self.handle_mscms(args)

	def handle_mscms(self, args: argparse.Namespace) -> int:
		"""
		Handle the 'mscms' fix action.

		Backs up the original mscms.dll to system32/original/ (runtime dependency),
		downloads the patched version from Nexus, and installs it.
		If --restore is specified, removes the patched DLL and restores the original backup.
		"""
		# Resolve WINEPREFIX: CLI arg -> RUN_ENV -> default ~/.wine
		wine_prefix = args.wineprefix or main.RUN_ENV.get(
			"WINEPREFIX", os.path.expanduser("~/.wine")
		)
		system32_dir = os.path.join(
			wine_prefix, "drive_c", "windows", "system32"
		)
		original_dir = os.path.join(system32_dir, "original")
		mscms_dll = os.path.join(system32_dir, "mscms.dll")
		original_mscms_dll = os.path.join(original_dir, "mscms.dll")
		# Validate the system32 directory exists
		if not os.path.isdir(system32_dir):
			main.logger.error(
				f"! Wine prefix system32 directory does not exist: {system32_dir}"
			)
			return 1

		# Handle restore mode
		if args.restore:
			return self._restore_mscms(system32_dir, original_dir, mscms_dll, original_mscms_dll, args)

		# Get merged config from nexus-credentials section.
		section_name = f"nexus-{args.section}"
		merged = main.get_merged_config_section(section_name, fail=True)
		# Validate required config variables.
		nexus_server_url = merged.get("NEXUS_SERVER_URL", "").rstrip("/")
		nexus_raw_repo = merged.get("NEXUS_RAW_REPO", "")
		nexus_user = merged.get("NEXUS_USER", "")
		nexus_password = merged.get("NEXUS_PASSWORD", "")
		if not nexus_server_url:
			main.logger.error("! Required config variable 'NEXUS_SERVER_URL' is not set!")
			return 1
		if not nexus_raw_repo:
			main.logger.error("! Required config variable 'NEXUS_RAW_REPO' is not set!")
			return 1
		if not nexus_user or not nexus_password:
			main.logger.error("! Required credentials 'NEXUS_USER' and/or 'NEXUS_PASSWORD' are not set!")
			return 1
		# Construct download URL.
		download_url = (
			f"{nexus_server_url}/repository/{nexus_raw_repo}/library/mscms-wine.tgz"
		)
		if args.verbose:
			main.logger.info(f"# Download URL: {download_url}")
			main.logger.info(f"# Wine prefix: {wine_prefix}")
		# Create system32/original/ directory if it doesn't exist.
		if main.DEBUG_FLAG:
			main.logger.info(f"~ Not creating directory: {original_dir}")
		else:
			os.makedirs(original_dir, exist_ok=True)
		# Check if already backed up; if not, move mscms.dll to original.
		if not os.path.exists(original_mscms_dll):
			if os.path.exists(mscms_dll):
				if main.DEBUG_FLAG:
					main.logger.info(f"~ Not moving: {mscms_dll} -> {original_mscms_dll}")
				else:
					main.logger.info(f"~ Backing up original DLL to: {original_mscms_dll}")
					os.rename(mscms_dll, original_mscms_dll)
			else:
				main.logger.warning(
					": No existing mscms.dll found to back up. "
					"The patched DLL requires the original in 'original/' as a runtime dependency.")
		else:
			main.logger.info(
				"# Original mscms.dll already backed up in 'original/' — skipping backup step."
			)
		# Download .tgz to a temp file.
		temp_dir = tempfile.mkdtemp()
		temp_tgz = os.path.join(temp_dir, "mscms-wine.tgz")
		try:
			status, error = main.download_file_http(download_url, temp_tgz, nexus_user, nexus_password, verbose=args.verbose)
			if status < 200 or status >= 300:
				main.logger.error(f"! Download failed with HTTP {status}: {error}")
				return 1
			if main.DEBUG_FLAG:
				main.logger.info(f"~ Not extracting archive: {temp_tgz} -> {system32_dir}")
			else:
				# Extract mscms.dll directly into system32/ (archive contains only the single DLL)
				main.logger.info(f"~ Extracting mscms.dll to: {system32_dir}")
				extract_result = main.run_command(["tar", "xzf", temp_tgz, "-C", system32_dir],
					dbg_mode=main.DebugMode.SILENT)
				if extract_result.returncode != 0:
					main.logger.error("! Failed to extract archive!")
					return 1
				main.logger.info("# Successfully installed patched: mscms.dll")
		finally:
			# Clean up temp file
			if not main.DEBUG_FLAG and os.path.exists(temp_dir):
				main.remove_tree(Path(temp_dir))
		return 0

	def _restore_mscms(self, system32_dir, original_dir, mscms_dll, original_mscms_dll, args) -> int:
		"""
		Restore the original mscms.dll by removing the patched version and
		moving the backup back to system32.
		"""
		if args.verbose:
			main.logger.info(f"# Wine prefix: {system32_dir.rsplit('drive_c', 1)[0]}")
		# Check if backup exists
		if not os.path.exists(original_mscms_dll):
			main.logger.error(
				f"! No backup found at {original_mscms_dll}. "
				"Cannot restore without the original backup."
			)
			# Check if we're already in a clean state
			if not os.path.exists(mscms_dll):
				main.logger.info("# No mscms.dll in system32 either — appears to be in a clean state.")
			return 1
		# Check if patched DLL is currently installed
		if not os.path.exists(mscms_dll):
			main.logger.info("# No patched mscms.dll in system32. Restoring original from backup.")
		else:
			main.logger.info(f"~ Removing patched DLL: {mscms_dll}")
			if not main.DEBUG_FLAG:
				os.remove(mscms_dll)
			else:
				main.logger.info(f"~ Not removing: {mscms_dll}")
		# Restore the original from backup
		main.logger.info(f"~ Restoring original DLL: {original_mscms_dll} -> {mscms_dll}")
		if not main.DEBUG_FLAG:
			os.rename(original_mscms_dll, mscms_dll)
		else:
			main.logger.info(f"~ Not moving: {original_mscms_dll} -> {mscms_dll}")
		#
		main.logger.info("# Successfully restored original mscms.dll")
		return 0


# Register the subcommand when the module is imported
SubCommandFix().register()

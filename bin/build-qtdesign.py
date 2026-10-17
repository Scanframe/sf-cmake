#!/usr/bin/env python3
# coding=utf-8
"""
Qt Designer subcommand for build.py.

This subcommand launches the Qt Designer executable based on the configured
preset, resolving the Qt version directory and compiler subdirectory
(gcc_64 / mingw_64 / msvc_64) automatically.
"""

import argparse
import sys
from typing import List, Dict

# Use the already-loaded 'build' module from sys.modules to avoid re-importing
# the module-level code (which would create a second config and separate registry).
# When run as './build.py', the module key is '__main__', not 'build'.
build_module = sys.modules.get("build") or sys.modules.get("__main__")
if build_module is None:
	raise ImportError(
		"build-qtdesign requires 'build' to be imported first. "
		"This module should only be loaded via _load_subcommand_modules()."
	)
# Fake import to trick IDE.
if build_module is None:
	import build as main
else:
	main = build_module


def get_qt_compiler_subdir(compiler_type: str) -> str:
	"""
	Maps the compiler type from the preset to the Qt compiler subdirectory.

	:param compiler_type: The compiler type (e.g. 'gnu', 'msvc', 'mingw').
	:return: The Qt compiler subdirectory name.
	"""
	if compiler_type in ("gnu", "ga"):
		return "gcc_64"
	elif compiler_type in ("mingw", "gw"):
		return "mingw_64"
	elif compiler_type == "msvc":
		return "msvc_64"
	else:
		return "gcc_64"


class SubCommandQtDesign(main.SubCommand):
	"""Subcommand handler for the 'qtdesigner' command."""

	def __init__(self):
		super().__init__("qtdesigner", ["qd"])

	def create_parser(self, subparsers):
		"""Create the parser for the qtdesigner subcommand."""
		self.parser = subparsers.add_parser(
			self.command,
			aliases=self.aliases,
			add_help=False,
			formatter_class=argparse.RawTextHelpFormatter,
			help="Launch Qt Designer using the preset's Qt version directory.",
			description="Launches the Qt Designer executable resolved from the given configure preset."
		)
		if self.parser is None:
			raise ValueError("Parser cannot be None")
		return self.parser

	def options(self, parser):
		"""Add options to the 'qtdesigner' subcommand parser."""
		super().options(parser)
		parser.add_argument(
			"-p", "--preset",
			type=str,
			nargs="?",
			required=True,
			metavar="<preset>",
			help="The configure preset to set the environment."
		)

	def handle(self, args: argparse.Namespace, args_left: List[str], args_right: List[str] | None) -> int:
		"""Handle the 'qtdesigner' subcommand execution."""
		super().handle(args, args_left, args_right)
		args = argparse.Namespace(
			dry_run=args.dry_run,
			exec=False,
			subcmd="run",
			verbose=False,
			help=False,
			preset=args.preset,
		)
		cmd_args_right: List[str] = ["designer"]
		if args_right:
			cmd_args_right += args_right
		# Get the 'run' subcommand entry.
		return self.registry[args.subcmd].handle(args, args_left, cmd_args_right)


# Register the subcommand when the module is imported
SubCommandQtDesign().register()

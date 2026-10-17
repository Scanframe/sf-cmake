#!/usr/bin/env python3
# coding=utf-8
"""
Demo subcommand for build.py.

This subcommand serves as an example of how to create a subcommand module
that is dynamically imported by the main build.py script.
"""

import argparse
import sys

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

class SubCommandDemo(main.SubCommand):
	"""Subcommand handler for the 'demo' command."""

	def __init__(self):
		super().__init__("demo")

	def create_parser(self, subparsers):
		"""Create the parser for the demo subcommand."""
		self.parser = subparsers.add_parser(
			self.command,
			aliases=self.aliases,
			add_help=False,
			formatter_class=argparse.RawTextHelpFormatter,
			help="Demo subcommand example.",
			description="A demo subcommand to illustrate the subcommand module system."
		)
		if self.parser is None:
			raise ValueError("Parser cannot be None")
		return self.parser

	def options(self, parser):
		"""Add options to the demo subcommand parser."""
		super().options(parser)
		parser.add_argument(
			"--info",
			action="store_true",
			help="Print demo information."
		)

	def handle(self, args, args_left, args_right):
		"""Handle the demo subcommand execution."""
		super().handle(args, args_left, args_right)

		if args.info:
			main.logger.info("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
			main.logger.info("Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
			main.logger.info("Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.")
			main.logger.info("Duis aute irure dolor in reprehenderit in voluptate velit esse cillum.")
			main.logger.info("Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia.")
		else:
			self.print_help()

		return 0


# Register the subcommand when the module is imported
SubCommandDemo().register()

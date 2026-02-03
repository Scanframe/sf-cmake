#!/usr/bin/env python3
# coding=utf-8
"""
Fix Doxygen PlantUML images
This script processes PlantUML source files, generating images for @startuml blocks and !include directives.
It supports both PNG and SVG output formats and requires Java and PlantUML to be installed.

Example input file with multiple diagrams::

	@startuml inline_umlgraph_1.svg
	!include my-file1.puml
	@enduml
	@startuml inline_umlgraph_2.svg
	!include my-file2.puml
	@enduml
"""

import argparse
import glob
import re
import subprocess
import sys
from pathlib import Path

# The directory of the current file.
RUN_DIR = Path(__file__).absolute()
# Location of the java application.
PLANTUML_JAR: Path


def generate_image(src_file: Path, dest_file: Path) -> bool:
	"""
	Generate an image from PlantUML source file.
	:param src_file: Path to the PlantUML source file.
	:param dest_file: Path to the output image file.
	:return: True if image generation is successful, False otherwise.
	"""
	# Determine format from destination file extension
	suffix = dest_file.suffix.lower()
	if suffix == '.svg':
		format_opt = '--svg'
	elif suffix == '.png':
		format_opt = '--png'
	else:
		print(f"Error: Unsupported output format '{suffix}'. Use .png or .svg")
		return False
	# Execute PlantUML with pipe mode.
	try:
		cmd = ["java", "-Djava.awt.headless=true", "-jar", str(PLANTUML_JAR), "--pipe", format_opt]
		with open(src_file, 'r') as src, open(dest_file, 'wb') as dest:
			return subprocess.run(cmd, stdin=src, stdout=dest, check=True).returncode == 0
	except subprocess.CalledProcessError as ex:
		print(f"Error: PlantUML execution failed for {src_file}: {ex.stderr.decode('utf-8')}")
		return False
	except FileNotFoundError:
		print("Error: 'java' command not found. Please ensure Java is installed and in PATH.")
		return False


def process_file(input_file: str, base_dir: str) -> bool:
	"""
	Process a PlantUML source file, generating images for @startuml blocks and !include directives.
	:param input_file: Path to the PlantUML source file.
	:param base_dir: Base directory for relative paths.
	:return: True if processing is successful, False otherwise.
	"""
	input_file = Path(input_file).resolve()
	if not input_file.exists():
		print(f"Error: Input file '{input_file}' not found.")
		return False
	with open(input_file, 'r') as f:
		content = f.read()

	# Regex to find all @startuml blocks with their content until @enduml
	# Pattern: @startuml <filename> ... !include <file> ... @enduml
	startuml_blocks = re.findall(
		r"@startuml\s+([\w.-]+)\s+(.*?)@enduml",
		content,
		re.DOTALL
	)

	if not startuml_blocks:
		print(f"Error: No '@startuml <filename>' blocks found in {input_file}")
		return False

	input_dir = input_file.parent
	all_success = True

	for image_filename, block_content in startuml_blocks:
		# Find '!include' directive in this block.
		include_match = re.search(r"!include\s+(.*)$", block_content)
		if not include_match:
			print(f"Error: No '!include <filename>' found in block for {image_filename}")
			all_success = False
			continue
		include_filename = include_match.group(1)
		# Resolve include file.
		include_file = input_dir / include_filename
		if not include_file.exists() and base_dir:
			base_path_obj = Path(base_dir).resolve()
			include_file = base_path_obj / include_filename
		if not include_file.exists():
			print(f"Error: Included file '{include_filename}' not found locally or in base-path for {input_file}")
			all_success = False
			continue
		ref_file = include_file.resolve()
		with open(ref_file, 'r') as f:
			ref_content = f.read().strip("\n\r ")
		if not ref_content.startswith("@startuml"):
			all_success = False
			continue
		print(f"Generate: {ref_file.name} > {image_filename}")
		if not generate_image(ref_file, input_dir / image_filename):
			all_success = False
	return all_success


def main() -> int:
	"""
	Main entry point for the script. Processes PlantUML files and generates images.
	:return: Exit code, 0 for success, 1 for failure.
	"""
	global PLANTUML_JAR
	#
	parser = argparse.ArgumentParser(description="Generate image from a PlantUML file.")
	parser.add_argument("files", nargs='+', help="Directory with wildcards for multiple files.")
	parser.add_argument("-b", "--base-dir", help="Base directory for the filed included.")
	parser.add_argument("-j", "--jar", help="Path to plantuml.jar file")
	# Get the arguments.
	args = parser.parse_args()
	# Check if the jar file was passed and is valid.
	if not args.jar or not Path(args.jar).exists():
		print("Error: plantuml.jar not found. Use --jar to specify its location.")
		return 1
	# Assign the application jar.
	PLANTUML_JAR = Path(args.jar)
	# Expand file patterns - each entry should be a directory combined wildcard.
	expanded_files = []
	for pattern in args.files:
		matched = glob.glob(pattern)
		if matched:
			expanded_files.extend(matched)
		else:
			print(f"Warning: No files matched pattern '{pattern}'")
	if not expanded_files:
		print("Error: No files found matching the provided patterns.")
		return 0
	success_count = 0
	for fn in expanded_files:
		if process_file(fn, args.base_dir):
			success_count += 1

	print(f"Processed {len(expanded_files)} files.")
	print(f"Success: {success_count}, Failed: {len(expanded_files) - success_count}")
	return 0


if __name__ == "__main__":
	try:
		exitcode = main()
	except KeyboardInterrupt:
		exitcode = 130
	except subprocess.CalledProcessError as cmd_ex:
		if cmd_ex.returncode != 130:
			print(f"! Command error({cmd_ex.returncode}): {' '.join(cmd_ex.cmd)}")
			if cmd_ex.stdout:
				print(cmd_ex.stdout.decode("utf-8"))
			if cmd_ex.stderr:
				print(cmd_ex.stderr.decode("utf-8"))
		exitcode = cmd_ex.returncode
	except Exception as any_ex:
		print(f"! Exception({any_ex.__class__.__name__}): {any_ex}")
		if hasattr(any_ex, '__notes__'):
			for note in any_ex.__notes__:
				print(f"Note: {note}")
		exitcode = 1
	# Show the cursor again.
	sys.exit(exitcode)

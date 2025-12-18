#!/usr/bin/env python3
# coding=utf-8
"""
Module for extracting metadata from binary files, specifically Windows PE and Linux ELF files.

This module provides functions to parse executable binary formats and extract relevant
information such as file type, CPU architecture, version details, and imported libraries.
The module supports Windows Portable Executable (PE) and Linux ELF formats.

Functions:
    - get_pe_info: Extracts metadata from Windows PE (Portable Executable) files.
    - get_elf_info: Extracts metadata from Linux ELF (Executable and Linkable Format) files.
    - main: Entry point of the script that determines the file type and extracts metadata.
"""
import os
import sys
from elftools.elf.elffile import ELFFile
import pefile

def get_pe_info(file_path):
	"""Extracts metadata from Windows PE files (.exe, .dll)"""
	try:
		pe = pefile.PE(file_path)
		info = {
			"File Name": os.path.basename(file_path),
			"File Type": "Windows Portable Executable (PE)",
			"CPU Type": pefile.MACHINE_TYPE.get(pe.FILE_HEADER.Machine, "Unknown"),
			"Product Version": "N/A",
			"File Version": "N/A",
			"Imports" : []
		}

		# Extract Version Information
		if hasattr(pe, 'FileInfo'):
			for fileinfo in pe.FileInfo[0]:
				if fileinfo.Key.decode() == 'StringFileInfo':
					for st in fileinfo.StringTable:
						for entry in st.entries.items():
							key = entry[0].decode()
							val = entry[1].decode()
							if key == 'ProductVersion': info["Product Version"] = val
							if key == 'FileVersion': info["File Version"] = val

		# Ensure the import directory is parsed
		if hasattr(pe, 'DIRECTORY_ENTRY_IMPORT'):
			for entry in pe.DIRECTORY_ENTRY_IMPORT:
				# entry.dll contains the name of the DLL (e.g., KERNEL32.dll)
				info["Imports"].append(entry.dll.decode('utf-8'))

		return info

	except Exception as e:
		return {"Error": f"PE Parsing failed: {e}"}


def get_elf_info(file_path):
	"""Extracts metadata from Linux ELF files (.so, executables)"""
	try:
		with open(file_path, 'rb') as f:
			elf = ELFFile(f)
			# Map Machine ID to human-readable strings.
			cpu_type = elf.header['e_machine']
			file_type = elf.header['e_type']
			info = {
				"File Name": os.path.basename(file_path),
				"File Type": f"Linux ELF ({file_type})",
				"CPU Type": cpu_type,
				"Product Version": "N/A",
				"File Version": "N/A",
				"Imports": []
			}
			# Get the .dynamic section, where dependency tags are stored
			dynamic_section = elf.get_section_by_name('.dynamic')
			if dynamic_section:
				# Iterate through the tags in the dynamic section.
				# Look for DT_NEEDED tags which contain names of imported libraries.
				for tag in dynamic_section.iter_tags():
					if tag.entry.d_tag == 'DT_NEEDED':
						info["Imports"].append(tag.needed)
			return info

	except Exception as e:
		return {"Error": f"ELF Parsing failed: {e}"}


def main()->int:
	script = os.path.basename(__file__)
	if len(sys.argv) < 2:
		print(f"Usage: {script} <path-to-binary>")

	file_path = sys.argv[1]

	if not os.path.exists(file_path):
		print(f"{script}: File not found: {file_path}!")
		return 1

	# Check magic numbers
	with open(file_path, 'rb') as f:
		magic = f.read(4)

	if magic.startswith(b'MZ'):
		data = get_pe_info(file_path)
	elif magic.startswith(b'\x7fELF'):
		data = get_pe_info(file_path) if os.name == 'nt' and magic.startswith(b'MZ') else get_elf_info(file_path)
	else:
		print("Unsupported file format!")
		return 1

	for key, val in data.items():
		if type(val) is list:
			print(f"{key:16}: {", ".join(val)}")
		else:
			print(f"{key:16}: {val}")
	return 1


if __name__ == "__main__":
	SystemExit(main())

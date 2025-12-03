#!/usr/bin/env bash
# Needed for this script is pip library 'pip install python-gitlab'
# Quoted strings are ignored by python.
# noinspection PySingleQuotedDocstring
"exec" "python" "$0" "$@"

import xml.etree.ElementTree as ET
import sys
import os
import shutil


def fix_svg_for_qt(file_path):
	ET.register_namespace('', "http://www.w3.org/2000/svg")
	tree = ET.parse(file_path)
	root = tree.getroot()

	changed = False
	embedded_font_id = "EmbeddedFont_1"

	for text_elem in root.findall(".//{*}text[@class='SVGTextShape']"):
		tspans = list(text_elem.findall(".//{*}tspan"))

		# Look for the TextPosition span explicitly
		text_pos_tspan = None
		for t in tspans:
			if t.get('class') == 'TextPosition':
				text_pos_tspan = t
				break
		# When the 'tspan' with class 'TextPosition' is not found it is already fixed.
		if text_pos_tspan is None:
			continue

		if text_pos_tspan is not None and len(tspans) >= 3:
			final_tspan = tspans[-1]
			text_content = final_tspan.text or ''
			attrs = final_tspan.attrib.copy()
			attrs['font-family'] = embedded_font_id
			# Save the attribute values.
			x = text_pos_tspan.get('x')
			y = text_pos_tspan.get('y')
			# Check if they were set.
			if x and y:
				text_elem.set('x', x)
				text_elem.set('y', y)
			else:
				print(f"⚠️  Warning: Missing 'x' or 'y' in TextPosition for element at line {text_elem.sourceline if hasattr(text_elem, 'sourceline') else 'unknown'}")
			# Create a new tspan element.
			new_tspan = ET.Element('tspan', attrib=attrs)
			new_tspan.text = text_content
			new_tspan.set('class', 'TextParagraph')
			# Remove the child elements.
			for child in list(text_elem):
				text_elem.remove(child)
			# Add the single "tspan" tag element.
			text_elem.append(new_tspan)
			# Set the changed flag.
			changed = True

	if changed:
		backup_path = file_path.replace('.svg', '-original.svg')
		shutil.move(file_path, backup_path)
		tree.write(file_path, encoding='utf-8', xml_declaration=True)
		print(f"✅ SVG updated. Original backed up to {backup_path}")
	else:
		print("ℹ️ No changes made. SVG is already compatible.")


if __name__ == "__main__":
	if len(sys.argv) != 2:
		print(f"Usage: {os.path.basename(__file__)} <file.svg>")
		sys.exit(1)

	input_svg = sys.argv[1]
	if not os.path.isfile(input_svg):
		print(f"File not found: {input_svg}")
		sys.exit(1)

	fix_svg_for_qt(input_svg)

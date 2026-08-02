#!/usr/bin/env python3

import sys
import subprocess
import os
import re

def check_dependencies():
    commands = ["nm", "pcregrep", "file", "sed", "c++filt"]
    for cmd in commands:
        if subprocess.run(f"command -v {cmd}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
            print(f"Missing command '{cmd}' for this script")
            sys.exit(1)

def run_command(cmd_list):
    try:
        return subprocess.check_output(cmd_list, stderr=subprocess.DEVNULL).decode('utf-8')
    except subprocess.CalledProcessError:
        return ""

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <lib-file>")
        sys.exit(1)

    lib_file = sys.argv[1]
    if not os.path.exists(lib_file):
        print(f"File not found: {lib_file}")
        sys.exit(1)

    check_dependencies()

    # Detect extension
    match = re.search(r'\.([a-zA-Z0-9]+)$', lib_file)
    ext = match.group(1) if match else ""

    # Detect executable if no extension
    if not ext:
        file_mime = subprocess.check_output(["file", "-bi", lib_file]).decode('utf-8').strip()
        if "application/x-pie-executable" in file_mime:
            ext = "bin"

    print(f"Exports of file ({ext}): {lib_file}")

    if ext == 'a':
        # nm -g "${1}" | c++filt | sort -ru | sed -re '/^[0 ]+ [TU] .*$/d'
        nm_out = run_command(["nm", "-g", lib_file])
        filt_out = subprocess.Popen(["c++filt"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate(input=nm_out.encode())[0].decode()
        
        # Sort and filter
        lines = sorted(list(set(filt_out.splitlines())), reverse=True)
        for line in lines:
            if not re.match(r'^[0 ]+ [TU] .*$', line):
                print(line)

    elif ext in ['so', 'bin']:
        # nm --demangle --dynamic --defined-only --extern-only "${1}" | sort -ru | sed -e '/^[0-9a-f]* W .*$/d'
        cmd = ["nm", "--demangle", "--dynamic", "--defined-only", "--extern-only", lib_file]
        nm_out = run_command(cmd)
        
        lines = sorted(list(set(nm_out.splitlines())), reverse=True)
        for line in lines:
            if not re.match(r'^[0-9a-f]* W .*$', line):
                print(line)

    elif ext == 'dll':
        # winedump -j export "${1}"
        print(run_command(["winedump", "-j", "export", lib_file]))
    
    else:
        print(f"Extension '.{ext}' not implemented.")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import socket, os, sys, json

# Get the port number which defaults to 9999.
PORT_NUMBER = int(os.environ.get("GIT_SERVER_PORT", "9999"))


def main():
	if len(sys.argv) == 1:
		print(r"""
Replacement for git.exe in Linux Wine.
Makes a call to the Git server listening on localhost default port 9999.
It can be changed by environment variable GIT_SERVER_PORT.
""")
		return 0
	# Assemble the payload.
	payload = {"cwd": os.getcwd(), "args": sys.argv[1:]}
	client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	client.connect(('127.0.0.1', PORT_NUMBER))
	client.sendall(json.dumps(payload).encode('utf-8'))
	# Accumulate full JSON response
	buffer = b""
	while True:
		chunk = client.recv(4096)
		if not chunk: break
		buffer += chunk
	client.close()
	resp = json.loads(buffer.decode('utf-8'))
	# Restore data to Windows streams
	if resp['stdout']:
		sys.stdout.buffer.write(bytes.fromhex(resp['stdout']))
	if resp['stderr']:
		sys.stderr.buffer.write(bytes.fromhex(resp['stderr']))
	return resp['exit_code']


if __name__ == "__main__":
	try:
		sys.exit(main())
	except KeyboardInterrupt:
		print("Interrupted by user!", file=sys.stderr)
		sys.exit(130)
	except Exception as the_exception:
		print(f"Error: {the_exception}", file=sys.stderr)
		sys.exit(1)

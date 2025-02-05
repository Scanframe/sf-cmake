#!/bin/bash

# Bail out on first error.
set -e

# Get the scripts run directory weather it is a symlink or not.
run_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When a symlink determine the script directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
	include_dir="${run_dir}/$(dirname "$(readlink "$0")")"
else
	include_dir="${run_dir}/cmake/lib/bin"
fi

# Include the Miscellaneous functions.
source "${include_dir}/inc/Miscellaneous.sh"
# Get the project root and subdirectory.
project_subdir="$(basename "${run_dir}")"
# Determines if the build is in the 'cmake-build/docker' directory or not.
flag_build_dir=true
# The target platform by default the current architecture of the machine.
if [[ "$(uname -m)" == 'aarch64' ]]; then
	platform="arm64"
	# Qt version
	qt_ver="6.8.1"
else
	platform="amd64"
	# Qt version
	qt_ver="6.8.1"
fi

# Set container name to be used.
container_name="cpp_builder"
# Hostname for the docker container.
hostname="$(hostname)"

function show_help {
	local cmd
	cmd="$(basename "${0}")"
	# When no arguments are given run bash from within the container.
	echo "Same as 'build.sh' script but running from Docker image but allows Docker specific commands.

Usage: ${cmd} <options> -- <build-options> [command] <args...>

  Options:
    -h, --help                : Shows this help.
    --qt-ver <version>        : Qt version part forming the Docker image name which defaults to '${qt_ver}' but empty is possible.
    -p, --platform <platform> : Platform part forming the Docker image which defaults to '${platform}' where available is 'amd64' and 'arm64'.
    --no-build-dir            : Docker project builds in a regular cmake-build directory as a native build would.

  Commands:
    pull      : Pulls the docker image from the Docker registry.
    run       : Runs a command as user 'user' in the container using Docker command.
                'run' or 'exec' depending on a running container in the background.
    start     : Starts/Detaches a container named '${container_name}' in the background.
    attach    : Attaches to the  in the background running container named '${container_name}'.
    status    : Returns info of the running container '${container_name}' in the background.
    stop      : Stops the container named '${container_name}' running in the background.
    kill      : Kills the container named '${container_name}' running in the background.
    versions  : Shows versions of most installed applications within the container.
    sshd      : Starts sshd service on port 3022 to allow remote control.

  When a the container is detached it executes the 'build.sh' script by attaching to the container which is much faster.

  Examples:
    Show the targets using the amd64 platform docker image and Qt version ${qt_ver}.
      ${cmd} --platform amd64 --qt-ver '${qt_ver}' -- --info
    Show the uname information of the arm64 container without QT libraries.
      ${cmd} --platform arm64 --qt-ver '' -- run uname -a
"
}

# Sentry to fail when calling from a Docker container.
if [[ -f /.dockerenv ]]; then
	WriteLog "Unable to call script $(basename "${0}") from withing a Docker container!"
	exit 1
fi

# Check if running detached.
function is_detached {
	cntr_id="$(docker ps --filter name="${container_name}" --quiet)"
	[[ -n "${cntr_id}" ]] || return 1 && return 0
}

# Function which runs the docker build.sh script in the container.
function docker_run {
	if is_detached; then
		docker exec --interactive --tty "${container_name}" sudo --login --user=user -- "${@}"
	else
		docker run "${options[@]}" "${img_name}" "${@}"
	fi
}

if [[ $# -eq 0 ]]; then
	show_help
else
	# Parse options.
	temp=$(getopt -o 'hp:' --long 'help,no-build-dir,platform:,qt-ver:' -n "$(basename "${0}")" -- "$@")
	# shellcheck disable=SC2181
	if [[ $? -ne 0 ]]; then
		show_help
		exit 1
	fi
	eval set -- "${temp}"
	unset temp
	while true; do
		case "$1" in

			-h | --help)
				show_help
				exit 0
				;;

			--no-build-dir)
				flag_build_dir=false
				shift 2
				continue
				;;

			-p | --platform)
				platform="$2"
				shift 2
				continue
				;;

			--qt-ver)
				qt_ver="$2"
				shift 2
				continue
				;;

			'--')
				shift
				break
				;;

			*)
				WriteLog "Internal error on argument (${1}) !" >&2
				exit 1
				;;
		esac
	done
	# Assemble the Docker default options to run.
	options=()
	# Set the platform to run on in docker.
	options+=(--platform "linux/${platform}")
	# Remove container and associated anonymous volumes.
	options+=(--rm)
	# Not needed when detached (daemon) running.
	options+=(--tty)
	options+=(--interactive)
	# Options to allow mounting fuse-zip from entry point.
	options+=(--device /dev/fuse)
	options+=(--cap-add SYS_ADMIN)
	options+=(--security-opt apparmor:unconfined)
	# Option 'privileged' when the 3 above are not working as it should.
	#options+=(--privileged)
	# Not really needed.
	options+=(--hostname "${hostname}")
	# The Entrypoint script requires to be executed as root although not actual
	# needed is prevents nesting sudo commands.
	options+=(--user 0:0)
	# The Entrypoint uses LOCAL_USER variable to set the 'uid' and 'gid' of the user 'user' and its home directory.
	options+=(--env LOCAL_USER="$(id -u):$(id -g)")
	# Options needed to forward X11 server from the host.
	options+=(--network host)
	# Check if the host has a X11 display running at all.
	if [[ -n "${DISPLAY}" && -f "${HOME}/.Xauthority" ]]; then
		# Pass the environment variable from the host to the container.
		options+=(--env DISPLAY)
		# Mount the nex volume so X11 apps can use the host's X11 server.
		options+=(--volume "${HOME}/.Xauthority:/home/user/.Xauthority:ro")
	fi
	# Mount the project sub directory into the project directory like
	# CLion does using a Docker toolchain.
	if [[ "$(uname -o)" == "Cygwin" ]]; then
		options+=(--volume "$(cygpath -w "${run_dir}"):/mnt/project/${project_subdir}:rw")
	else
		options+=(--volume "${run_dir}:/mnt/project/${project_subdir}:rw")
	fi
	# Check if the build directory offset has been set for separate build dir offset.
	if ${flag_build_dir}; then
		# Build directory used for Docker builds.
		build_dir="${run_dir}/cmake-build/docker-${platform}"
		# Create the special docker binary build directory.
		mkdir --parents "${build_dir}"
		if [[ "$(uname -o)" == "Cygwin" ]]; then
			options+=(--volume "$(cygpath -w "${build_dir}"):/mnt/project/${project_subdir}/cmake-build:rw")
		else
			options+=(--volume "${build_dir}:/mnt/project/${project_subdir}/cmake-build:rw")
		fi
	fi
	options+=(--workdir "/mnt/project/${project_subdir}/")
	# Form the Docker image name and trim the '-' whe qt_ver is empty.
	img_name="nexus.scanframe.com/${platform}/gnu-cpp:24.04-${qt_ver}"
	img_name="${img_name/%-/}"
	WriteLog "Docker image used: ${img_name}":
	# Process the given commands additional to the 'build.sh' script.
	case "$1" in
		pull)
			# Pull the Docker image from the registry.
			docker pull "${img_name}"
			;;

		versions)
			# Just reenter the script using the the correct arguments.
			docker_run /home/user/bin/versions.sh
			;;

		run)
			shift 1
			docker_run "${@}"
			;;

		detach | start)
			# Check if the container is running.
			if is_detached; then
				WriteLog "Container '${container_name}' is already running."
				exit 1
			fi
			# Name of the container only useful for detached running.
			options+=(--name "${container_name}")
			options+=(--detach)
			docker_run sleep infinity
			;;

		sshd)
			# Check if the container is running.
			if is_detached; then
				WriteLog "Container '${container_name}' is already running."
				exit 1
			fi
			# Name of the container only useful for detached running.
			options+=(--name "${container_name}")
			# Mount a cache directory to reuse Jetbrains Gateway install.
			mkdir --parents "${HOME}/tmp/${container_name}-cache"
			options+=(--volume "${HOME}/tmp/${container_name}-cache:/home/user/.cache:rw")
			# Run the sshd in the background.
			options+=(--detach)
			# Run sshd on port 3022.
			docker_run sudo -- /usr/sbin/sshd -e -D -p 3022
			;;

		attach)
			# Check if the container is running.
			if ! is_detached; then
				WriteLog "Container '${container_name}' is not running."
				exit 1
			fi
			# Remove the attach command from the arguments list.
			shift 1
			# Connect to the last started container as user 'user'.
			docker exec --interactive --tty "${container_name}" sudo --login --user=user -- "${@}"
			;;

		status)
			# Show the status of the container.
			docker ps --filter name="${container_name}"
			;;

		stop | kill)
			if is_detached; then
				WriteLog "Container ID is '${cntr_id}' and performing '${1}' command."
				docker "${1}" "${cntr_id}"
			else
				WriteLog "Container '${container_name}' is not running."
			fi
			;;

		*)
			# Stop this docker container only.
			if is_detached; then
				docker exec --interactive --tty "${container_name}" sudo --login --user=user -- "/mnt/project/${project_subdir}/build.sh" "${@}"
			else
				# Execute/run the build script from the Docker container.
				docker_run "/mnt/project/${project_subdir}/build.sh" "${@}"
			fi
			;;
	esac
fi

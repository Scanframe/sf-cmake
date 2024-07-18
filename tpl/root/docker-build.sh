#!/bin/bash

script_dir="$(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build directory used for Docker to prevent mixing.
build_dir="${script_dir}/cmake-build/docker"
# Create the docker binary build directory.
mkdir -p "${script_dir}/cmake-build/docker"
# Function which runs the docker build.sh script.
function docker_run {
	local img_name hostname
	# Set the image name to be used.
	img_name="nexus.scanframe.com/gnu-cpp:dev"
	# Hostname for the docker container.
	hostname="cpp-builder"
	docker run \
		--rm \
		--interactive \
		--tty \
		--privileged \
		--net=host \
		--env LOCAL_USER="$(id -u):$(id -g)" \
		--env DISPLAY \
		--volume "${HOME}/.Xauthority:/home/user/.Xauthority:ro" \
		--volume "${script_dir}:/mnt/project:rw" \
		--volume "${build_dir}:/mnt/project/cmake-build:rw" \
		--workdir "/mnt/project/" \
		"${img_name}" "${@}"
}

if [[ $# -eq 0 ]]; then
	# Execute the build script from the Docker image.
	docker_run bash
else
	# Execute the build script from the Docker image.
	docker_run /mnt/project/build.sh "${@}"
fi

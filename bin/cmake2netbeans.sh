#!/usr/bin/env bash

# Stop on first error or pipeline errors.
set -o pipefail -e

# Get the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"

# Prints the help.
#
function show_help {
	echo "Usage: ${0} [options]
Creates a Netbeans v19+ project and files from a 'CMakePreset.json' file.
  Options:
    -h | --help  : Shows this help.
    -c | --create: Create the when it does not exist.
    -f | --force : Force recreation when the project exists.
"
}

# Check if the needed commands are installed.
COMMANDS=(
	"recode"
	"jq"
	"cmake"
)
for COMMAND in "${COMMANDS[@]}"; do
	if ! command -v "${COMMAND}" >/dev/null; then
		echo "Missing command '${COMMAND}' for this script"
		exit 1
	fi
done

# Do not allow zero command arguments.
if [[ $# -eq 0 ]]; then
	show_help
	exit 0
fi
##
# Writes the 'project.xml' file to stdout.
# Arg1: Name of the project project_name
#
function project_xml {
	cat <<EOD
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://www.netbeans.org/ns/project/1">
    <type>org.netbeans.modules.cnd.makeproject</type>
    <configuration>
        <data xmlns="http://www.netbeans.org/ns/make-project/1">
            <name>${1}</name>
            <c-extensions>c</c-extensions>
            <cpp-extensions>cpp,cc</cpp-extensions>
            <header-extensions>H,add,def,h,hh,hpp,inc,inl</header-extensions>
            <sourceEncoding>UTF-8</sourceEncoding>
            <make-dep-projects/>
            <sourceRootList>
                <sourceRootElem>.</sourceRootElem>
            </sourceRootList>
            <confList>
                <confElem>
                    <name>Default</name>
                    <type>0</type>
                </confElem>
            </confList>
            <formatting>
                <project-formatting-style>false</project-formatting-style>
            </formatting>
        </data>
    </configuration>
</project>
EOD
}

##
# Writes the 'configurations.xml' file's first part to stdout.
#
function configurations_xml_first {
	cat <<EOD
<?xml version="1.0" encoding="UTF-8"?>
<configurationDescriptor version="100">
	<logicalFolder name="root" displayName="root" projectFiles="true" kind="ROOT">
		<logicalFolder name="ExternalFiles" displayName="Important Files" projectFiles="false" kind="IMPORTANT_FILES_FOLDER">
			<itemPath>CMakeLists.txt</itemPath>
			<itemPath>Makefile</itemPath>
			<itemPath>nbproject/private/launcher.properties</itemPath>
		</logicalFolder>
	</logicalFolder>
	<sourceFolderFilter>^(nbproject)\$</sourceFolderFilter>
	<sourceRootList>
		<Elem>.</Elem>
	</sourceRootList>
	<projectmakefile>Makefile</projectmakefile>
	<confs>
EOD
}

##
# Writes the 'configurations.xml' file's first part to stdout.
# Arg1: Name of the configuration
# Arg2: Cmake preset name.
# Arg3: Cmake build directory
#
function configurations_conf {
	cat <<EOD
		<conf name="${1}" type="0">
			<toolsSet>
				<compilerSet>default</compilerSet>
				<dependencyChecking>false</dependencyChecking>
				<rebuildPropChanged>false</rebuildPropChanged>
			</toolsSet>
			<codeAssistance>
			</codeAssistance>
			<makefileType>
				<makeTool>
					<buildCommandWorkingDir>${3}</buildCommandWorkingDir>
					<buildCommand>\${MAKE} -f Makefile</buildCommand>
					<cleanCommand>\${MAKE} -f Makefile clean</cleanCommand>
					<executablePath>output/lnx/application</executablePath>
				</makeTool>
				<preBuild>
					<preBuildCommandWorkingDir>.</preBuildCommandWorkingDir>
					<preBuildCommand>\${CMAKE} --preset "${2}" -G "Unix Makefiles"</preBuildCommand>
					<preBuildFirst>true</preBuildFirst>
				</preBuild>
			</makefileType>
		</conf>
EOD
}

##
# Writes the 'configurations.xml' file's last part to stdout.
#
function configurations_xml_last {
	cat <<EOD
	</confs>
</configurationDescriptor>
EOD
}

# Set the project initial root.
project_root="$(pwd)"
# Initialize the flags.
flag_create=false
force_create=false

# Parse options.
temp=$(getopt -o 'hcf' --long 'help,create,force:' -n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "$temp"
unset temp
while true; do
	case "$1" in

		-h | --help)
			ShowHelp
			exit 0
			;;

		-c | --create)
			flag_create=true
			shift
			continue
			;;

		-f | --force)
			force_create=true
			shift
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

# Form the presets file location.
file_presets="${project_root}/CMakePresets.json"
# Check if the presets file is present.
if [[ -d "${file_presets}" ]]; then
	WriteLog "File '${project_root}/CMakePresets.json' is missing!"
fi

# Check if creation is ordered.
if ${flag_create}; then
	# Check if the project directory already exists.
	if [[ -d "${project_root}/nbproject" ]]; then
		if ${force_create}; then
			WriteLog "Overwriting existing project"
		else
			WriteLog "Project directory already exists!"
			exit 1
		fi
	fi
	# create the directory when it does not exist.
	mkdir --parents "${project_root}/nbproject"
	WriteLog "Creating project from presets"
	# Create the project.xml file.
	project_xml "$(basename "${project_root}")" >"${project_root}/nbproject/project.xml"
	# Create the configurations.xml file by writing the first part.
	configurations_xml_first >"${project_root}/nbproject/configurations.xml"
	# shellcheck disable=SC2034
	while read -r preset config; do
		preset="${preset//\"/}"
		WriteLog "~ Parsing preset '${preset}'"
		cfg_name="$(jq -r ".configurePresets[]|select(.name==\"${preset}\").displayName" "${file_presets}")"
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${preset}\").binaryDir" "${file_presets}")"
		binary_dir="${binary_dir//\$\{sourceDir\}\//}"
		WriteLog "~ Creating configuration '${cfg_name}' from preset '$preset' with build directory '${binary_dir}'."
		configurations_conf "${cfg_name}" "${preset}" "${binary_dir}" >>"${project_root}/nbproject/configurations.xml"
	done < <(cmake --list-presets | tail -n +3)
	configurations_xml_last >>"${project_root}/nbproject/configurations.xml"
fi

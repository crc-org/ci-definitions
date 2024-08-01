#!/bin/sh

source common.sh

# Envs
if [ "${DEBUG:-}" = "true" ]; then
    set -xuo 
fi
if [[ ! validate_envs ]] || [[ ! validate_assets_info ]] || [[ ! validate_s3_configuration ]]; then
    exit 1
fi
SSH=$(ssh_cmd)
SCP=$(scp_cmd)

# Create target on remote
echo "Create builder folder"
target_folder="/Users/${TARGET_HOST_USERNAME}"
$SSH "powershell.exe -c New-Item -ItemType directory -Path ${target_folder}"

# Copy resources
echo "Copy resources to target"
connection_string=$(remote_connection)
$SCP ${BUILDER_RESOURCES} "${connection_string}:${target_folder}"

# Run builder
echo "Running builder"
build_cmd=".\build.ps1 -datalakeURL ${DATALAKE_URL} -datalakeAcessKey ${DATALAKE_ACCESS_KEY} -datalakeSecretKey ${DATALAKE_SECRET_KEY} "
if [[ ! -z ${CRC_SCM+x} ]]; then
    build_cmd="${build_cmd} -crcSCM ${CRC_SCM} "
fi
if [[ -z ${CRC_VERSION+x} ]]; then 
    if [[ ! -z ${CUSTOM_BUNDLE_VERSION_VARIABLE+x} ]]; then 
        build_cmd="${build_cmd} -customBundleVersionVariable ${CUSTOM_BUNDLE_VERSION_VARIABLE} "
    fi
    if [[ ! -z ${CUSTOM_BUNDLE_VERSION+x} ]]; then 
        build_cmd="${build_cmd} -customBundleVersion ${CUSTOM_BUNDLE_VERSION} "
    fi
    if [[ ! -z ${PULL_REQUEST+x} ]]; then 
        build_cmd="${build_cmd} -crcSCMPR ${PULL_REQUEST} "
    fi
    if [[ ! -z ${REF+x} ]]; then 
        build_cmd="${build_cmd} -crcSCMRef ${REF} "
    fi
else 
    build_cmd="${build_cmd} -crcVersion ${CRC_VERSION} "
fi 

# UPLOAD PATH, create it as local env and then pass to remote execution
# creating it as local we can pick the value from the task
UPLOAD_PATH="${UPLOAD_PATH:-"$(upload_path)"}"
build_cmd="${build_cmd} -uploadPath ${UPLOAD_PATH} "

$SSH "cd ${target_folder}/crc-builder; ${build_cmd}"

# Cleanup
echo "Cleanup target"
$SSH "rm -r ${target_folder}/crc-builder -Force"
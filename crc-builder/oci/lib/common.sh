#!/bin/sh

# Validate required envs are setup to run the container
validate_envs () {
    local validate=1

    [[ -z "${TARGET_HOST+x}" ]] \
        && echo "TARGET_HOST required" \
        && validate=0

    [[ -z "${TARGET_HOST_USERNAME+x}" ]] \
        && echo "TARGET_HOST_USERNAME required" \
        && validate=0

    [[ -z "${TARGET_HOST_KEY_PATH+x}" && -z "${TARGET_HOST_PASSWORD+x}" ]] \
        && echo "TARGET_HOST_KEY_PATH or TARGET_HOST_PASSWORD required" \
        && validate=0

    return $validate
}

validate_assets_info () {
    local validate=1

    [[ -z "${TRAY_URL+x}" ]] \
        && echo "TRAY_URL required" \
        && validate=0

    return $validate
}

validate_s3_configuration () {
    local validate=1

    [[ -z "${DATALAKE_URL}" || -z "${DATALAKE_ACCESS_KEY}" || -z "${DATALAKE_SECRET_KEY}" ]] \
    && echo "s3 credentials are required, binary can not be updaloaded" \
    && validate=0

    return $validate
}

# Define remote connection
remote_connection () {
    local remote="${TARGET_HOST_USERNAME}@${TARGET_HOST}"
    if [[ ! -z "${TARGET_HOST_DOMAIN+x}" ]]; then
        remote="${TARGET_HOST_USERNAME}@${TARGET_HOST_DOMAIN}@${TARGET_HOST}"
    fi
    echo "${remote}" 
}

# scp connection string
scp_cmd () {
    local options='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    if [[ ! -z "${TARGET_HOST_KEY_PATH+x}" ]]; then
        echo "scp -r ${options} -i ${TARGET_HOST_KEY_PATH} "
    else
        echo "sshpass -p ${TARGET_HOST_PASSWORD} scp -r ${options} " 
    fi
}

# ssh connection string
ssh_cmd () {
    local options='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    local connection_string=$(remote_connection)
    if [[ ! -z "${TARGET_HOST_KEY_PATH+x}" ]]; then
        echo "ssh ${options} -i ${TARGET_HOST_KEY_PATH} ${connection_string}"
    else
        echo "sshpass -p ${TARGET_HOST_PASSWORD} ssh ${options}  ${connection_string}"
    fi
}

upload_path() {
    path="distributables/app"
    if [[ -z ${CRC_VERSION+x} ]]; then
        if [[ ! -z ${PULL_REQUEST+x} ]]; then
                echo "${path}/pr-${PULL_REQUEST}"
        else
                echo "${path}/${REF}"
        fi
    else
        echo "${path}/release/${CRC_VERSION}"
    fi
}
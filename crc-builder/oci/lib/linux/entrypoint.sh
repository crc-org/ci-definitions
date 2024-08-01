#!/bin/bash

# Imports
source ./common.sh

# Script to be executed on macos machine to build a crc macos installer
# and upload it to s3 compatible storage

# Execution is controlled based on ENVS:

# CUSTOM_BUNDLE_VERSION_VARIABLE When build based on a custom bundle need to set type: PODMAN_VERSION or OPENSHIFT_VERSION
# CUSTOM_BUNDLE_VERSION When build based on a custom bundle need to set version
# CRC_SCM: Source code repository for crc
# CRC_SCM_PR: Optional parameter to build an specific PR for crc
# CRC_SCM_REF: Optional parameter to build an specific PR for crc
# CRC_VERSION: Build based on crc version
# DATALAKE_URL: url for remote s3 compatible storage where build bits will be stored
# DATALAKE_ACCESS_KEY: remote s3 credential 
# DATALAKE_SECRET_KEY:remote s3 credential

# Defaults
GOARCH=$(go env GOARCH)
CRC_SCM="${CRC_SCM:-"https://github.com/code-ready/crc.git"}"
CRC_SCM_REF="${CRC_SCM_REF:-"main"}"
LIBVIRT_DRIVER_SCM="${LIBVIRT_DRIVER_SCM:-"https://github.com/code-ready/machine-driver-libvirt.git"}"
ADMINHELPER_SCM="${ADMINHELPER_SCM:-"https://github.com/code-ready/admin-helper.git"}"
UPLOAD_PATH="${UPLOAD_PATH:-"$(upload_path)"}"

set -exuo pipefail

# Upload content to S3 compatible 
# $1 remote path
# $2 local path to be uploaded
s3_upload() {
    [[ -z "${DATALAKE_URL}" || -z "${DATALAKE_ACCESS_KEY}" || -z "${DATALAKE_SECRET_KEY}" ]] \
    && echo "s3 credentials are required, binary can not be updaloaded" \
    && exit 1

    mc alias set datalake \
        ${DATALAKE_URL} \
        ${DATALAKE_ACCESS_KEY} \
        ${DATALAKE_SECRET_KEY} \
        --api S3v4

    # Create bucket if not exits
    mc mb "datalake/${1}"
    # Copy files to datalake
    mc cp "${2}/crc-linux-${GOARCH}.tar.xz" "datalake/${1}/crc-linux-${GOARCH}.tar.xz"
    mc cp "${2}/sha256sum.txt" "datalake/${1}/crc-linux-${GOARCH}.tar.xz.sha256sum"

    # Make bucket public
    # mc anonymous set public "datalake/${1}/"
}

#####################
####### MAIN ########
#####################

# Custom setup for git
git config --global http.version "HTTP/1.1"
git config --global http.lowSpeedLimit 0      
git config --global http.lowSpeedTime 999999 

# Get crc code
git clone ${CRC_SCM}

# Fetch according to parameters provided
if [[ -z ${CRC_VERSION+x} ]]; then 
    CRC_VERSION_PARTIAL=$(date +'%y.%m.%d')
    if [[ ! -z ${CRC_SCM_PR+x} ]]; then 
        git -C crc fetch origin pull/${CRC_SCM_PR}/head:pr-${CRC_SCM_PR}
        git -C crc checkout pr-${CRC_SCM_PR}
    else
        git -C crc checkout ${CRC_SCM_REF} 
    fi 
    sed -i.bak "s/CRC_VERSION = .*/CRC_VERSION = ${CRC_VERSION_PARTIAL}/g" crc/Makefile
else 
    git -C crc checkout "tags/v${CRC_VERSION}" -b "v${CRC_VERSION}"
fi

# Build hyperkit driver
git clone ${LIBVIRT_DRIVER_SCM}
pushd machine-driver-libvirt
mdl_version_line=$(cat pkg/libvirt/constants.go | grep DriverVersion)
mdl_version=${mdl_version_line##*=} 
mdl_version=$(echo $mdl_version | xargs)
go build -v -o crc-driver-libvirt-local ./cmd/machine-driver-libvirt
popd

# Build admin-helper
git clone ${ADMINHELPER_SCM}
admin_version_line=$(cat admin-helper/crc-admin-helper.spec.in | grep Version:)
admin_version=${admin_version_line##*:} 
admin_version=$(echo $admin_version | xargs)
make -C admin-helper out/linux-${GOARCH}/crc-admin-helper VERSION=$admin_version 

# Build linux distributable with custom admin helper
pushd crc
mkdir custom_embedded
cp ./../machine-driver-libvirt/crc-driver-libvirt-local custom_embedded/crc-driver-libvirt-${GOARCH}
cp ./../admin-helper/out/linux-${GOARCH}/crc-admin-helper custom_embedded/crc-admin-helper-linux-${GOARCH}
# Match admin-helper version with latest from master head
sed -i "s/crcAdminHelperVersion.*=.*/crcAdminHelperVersion = \"${admin_version}\"\n/g" pkg/crc/version/version.go
# Match machine-driver-libvirt version with latest from master head
sed -i "s/MachineDriverVersion =.*/MachineDriverVersion = \"${mdl_version}\"/g" pkg/crc/machine/libvirt/constants.go
make linux-release CUSTOM_EMBED=true EMBED_DOWNLOAD_DIR=custom_embedded
# make release CUSTOM_EMBED=true EMBED_DOWNLOAD_DIR=custom_embedded
popd

# Upload
s3_upload ${UPLOAD_PATH} crc/release
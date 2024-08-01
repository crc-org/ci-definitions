#!/bin/sh
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
CRC_SCM="${CRC_SCM:-"https://github.com/code-ready/crc.git"}"
CRC_SCM_REF="${CRC_SCM_REF:-"main"}"
ADMINHELPER_SCM="${ADMINHELPER_SCM:-"https://github.com/code-ready/admin-helper.git"}"
VFKIT_SCM="${VFKIT_SCM:-"https://github.com/code-ready/vfkit.git"}"

set -exuo pipefail

# Upload content to S3 compatible 
# $1 remote path
# $2 local path to be uploaded
s3_upload() {
    [[ -z "${DATALAKE_URL}" || -z "${DATALAKE_ACCESS_KEY}" || -z "${DATALAKE_SECRET_KEY}" ]] \
    && echo "s3 credentials are required, binary can not be updaloaded" \
    && exit 1

    ./mc alias set datalake \
        ${DATALAKE_URL} \
        ${DATALAKE_ACCESS_KEY} \
        ${DATALAKE_SECRET_KEY} \
        --api S3v4

    # Create bucket if not exits
    ./mc mb "datalake/${1}"
    # Copy files to datalake
    ./mc cp "${2}/crc-macos-installer.pkg" "datalake/${1}/crc-macos-installer.pkg"
    ./mc cp "${2}/crc-macos-installer.sha256sum" "datalake/${1}/crc-macos-installer.pkg.sha256sum"
    # Make bucket public
    # ./mc anonymous set public "datalake/${1}/"
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
    # In case we build for a custom bundle we need to match the version
    # if [[ ! -z ${CUSTOM_BUNDLE_VERSION_VARIABLE+x} ]] && [[ ! -z ${CUSTOM_BUNDLE_VERSION+x} ]]; then 
    #     sed -i.bak "s/${CUSTOM_BUNDLE_VERSION_VARIABLE} ?= .*/${CUSTOM_BUNDLE_VERSION_VARIABLE} = ${CUSTOM_BUNDLE_VERSION}/g" crc/Makefile
    # fi
    sed -i.bak "s/CRC_VERSION = .*/CRC_VERSION = ${CRC_VERSION_PARTIAL}/g" crc/Makefile
else 
    git -C crc checkout "tags/v${CRC_VERSION}" -b "v${CRC_VERSION}"
fi

# Build admin-helper
git clone ${ADMINHELPER_SCM}
admin_version_line=$(cat admin-helper/crc-admin-helper.spec.in | grep Version:)
admin_version=${admin_version_line##*:} 
admin_version=$(echo $admin_version | xargs)
make -C admin-helper out/macos-amd64/crc-admin-helper VERSION=$admin_version

# Build vfkit
git clone ${VFKIT_SCM}
sudo make -C vfkit all

# Build pkg
pushd crc
# custom resources to be included
mkdir custom_embedded
cp ./../admin-helper/out/macos-amd64/crc-admin-helper custom_embedded/crc-admin-helper-darwin
cp ./../vfkit/out/vfkit custom_embedded/vfkit
cp ./../vfkit/vf.entitlements custom_embedded/vf.entitlements

# Match admin-helper version with latest from master head
sed -i '' "s/crcAdminHelperVersion =.*/crcAdminHelperVersion = \"${admin_version}\"/g" pkg/crc/version/version.go

# create pkg
make out/macos-universal/crc-macos-installer.pkg NO_CODESIGN=1 CUSTOM_EMBED=true EMBED_DOWNLOAD_DIR=custom_embedded
# check sum
pushd out/macos-universal 
shasum -a 256 * > crc-macos-installer.sha256sum
popd
popd

# Upload
s3_upload ${UPLOAD_PATH} crc/out/macos-universal
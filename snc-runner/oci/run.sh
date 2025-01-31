#!/bin/bash
#
# Usage run.sh -ocp-ps-path /Users/.../ps -ocp-version 4.1X.X [-ocp-extended-cert enabled] \
#               -s3-url https://amazon.es/ -s3-ak XXXX -s3-sk XXXX -s3-path nightly/ocp/4.1X.X \
#               [-scm https://github.com/code-ready/snc.git] [-ref master] [-pr] [-ocp-mirror] 

# Define error handler function
function handle_error() {
    FILENAME_PATTERN="log-bundle-*.tar.gz"
    OUTPUT_FILENAME="log-bundle.tar.gz"

    set -exuo pipefail

    pushd crc-tmp-install-data
    log_filename=$(find . -name ${FILENAME_PATTERN} -printf "%f\n" | grep . || true)

    # Enforce ntp sync
    sudo timedatectl set-ntp on
    # wait for sync
    while [[ $(timedatectl status | grep 'System clock synchronized' | grep -Eo '(yes|no)') = no ]]; do
      sleep 2
    done

    if [ "${log_filename}" != "" ]; then
      mc cp  ${log_filename} datalake/${s3Path}
    fi

  # Optionally exit the script gracefully
  exit 1
}

# Parameters
# Default values
scm="https://github.com/code-ready/snc.git"
ref="master"
export SNC_USE_PATCHED_RELEASE_IMAGE="enabled"
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -scm)
        scm="$2"
        shift 
        shift 
        ;;
        -ref)
        ref="$2"
        shift 
        shift 
        ;;
        -pr)
        pr="$2"
        shift 
        shift 
        ;;
        -ocp-ps-path)
        export OPENSHIFT_PULL_SECRET_PATH="$2"
        shift 
        shift 
        ;;
        -ocp-version)
        export OPENSHIFT_VERSION="$2"
        shift 
        shift 
        ;;
        -ocp-mirror)
        export MIRROR="$2"
        shift 
        shift 
        ;;
        -ocp-extended-cert)
        export SNC_USE_PATCHED_RELEASE_IMAGE="$2"
        shift 
        shift 
        ;;
        -s3-url)
        s3Url="$2"
        shift 
        shift 
        ;;
        -s3-ak)
        s3AccessKey="$2"
        shift 
        shift 
        ;;
        -s3-sk)
        s3SecretKey="$2"
        shift 
        shift 
        ;;
        -s3-path)
        s3Path="$2"
        shift 
        shift 
        ;;
        *)    # unknown option
        shift 
        ;;
    esac
done

set -exuo pipefail

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Validations
if [[ -z ${OPENSHIFT_PULL_SECRET_PATH+x} ]] || [[ -z ${OPENSHIFT_VERSION+x} ]]; then 
    echo "OPENSHIFT_PULL_SECRET_PATH and OPENSHIFT_VERSION should be provided"
    exit 1
fi

# Set datalake for uploading results / error logs
if ! which mc >/dev/null; then
    if [[ $(uname -m) == "x86_64" ]]; then
        mcurl="https://dl.min.io/client/mc/release/linux-amd64/mc"
    else
        mcurl="https://dl.min.io/client/mc/release/linux-arm64/mc"
    fi
    sudo curl ${mcurl} -o /usr/local/bin/mc
    sudo chmod +x /usr/local/bin/mc
fi
mc alias set datalake ${s3Url} \
    ${s3AccessKey} \
    ${s3SecretKey} \
    --api S3v4
mc mb -p datalake/${s3Path}

# Get SNC code
git clone ${scm}
pushd snc
if [[ ! -z ${pr+x} ]]; then 
    git fetch origin pull/${pr}/head:pr-${pr}
    git checkout pr-${pr}
else
    git checkout ${ref} 
fi 

# Run SNC
trap handle_error ERR
./snc.sh

# Create disks 
SNC_GENERATE_LINUX_BUNDLE=1 ./createdisk.sh crc-tmp-install-data
mkdir -p ${OPENSHIFT_VERSION}
mv *.crcbundle ${OPENSHIFT_VERSION}/
pushd ${OPENSHIFT_VERSION}
# Standarize arch names
arch=$(uname -m)
if [[ ${arch} == "aarch64" ]]; then
    arch="arm64"
fi
sha256sum * > bundles.${arch}.sha256
popd

# Upload disks
mc cp -r ${OPENSHIFT_VERSION}/* datalake/${s3Path}

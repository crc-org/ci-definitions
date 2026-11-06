#!/bin/bash

# Parameters
crcSCM="https://github.com/code-ready/crc.git"
crcSCMPR=''
crcSCMRef='main'
vfkitSCMRef='main'
targetFolder="crc-builder"
uploadPath='crc-binaries'
datalakeURL=''
datalakeAcessKey=''
datalakeSecretKey=''
datalakeRegion=''

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -crcSCM)
        crcSCM="$2"
        shift 
        shift 
        ;;
        -crcSCMPR)
        crcSCMPR="$2"
        shift 
        shift 
        ;;
        -crcSCMRef)
        crcSCMRef="$2"
        shift 
        shift 
        ;;
        -vfkitSCMRef)
        vfkitSCMRef="$2"
        shift
        shift
        ;;
        -targetFolder)
        targetFolder="$2"
        shift 
        shift 
        ;;
        -uploadPath)
        uploadPath="$2"
        shift 
        shift 
        ;;
        -datalakeURL)
        datalakeURL="$2"
        shift 
        shift 
        ;;
        -datalakeAcessKey)
        datalakeAcessKey="$2"
        shift 
        shift 
        ;;
        -datalakeSecretKey)
        datalakeSecretKey="$2"
        shift 
        shift 
        ;;
        -datalakeRegion)
        datalakeRegion="$2"
        shift
        shift
        ;;
        *)    # unknown option
        shift 
        ;;
    esac
done

set -exuo pipefail

# Upload content to S3 compatible 
# $1 remote path
# $2 local path to be uploaded
s3_upload() {
    set +x
    if [[ -z "$datalakeURL" || -z "$datalakeAcessKey" || -z "$datalakeSecretKey" || -z "$datalakeRegion" ]]; then
        echo "S3 endpoint, region, access key, and secret key are required" >&2
        exit 1
    fi

    export RCLONE_CONFIG_DATALAKE_TYPE=s3
    export RCLONE_CONFIG_DATALAKE_PROVIDER=AWS
    export RCLONE_CONFIG_DATALAKE_ACCESS_KEY_ID="$datalakeAcessKey"
    export RCLONE_CONFIG_DATALAKE_SECRET_ACCESS_KEY="$datalakeSecretKey"
    export RCLONE_CONFIG_DATALAKE_REGION="$datalakeRegion"
    if [[ -n "$datalakeURL" && "${datalakeURL%/}" != "https://s3.amazonaws.com" ]]; then
        export RCLONE_CONFIG_DATALAKE_ENDPOINT="$datalakeURL"
    fi
    set -x

    ./rclone copyto "${2}/crc-macos-installer.pkg" "datalake:${1}/crc-macos-installer.pkg"
    ./rclone copyto "${2}/crc-macos-installer.sha256sum" "datalake:${1}/crc-macos-installer.pkg.sha256sum"
}

#####################
####### MAIN ########
#####################

cd $targetFolder

# Custom setup for git
git config --global http.version "HTTP/1.1"
git config --global http.lowSpeedLimit 0      
git config --global http.lowSpeedTime 999999 

# Get crc code
git clone $crcSCM

# Fetch according to parameters provided
CRC_VERSION_PARTIAL=$(date +'%y.%m.%d')
if [ ! -z "$crcSCMPR" ]
then
    git -C crc fetch origin pull/$crcSCMPR/head:pr-$crcSCMPR
    git -C crc checkout pr-$crcSCMPR
else
    git -C crc checkout $crcSCMRef 
fi
sed -i.bak "s/CRC_VERSION = .*/CRC_VERSION = ${CRC_VERSION_PARTIAL}/g" crc/Makefile


# Build admin-helper
git clone https://github.com/code-ready/admin-helper.git
admin_version_line=$(cat admin-helper/crc-admin-helper.spec.in | grep Version:)
admin_version=${admin_version_line##*:} 
admin_version=$(echo $admin_version | xargs)
make -C admin-helper macos-universal VERSION=$admin_version

# Build vfkit
git clone https://github.com/code-ready/vfkit.git
git -C vfkit checkout $vfkitSCMRef
make -C vfkit all

# Build pkg
pushd crc
# custom resources to be included
mkdir custom_embedded
cp ./../admin-helper/out/macos-universal/crc-admin-helper custom_embedded/crc-admin-helper-darwin
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
s3_upload $uploadPath crc/out/macos-universal
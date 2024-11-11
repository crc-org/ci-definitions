#!/bin/sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SCRIPT_DIR}/lib.sh"

# Parameters
aBaseURL=''
aName=''
aSHAName='sha256sum.txt'
targetPath=''
freshEnv='true'
download='true'
install='false'
debug='false'


while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -aBaseURL)
        aBaseURL="$2"
        shift 
        shift 
        ;;
        -aName)
        aName="$2"
        shift 
        shift 
        ;;
        -aSHAName)
        aSHAName="$2"
        shift 
        shift 
        ;;
        -targetPath)
        targetPath="$2"
        shift 
        shift 
        ;;
        -freshEnv)
        freshEnv="$2"
        shift 
        shift 
        ;;
        -download)
        download="$2"
        shift 
        shift 
        ;;
        -install)
        install="$2"
        shift 
        shift 
        ;;
        -debug)
        debug="$2"
        shift 
        shift 
        ;;
        *)    # unknown option
        shift 
        ;;
    esac
done

# $1 downloadle url
download () {
    local binary_url="${1}"
    local download_result=1
    while [[ ${download_result} -ne 0 ]]
    do
        curl --insecure -LO -C - ${binary_url}
        download_result=$?
    done
}

##############
#### MAIN ####
##############
if [ "$debug" = "true" ]; then
    set -xuo 
fi

# Ensure fresh environment
if [[ $freshEnv == 'true' ]]; then
    echo "removing previous crc"
    force_fresh_environment
fi

mkdir -p $targetPath
pushd $targetPath

# DOWNLOAD
if [[ $download == "true" ]]; then
    echo "downlading $aName"
    
    # Download sha256sum
    curl --insecure -LO "$aBaseURL/$aSHAName"
    # Check if require download
    required_download $aName $aSHAName
    if [[ ${?} -ne 0 ]]; then
        # Required to download
        rm -f $aName
        dURL="$aBaseURL/$aName"
        download $dURL
        check_download $aName $aSHAName
        if [[ ${?} -ne 0 ]]; then 
            echo "Error with downloading $aName"
            exit 1
        fi
    fi
fi

# INSTALLATION
if [[ $install == 'true' ]]; then
    echo "installing crc"
    installCRC $aName
fi 

popd
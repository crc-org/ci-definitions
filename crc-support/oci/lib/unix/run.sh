#!/bin/sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SCRIPT_DIR}/lib.sh"

# Parameters
aBaseURL=''
aBaseURLFallback=''
aName=''
aSHAName='sha256sum.txt'
targetPath=''
freshEnv='true'
download='true'
install='false'
debug='false'
delete='false'

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -aBaseURLFallback)
        aBaseURLFallback="$2"
        shift
        shift
        ;;
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
        -delete)
        delete="$2"
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

download_check () {
    local name="$1"
    local base="$2"
    local sha="$3"

    # Required to download
    rm -f $name
    dURL="$base/$name"
    download $dURL
    check_download $name $sha
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
        local doExit=0
        download_check "$aName" "$aBaseURL" "$aSHAName"
        if [[ ${?} -ne 0 ]]; then
            doExit=1
            if [[ ${aBaseURLFallback} != '' ]]; then
                doExit=0
                echo "Error with downloading $aName, using fallback"
                download_check "$aName" "$aBaseURLFallback" "$aSHAName"
                if [[ ${?} -ne 0 ]]; then
                    doExit=1
                fi
            fi
        fi
        if [[ ${doExit} -eq 1 ]]; then
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

# Remove old folders
if [[ $delete == 'true' ]]; then
    cd ..
    ls -lh
    echo "removing 21 days ago folders"
    for dir in */; do
        # find the latest changed file
        latest_file=`ls -t $dir | head -n 1`
        # Check if the latest file is older than 21 days
        if find $dir/$latest_file -type f -mtime +21 | grep -q .; then
            echo "removing  $dir"
            rm -r $dir
        fi
    done
    ls -lh
fi

popd
#!/bin/sh

# Remove any content from any previous crc installation
force_fresh_environment () {
    crc cleanup 2>/dev/null
    sudo kill -9 $(pgrep crc-tray | head -1) 2>/dev/null
    sudo rm -rf /Applications/Red\ Hat\ OpenShift\ Local.app/
    sudo rm /usr/local/bin/crc
    rm -rf ~/.crc/
}

# $1 file name for the asset to be checked
# $2 file name holding the shasum value
# Return 1 if true 0 false 
required_download () {
    if [[ ! -f ${1} ]]; then
        return 1
    fi
    cat ${2} | grep ${1} | shasum -a 256 -c -
    return ${?}
}

# $1 file name for the asset to be checked
# $2 file name holding the shasum value
# Return 1 if true 0 false 
check_download() {
    cat ${2} | grep ${1} | shasum -a 256 -c -
    return ${?}
} 

# $1 file name for crc installer
installCRC() {
    sudo installer -pkg ${1} -target /
}



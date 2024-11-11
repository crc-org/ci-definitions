#!/bin/sh

# Remove any content from any previous crc installation
force_fresh_environment () {
    crc cleanup
    sudo rm -rf /usr/local/bin/crc
    rm -rf ~/.crc/
}

# $1 file name for the asset to be checked
# $2 file name holding the shasum value
# Return 1 if true 0 false 
required_download () {
    if [[ ! -f ${1} ]]; then
        return 1
    fi
    cat ${2} | grep ${1} | sha256sum -c -
    return ${?}
    
}

# $1 file name for the asset to be checked
# $2 file name holding the shasum value
# Return 1 if not valid, 0 if valid
check_download() {
    cat ${2} | grep ${1} | sha256sum -c -
    return ${?}
} 

# $1 file name for crc installer
installCRC() {
    if [[ ${1} == *.tar.xz ]]; then
        sudo tar xvf "${1}" --strip-components 1 -C /usr/local/bin/
    else
        sudo cp ${1} /usr/local/bin/
    fi
}

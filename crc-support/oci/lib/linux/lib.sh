#!/bin/sh

# Remove any content from any previous crc installation
force_fresh_environment () {
    crc cleanup
    sudo rm -rf /usr/local/bin/crc
    rm -rf ~/.crc/
}

# Return 1 if true 0 false 
required_download () {
    if [[ ! -f ${DOWNLOADED_ITEM_NAME} ]]; then
        return 1
    fi
    cat ${SHASUM_FILE} | grep ${DOWNLOADED_ITEM_NAME} | sha256sum -c -
    return ${?}
}

# $1 downloadle url
# Return 1 if not valid, 0 if valid
check_download() {
    cat ${SHASUM_FILE} | grep ${DOWNLOADED_ITEM_NAME} | sha256sum -c -
    return ${?}
} 


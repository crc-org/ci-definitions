#!/bin/sh

# Remove any content from any previous crc installation
force_fresh_environment () {
    crc cleanup 2>/dev/null
    sudo kill -9 $(pgrep crc-tray | head -1) 2>/dev/null
    sudo rm -rf /Applications/Red\ Hat\ OpenShift\ Local.app/
    sudo rm /usr/local/bin/crc
    rm -rf ~/.crc/
}

# Return 1 if true 0 false 
required_download () {
    if [[ ! -f $aName ]]; then
        return 1
    fi
    cat $aSHAName | grep $aName | shasum -a 256 -c -
    return ${?}
}

# $1 downloadle url
# Return 1 if not valid, 0 if valid
check_download() {
    cat $aSHAName | grep $aName | shasum -a 256 -c -
    return ${?}
} 



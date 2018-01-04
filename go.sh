#!/bin/bash

# include commonly used functions and variables. 
source common/boilerplate.sh


declare -a ON_TRAP_COMMANDS

readonly OPENWRT_GIT_REPO='git://git.openwrt.org/openwrt/openwrt.git'
readonly OPENWRT_TARGET='openwrt'

function clone_repository() {
    LogLine "Cloning git repository from ${OPENWRT_GIT_REPO} to ${OPENWRT_TARGET}"
    git clone --verbose ${OPENWRT_GIT_REPO} ${OPENWRT_TARGET}
    LogLine "Cloning complete."
}

function copy_base_structure() {
    LogLine "Copying base structure files to repo."
    cp --verbose --recursive ./structure/* ./${OPENWRT_TARGET}/
}

function apply_base_patches() {
    LogLine "Applying base patches..."
    common/patch-all.sh patches ${OPENWRT_TARGET}
}

function apply_luci_patches() {
    LogLine "Applying luci patches..."
    common/patch-all.sh luci/patches ${OPENWRT_TARGET}/feeds/luci
}

function apply_packages_patches() {
    LogLine "Applying packages patches..."
    common/patch-all.sh packages/patches ${OPENWRT_TARGET}/feeds/packages
}

function copy_luci_structure() {
    LogLine "Copying luci structure to repo."
    cp --verbose --recursive ./luci/structure/* ./${OPENWRT_TARGET}/feeds/luci/
}

function copy_packages_structure() {
    LogLine "Copying packages structure to repo."
    cp --verbose --recursive ./packages/structure/* ./${OPENWRT_TARGET}/feeds/packages/
}

function add_on_exit()
{
    local n=${#ON_TRAP_COMMANDS[*]}
    ON_TRAP_COMMANDS[$n]="$*"
    if [[ $n -eq 0 ]]; then
        LogLine "Appending Trap: $*"
        trap on_exit EXIT
    fi
}

function on_exit()
{
    for i in "${ON_TRAP_COMMANDS[@]}"
    do
        echo "on_exit: $i"
        eval $i
    done

    exit 1
}

function main() {
    LogLine "Applying custom OpenWrt build..."
    shopt -s dotglob

    clone_repository
    copy_base_structure
    apply_base_patches

    LogLine "Updating OpenWrt feeds..."
    ${OPENWRT_TARGET}/scripts/feeds update -a

    copy_luci_structure
    copy_packages_structure
    apply_luci_patches
    apply_packages_patches

    LogLine "Reupdating feeds..."
    ${OPENWRT_TARGET}/scripts/feeds update -i

    LogLine "Installing packages..."
    ${OPENWRT_TARGET}/scripts/feeds install -a
    
    cp ${OPENWRT_TARGET}/.config.init ${OPENWRT_TARGET}/.config

    make -C ${OPENWRT_TARGET} defconfig
    make -C ${OPENWRT_TARGET} download
}

main "$@"

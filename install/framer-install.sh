#!/bin/bash
readonly FRAMER_GIT_REPOSITORY="https://github.com/McShauno/openwrt-framer.git"
readonly FRAMER_RELEASE_BRANCH="release"
readonly FRAMER_TARGET_DIR="openwrt-framer"

command_exists() {
    local executable=$1
    command -v $executable
}

fail() {
    local failMessage=$1
    logline "Failure: $failMessage"
    exit 1
}

logline() {
    local message=$1
    echo ""
    echo $message
}

clone_repository() {
    git clone -b $FRAMER_RELEASE_BRANCH --single-branch $FRAMER_GIT_REPOSITORY $FRAMER_TARGET_DIR
    rm -rf $FRAMER_TARGET_DIR/.git
}

main() {
    logline "Installing openwrt-framer."
    command_exists git || fail "Could not find git."
    logline "Cloning release branch."
    clone_repository || fail "Unable to clone repository."
}

main "$@"

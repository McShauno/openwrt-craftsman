#!/bin/bash
DEBUG_SHELL=1
readonly FRAMERSCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# include commonly used functions and variables. 
source ${FRAMERSCRIPT_DIR}/../common/boilerplate.sh
decho "frame.sh execution directory is ${FRAMERSCRIPT_DIR}"

declare -a ON_TRAP_COMMANDS

readonly FRAMER_DIR=$(pwd)
readonly VERSION_FILE="files/etc/framer.build"
readonly PACKAGE_TARGET="package"
readonly REPOSITORY_TARGET="${PACKAGE_TARGET}/openwrt"
shopt -s expand_aliases
shopt -s dotglob

create_version() {
    local target=$1
    local framer_version=$2
    local frame_prefix="openwrt_framer beta"
    local framer_file=${target}/${VERSION_FILE}
    local date_format=$(date -u "+%F T %H:%M:%S UTC")
    local openwrt_version=$(cd ${target} && scripts/getver.sh)
    local release_nick=$(grep RELEASE: ${target}/include/{version,toplevel}.mk | cut -d "=" -f 2)
    local openwrt_version_stamp="OpenWrt ${release_nick} ${openwrt_version} / ${date_format}"
    local main_version=$(cd ${target} && git show --format="%cd %h %s" --abbrev=7 --date=short | head -n 1 | cut -b1-60)
    local luci_version=$(cd ${target}/feeds/luci && git show --format="%cd %h %s" --abbrev=7 --date=short | head -n 1 | cut -b1-60)
    local packages_version=$(cd ${target}/feeds/packages && git show --format="%cd %h %s" --abbrev=7 --date=short | head -n 1 | cut -b1-60)
    local routing_version=$(cd ${target}/feeds/routing && git show --format="%cd %h %s" --abbrev=7 --date=short | head -n 1 | cut -b1-60)

    echo "${openwrt_version_stamp}" > ${framer_file}
    echo "---" >> ${framer_file}
    echo "framer    v${framer_version}" >> ${framer_file}
    echo "main      ${main_version}" >> ${framer_file}
    echo "luci      ${luci_version}" >> ${framer_file}
    echo "packages  ${packages_version}" >> ${framer_file}
    echo "routing   ${routing_version}" >> ${framer_file}

    date +%s > ${target}/version.date
}

get_construct() {
    local construct_name=$1
    echo $CONSTRUCT | ${FRAMERSCRIPT_DIR}/../common/jq -r $construct_name
}

apply_patches() {
    logline "Appylying patches..."
    local patch_build_target=$1
    local patch_directory=$2
    local patch_build_directory=$3

    logline "Patch build target: ${patch_build_target}"
    logline "Patch directory: ${patch_directory}"
    logline "Patch build directory: ${patch_build_directory}"

    local files=${patch_directory}/*.patch
    local total_files=$(ls -1 $files | wc -l)

    logline "Total patch files to process: $total_files"

    for patch_file in ${files}
    do
        local filename=$(basename "$patch_file")
        logline "Applying patch file ${filename}"
        patch --verbose -N -d $patch_build_target  -p1 -i ${patch_build_directory}/${filename}
    done
}

clone_repository() {
    local repo=$1
    local branch=$2
    local target=$3
    if [ ! -d "$target" ]; then
        logline "Cloning git repository from ${repo} - ${branch} to ${target}"
        git clone -b $branch --single-branch $repo $target
        logline "Cloning complete."
    else
        logline "$target directory already exists, will not clone."
    fi
}

construct_exists() {
    if [ ! -e "./construct.json" ];
    then
        fail "Could not find construct.json file."
    fi
}

execute_external() {
    local external_script=$1
    logline "Sourcing ${external_script}..."
    if [ -e $1 ]
    then
        source $1
    else
        logline "Warning: $1 does not exist."
    fi
}

copy_structure() {
    local structure=$1
    local target=$2
    logline "Copying ${structure} structure files to repo - ${target}"
    cp --update --verbose --recursive ./${structure}/* ./${target}/
}

add_on_exit()
{
    local n=${#ON_TRAP_COMMANDS[*]}
    ON_TRAP_COMMANDS[$n]="$*"
    if [[ $n -eq 0 ]]; then
        logline "Appending Trap: $*"
        trap on_exit EXIT
    fi
}

on_exit()
{
    for i in "${ON_TRAP_COMMANDS[@]}"
    do
        echo "on_exit: $i"
        eval $i
    done

    exit 1
}
execute_plans() {
    local target=$1
    while 
        IFS= read -r plan_name &&
        IFS= read -r plan_pre &&
        IFS= read -r plan_structure &&
        IFS= read -r plan_patches &&
        IFS= read -r plan_pos;
    do
        logline "Executing plan $plan_name."
        execute_external ${PACKAGE_TARGET}/${plan_name}/${plan_pre}
        copy_structure ${PACKAGE_TARGET}/${plan_name}/${plan_structure} ${target}/feeds/${plan_name}
        apply_patches ${target}/feeds/${plan_name} ${PACKAGE_TARGET}/${plan_name}/${plan_patches} ../../../${plan_name}/${plan_patches}
        execute_external ${PACKAGE_TARGET}/${plan_name}/${plan_pos}
    done < <(echo $CONSTRUCT | ${FRAMERSCRIPT_DIR}/../common/jq -r '.plans[] | (.name, .prebuild, .structureDirectory, .patchesDirectory, .postbuild)')
}

main() {
    construct_exists
    readonly CONSTRUCT=$(cat construct.json)

    logline "Applying custom OpenWrt build..."

    local uri=$(get_construct '.uri')
    local branch=$(get_construct '.branch')
    local construct_name=$(get_construct '.name')
    local repository_url=$(get_construct '.openwrt.repository.url')
    local repository_branch=$(get_construct '.openwrt.repository.branch')
    local framer_version=$(get_construct '.version')

    logline "Cloning package from ${uri}"

    clone_repository $uri $branch $PACKAGE_TARGET

    logline "Cloning OpenWrt repository"
    clone_repository $repository_url $repository_branch $REPOSITORY_TARGET

    local base_pre=$(get_construct '.base.prebuild')
    local base_structure=$(get_construct '.base.structureDirectory')
    local base_patches=$(get_construct '.base.patchesDirectory')
    local base_post=$(get_construct '.base.postbuild')

    logline "Executing base prebuild script ${base_pre}."
    execute_external $PACKAGE_TARGET/${base_pre}

    logline "Copying base structure."
    copy_structure ${PACKAGE_TARGET}/$base_structure $REPOSITORY_TARGET

    logline "Applying base patches."
    apply_patches $REPOSITORY_TARGET ${PACKAGE_TARGET}/${base_patches} ../${base_patches}

    logline "Executing base post script ${base_post}."
    execute_external ${PACKAGE_TARGET}/${base_post}

    logline "Executing additional plans..."
    execute_plans ${REPOSITORY_TARGET}

    local final_script=$(get_construct '.finalize')

    logline "Executing final script..."
    execute_external ${PACKAGE_TARGET}/${final_script}

    create_version ${REPOSITORY_TARGET} ${framer_version}

    logline "Complete."
}

main "$@"

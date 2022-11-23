#!/bin/bash

PURGATORY_PROTOCOL_LABELING="Purgatory Protocol"
PURGATORY_PROTOCOL_PLATFORM="Debian"
PURGATORY_PROTOCOL_VERMAJOR=1
PURGATORY_PROTOCOL_VERMINOR=1
PURGATORY_PROTOCOL_VERPATCH=0

PURGATORY_PROTOCOL_PASSWORD=""

BAR="---"

print_none() { printf "(none)\n"; }

print_ruler() { printf "%*s\n" 9 "" | sed "s/ /${BAR} /g"; }

print_segment() { printf "\n%s %s: %s\n" "${BAR}" "${1}" "${2}" && print_ruler; }

remove_named_matching()
{
    local infostr=$1
    local dirpath=$( envsubst <<< "$2" )
    local pattern=$3
    printf "  %s:\n" "${infostr}"
    DELETION_TARGETS=$( find "${dirpath}" -type d -regex "${pattern}" )
    if [[ -z "${DELETION_TARGETS}" ]]; then
        printf "    "
        print_none
    else
        while read -r -u 9 FILEPATH || [ -n "${FILEPATH}" ];
        do
            printf "    %s\n" "${FILEPATH}"
            yes | rm -fr "${FILEPATH}"
        done 9<<<"${DELETION_TARGETS}";
    fi
}

run_show_none()
{
    local output=$( "${@}" | tee /dev/tty )
    if [[ -z "${output}" ]]; then
        print_none
    fi 
}

super_user_do()
{
    if [[ "$UID" -eq 0 ]]; then
        "${@}" <<< "${PURGATORY_PROTOCOL_PASSWORD}"
    else
        sudo -S -p '' "${@}" <<< "${PURGATORY_PROTOCOL_PASSWORD}"
    fi
}

super_user_prompt()
{
    print_ruler
    printf '%s %s [%s]\n' "${BAR}" "${PURGATORY_PROTOCOL_LABELING}" "${PURGATORY_PROTOCOL_PLATFORM}"
    printf '%s Version %d.%d.%d\n' "${BAR}" \
        "${PURGATORY_PROTOCOL_VERMAJOR}" \
        "${PURGATORY_PROTOCOL_VERMINOR}" \
        "${PURGATORY_PROTOCOL_VERPATCH}"
    print_ruler
    printf "\n"
    
    if [ "$(id -nu)" != "root" ]; then
        printf 'Invoking %s requires "super-user" privilege.\n' "${PURGATORY_PROTOCOL_LABELING}"
        sudo -k
        read -s -p "[sudo] Password for user ${USER}: " PURGATORY_PROTOCOL_PASSWORD
        printf '\n'
    fi
}

update_purge_aptitude()
{
    print_segment 'Aptitude' 'Updating'
    super_user_do apt-get update     --allow-releaseinfo-change
    super_user_do apt-get autoclean  --yes
    super_user_do apt-get autoremove --yes
    super_user_do apt-get upgrade    --yes \
        --allow-downgrades \
        --fix-broken \
        --install-suggests \
        --with-new-pkgs
    
    print_segment 'Aptitude' 'Purging'
    super_user_do apt-get autoclean  --yes
    super_user_do apt-get autoremove --yes
}

update_purge_cabal()
{
    print_segment 'Cabal' 'Updating'
    ghcup install cabal latest --set
    cabal update
    print_segment 'Cabal' 'Purging'
    remove_named_matching 'store caches' '${HOME}/.cabal/store' 'ghc-*'
    remove_named_matching 'local caches' '${HOME}'              'dist-newstyle'
}

update_purge_GHC()
{
    print_segment 'GHC' 'Updating'
    ghcup upgrade
    ghcup install ghc latest --set
    print_segment 'GHC' 'Purging'
    run_show_none ghcup gc --cache --ghc-old --hls-no-ghc
}

update_purge_stack()
{
    print_segment 'Stack' 'Updating'
    ghcup install stack latest --set
    stack update 
    print_segment 'Stack' 'Purging'
    remove_named_matching 'store caches' '${HOME}/.stack' 'snapshots'
    remove_named_matching 'local caches' '${HOME}'        '.stack-work\(s\)?'
}

# Check that the script is running as root. If not, then prompt for the sudo
# password and re-execute this script with sudo.
super_user_prompt

update_purge_aptitude

update_purge_GHC

update_purge_cabal

update_purge_stack

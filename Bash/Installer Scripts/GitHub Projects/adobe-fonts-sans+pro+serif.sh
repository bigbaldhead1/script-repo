#!/usr/bin/env bash

####################################################################################################################################################
##
##  GitHub Script: https://github.com/slyfox1186/script-repo/blob/main/Bash/Installer%20Scripts/SlyFox1186%20Scripts/install-adobe-sans+pro+serif-fonts.sh
##
##  Purpose: install adobe-sans + adobe-pro fonts system wide
##
##  Created: 10.10.23
##
##  Script version: 1.1
##
####################################################################################################################################################

clear

if [ "${EUID}" -eq '0' ]; then
    printf "%s\n\n" 'You must run this script WITHOUT root/sudo.'
    exit 1
fi

#
# SET THE VARIABLES
#

script_ver=1.1
pro_url=https://github.com/adobe-fonts/source-code-pro/archive/refs/tags/2.042R-u/1.062R-i/1.026R-vf.tar.gz
sans_url=https://github.com/adobe-fonts/source-sans/archive/refs/tags/3.052R.tar.gz
serif_url=https://github.com/adobe-fonts/source-serif/releases/download/4.004R/source-serif-4.004.zip
cwd="${PWD}"/adobe-fonts-installer
pro_dir="${cwd}"/pro-source
sans_dir="${cwd}"/sans-source
serif_dir="${cwd}"/serif-source
install_dir_pro=/usr/local/share/fonts/adobe-pro
install_dir_sans=/usr/local/share/fonts/adobe-sans
install_dir_serif=/usr/local/share/fonts/adobe-serif
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36'
web_repo=https://github.com/slyfox1186/script-repo

# sudo rm -fr /usr/local/share/fonts/adobe-pro /usr/local/share/fonts/adobe-sans /usr/local/share/fonts/adobe-serif

#
# PRINT SCRIPT BANNER
#

box_out_banner_header()
{
    input_char=$(echo "${@}" | wc -c)
    line=$(for i in $(seq 0 ${input_char}); do printf "-"; done)
    tput bold
    line="$(tput setaf 3)${line}"
    space=${line//-/ }
    echo " ${line}"
    printf '|' ; echo -n "${space}" ; printf "%s\n" '|';
    printf '| ' ;tput setaf 4; echo -n "${@}"; tput setaf 3 ; printf "%s\n" ' |';
    printf '|' ; echo -n "${space}" ; printf "%s\n" '|';
    echo " ${line}"
    tput sgr 0
}
box_out_banner_header "Installer Script - Adobe-Sans & Adobe-Pro Fonts - version ${script_ver}"

printf "\n%s\n\n" "The script will utilize (${cpu_threads}) CPU threads for parallel processing to accelerate the build speed."

#
# CREATE FUNCTIONS
#

exit_fn()
{
    printf "\n%s\n\n%s\n\n" \
        'Make sure to star this repository to show your support!' \
        "${web_repo}"
        sudo rm -fr "${cwd}" >2/dev/null
    exit 0
}

fail_fn()
{
    printf "\n%s\n\n%s\n\n" \
        "${1}" \
        "To report a bug create an issue at: ${web_repo}/issues"
    exit 1
}

#
# CREATE OR DELETE OLD OUTPUT DIRECTORIES FROM PREVIOUS RUNS
#

if [ -d "${pro_dir}" ] && [ -d "${sans_dir}" ] && [ -d "${serif_dir}" ]; then
    sudo rm -fr "${pro_dir}" "${sans_dir}" "${serif_dir}"
fi
mkdir -p "${pro_dir}" "${sans_dir}" "${serif_dir}"

sudo mkdir -p "${install_dir_pro}" "${install_dir_sans}" "${install_dir_serif}" 2>/dev/null

#
# DOWNLOAD THE ARCHIVE FILES
#

if [ ! -f "${pro_dir}".tar.gz ]; then
    if ! wget --show-progress -U "${user_agent}" -cqO "${pro_dir}".tar.gz "${pro_url}"; then
        fail_fn "Failed to download the archive file \"${pro_dir}.tar.gz\". Line: ${LINENO}"
    fi
fi

if [ ! -f "${sans_dir}".tar.gz ]; then
    if ! wget --show-progress -U "${user_agent}" -cqO "${sans_dir}".tar.gz "${sans_url}"; then
        fail_fn "Failed to download the archive file \"${sans_dir}.tar.gz\". Line: ${LINENO}"
    fi
fi
if [ ! -f "${serif_dir}".tar.gz ]; then
    if ! wget --show-progress -U "${user_agent}" -cqO "${serif_dir}".tar.gz "${sans_url}"; then
        fail_fn "Failed to download the archive file \"${serif_dir}.tar.gz\". Line: ${LINENO}"
    fi
fi
#
# EXTRACT THE ARCHIVE FILES
#

if ! tar -zxf "${pro_dir}".tar.gz -C "${pro_dir}" --strip-components 1; then
    fail_fn "Failed to extract the archive \"${pro_dir}.tar.gz\". Line: ${LINENO}"
fi
if ! tar -zxf "${sans_dir}".tar.gz -C "${sans_dir}" --strip-components 1; then
    fail_fn "Failed to extract the archive \"${sans_dir}.tar.gz\". Line: ${LINENO}"
fi
if ! tar -zxf "${serif_dir}".tar.gz -C "${serif_dir}" --strip-components 1; then
    fail_fn "Failed to extract the archive \"${serif_dir}.tar.gz\". Line: ${LINENO}"
fi

#
# FIND AND MOVE THE FONT FILES TO THE OUTPUT FOLDER
#

cd "${pro_dir}" || exit 1
sudo find . -type f -name '*.ttf' -exec sudo mv -f '{}' "${install_dir_pro}" \;
sudo find . -type f -name '*.otf' -exec sudo mv -f '{}' "${install_dir_pro}" \;
sudo find . -type f -name '*.woff' -exec sudo mv -f '{}' "${install_dir_pro}" \;
cd "${sans_dir}" || exit 1
sudo find . -type f -name '*.ttf' -exec sudo mv -f '{}' "${install_dir_sans}" \;
sudo find . -type f -name '*.otf' -exec sudo mv -f '{}' "${install_dir_sans}" \;
sudo find . -type f -name '*.woff' -exec sudo mv -f '{}' "${install_dir_sans}" \;
cd "${serif_dir}" || exit 1
sudo find . -type f -name '*.ttf' -exec sudo mv -f '{}' "${install_dir_serif}" \;
sudo find . -type f -name '*.otf' -exec sudo mv -f '{}' "${install_dir_serif}" \;
sudo find . -type f -name '*.woff' -exec sudo mv -f '{}' "${install_dir_serif}" \;

#
# MAKE SURE THERE THE FILES WERE MOVED SUCCESSFULLY AND THEN UPDATE THE FONT CACHE
#

if [ "$(sudo find "${install_dir_pro}" -type f -name '*.*' | wc -l)" -lt '64' ]; then
    fail_fn "The script failed to extract 64 total fonts to the adobe-pro directory. Line: ${LINENO}"
elif [ "$(sudo find "${install_dir_sans}" -type f -name '*.*' | wc -l)" -lt '64' ]; then
    fail_fn "The script failed to extract 64 total fonts to the adobe-pro directory. Line: ${LINENO}"
elif [ "$(sudo find "${install_dir_serif}" -type f -name '*.*' | wc -l)" -lt '64' ]; then
    fail_fn "The script failed to extract 64 total fonts to the adobe-pro directory. Line: ${LINENO}"
else
    sudo fc-cache -fv
fi

# CLEANUP THE LEFTOVER BUILD FILES
sudo rm -fr "${cwd}"

# SHOW THE EXIT MESSAGE
exit_fn

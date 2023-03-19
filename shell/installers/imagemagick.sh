#!/bin/bash

#################################################################
##
## GitHub: https://github.com/slyfox1186
##
## PURPOSE: BUILDS IMAGEMAGICK 7 FROM SOURCE CODE THAT IS
##          OBTAINED FROM THE OFFICIAL IMAGEMAGICK GITHUB PAGE.
##
## FUNCTION: IMAGEMAGICK IS THE LEADING OPEN SOURCE COMMAND LINE
##           IMAGE PROCESSOR. IT CAN BLUR, SHARPEN, WARP, REDUCE
##           FILE SIZE, ECT... IT IS FANTASTIC.
##
## LAST UPDATED: 03.18.23
##
#################################################################

clear

# verify the script does not have root access before continuing
if [ "${EUID}" -ne '0' ]; then
    echo 'You must run this script as root/sudo'
    echo
    exec sudo bash "${0}" "${@}"
fi

# FIND THE LATEST VERSION BY QUERYING GITHUB'S API
github_api_fn()
{
    # SCRAPE GITHUB WEBSITE FOR LATEST REPO VERSION
    net_timeout='5'
    github_repo="${1}"
    curl_cmd=$(curl -m "${net_timeout}" -Ls "https://api.github.com/repos/${github_repo}/releases?per_page=1")
    if [ "${?}" -eq '0' ]; then
        github_ver=$(echo "${curl_cmd}" | jq -r '.[].tag_name')
        github_ver=${github_ver#v}
    fi
}

# PASS THE GITHUB REPO NAME TO THE FUNCTION TO FIND IT'S CURRENT RELEASE
github_api_fn 'ImageMagick/ImageMagick' 2>/dev/null

# SET VARIABLES
sver='2.00'
imver="${github_ver}"
pver='1.2.59'

##
## CREATE FUNCTIONS
##

## EXIT SCRIPT
exit_fn()
{
    clear

    # SHOW THE NEWLY INSTALLED MAGICK VERSION
    if ! magick -version 2>/dev/null; then
        clear
        echo '$ error the script failed to execute the command "magick -version"'
        echo
        echo '$ Try running the command manually first and if needed create a support ticket by visiting:'
        echo '$ https://github.com/slyfox1186/script-repo/issues'
        echo
        exit 1
    fi

    echo
    echo 'The script has completed'
    echo
    echo 'Make sure to star this repository to show your support!'
    echo 'https://github.com/slyfox1186/script-repo'
    echo
    exit 0
}

## DELETE FILES FUNCTION
del_files_fn()
{
    if [[ "${1}" -eq '1' ]]; then
        rm -fr "${0}" "${2}" "${3}" "${4}" "${5}"
        exit_fn
    elif [[ "${1}" -eq '2' ]]; then
        exit_fn
    else
        echo 'Error: Bad user input'
        echo
        read -p 'Press enter to exit'
        exit_fn
    fi
}

## FUNCTION TO DETERMINE IF A PACKAGE IS INSTALLED OR NOT
installed() { return $(dpkg-query -W -f '${Status}\n' "${1}" 2>&1 | awk '/ok installed/{print 0;exit}{print 1}'); }

## FAILED DOWNLOAD/EXTRACTIONS FUNCTION
extract_fail_fn()
{
    clear
    echo 'Error: The tar command failed to extract any files'
    echo
    echo 'To create a support ticket visit: https://github.com/slyfox1186/script-repo/issues'
    echo
    exit 1
}

## REQUIRED IMAGEMAGICK DEVELOPEMENT PACKAGES
magick_packages_fn()
{

    pkgs=(autoconf automake build-essential google-perftools libc-devtools libcpu-features-dev libcrypto++-dev libdmalloc-dev libdmalloc5 libgc-dev libgc1 libgl2ps-dev libglib2.0-dev libgoogle-perftools-dev libgoogle-perftools4 libheif-dev libjemalloc-dev libjemalloc2 libjpeg-dev libmagickcore-6.q16hdri-dev libmimalloc-dev libmimalloc2.0 libopenjp2-7-dev libpng++-dev libpng-dev libpng-tools libpng16-16 libpstoedit-dev libraw-dev librust-bzip2-dev librust-jpeg-decoder+default-dev libtcmalloc-minimal4 libtiff-dev libtool libwebp-dev libzip-dev pstoedit)

    for pkg in ${pkgs[@]}
    do
        if ! installed "${pkg}"; then
            missing_pkgs+=" ${pkg}"
        fi
    done

    if [ -n "${missing_pkgs-}" ]; then
        for i in "${missing_pkgs}"
        do
            apt -y install ${i}
        done
        echo '$ the required packages were successfully installed'
    else
        echo '$ the required packages are already installed'
    fi
}

echo '$ building libpng12'
echo '================================'
echo
# SET LIBPNG12 VARIABLES
pngurl="https://sourceforge.net/projects/libpng/files/libpng12/${pver}/libpng-${pver}.tar.xz/download"
pngdir="libpng-${pver}"
pngtar="${pngdir}.tar.xz"

# DOWNLOAD LIBPNG12 SOURCE CODE
if [ ! -f "${pngtar}" ]; then
    wget --show-progress -cqO "${pngtar}" "${pngurl}"
fi

if ! tar -xf "${pngtar}"; then
    extract_fail_fn
fi

# CHANGE THE WORKING DIRECTORY TO LIBPNG'S SOURCE CODE PARENT FOLDER
cd "${pngdir}" || exit 1

# NEED TO RUN AUTOGEN SCRIPT FIRST SINCE THIS IS A WAY NEWER SYSTEM THAN THESE FILES ARE USED TO
echo
echo '$ executing ./autogen.sh'
./autogen.sh &> /dev/null
echo '$ executing ./configure'
./configure --prefix='/usr/local' &> /dev/null

# INSTALL LIBPNG12
echo '$ executing make install'
make install &> /dev/null

# CHANGE WORKING DIRECTORY BACK TO PARENT FOLDER
cd ../ || exit 1

#############################
## START IMAGEMAGICK BUILD ##
#############################

echo
echo '$ installing required packages'
echo '================================'
echo

# REQUIRED + EXTRA OPTIONAL PACKAGES FOR IMAGEMAGICK TO BUILD SUCCESSFULLY
magick_packages_fn

echo
echo '$ building imagemagick'
echo '================================'

# SET VARIABLES FOR IMAGEMAGICK
imurl="https://github.com/ImageMagick/ImageMagick/archive/refs/tags/${imver}.tar.gz"
imdir="ImageMagick-${imver}"
imtar="ImageMagick-${imver}.tar.gz"

# DOWNLOAD IMAGEMAGICK SOURCE CODE
if [ ! -f "${imtar}" ]; then
    echo
    wget --show-progress -cqO "${imtar}" "${imurl}"
    echo
fi

## UNCOMPRESS SOURCE CODE TO OUTPUT FOLDER
if ! tar -xf "${imtar}"; then
    extract_fail_fn
fi

# EXTRACT TAR AND CD INTO DIRECTORY
if [ ! -d "${imdir}" ]; then
    mkdir -p "${imdir}"
else
    tar -xf "${imtar}"
    cd "${imdir}" || exit 1
fi

# EXPORT THE PKG CONFIG PATHS TO ENABLE SUPPORT DURING THE BUILD
PKG_CONFIG_PATH="\
/usr/lib/x86_64-linux-gnu/pkgconfig:\
/usr/lib/pkgconfig:\
/usr/share/pkgconfig:\
"
export PKG_CONFIG_PATH

echo '$ executing ./configure'
./configure \
    --enable-ccmalloc \
    --enable-legacy-support \
    --with-autotrace \
    --with-dmalloc \
    --with-flif \
    --with-gslib \
    --with-heic \
    --with-jemalloc \
    --with-modules \
    --with-perl \
    --with-tcmalloc \
    --with-quantum-depth=16 &> /dev/null

# RUNNING MAKE COMMAND WITH PARALLEL PROCESSING
echo "\$ executing make -j$(nproc)"
make "-j$(nproc)" &> /dev/null

# INSTALLING FILES TO /usr/local/bin/
echo '$ executing make install'
make install &> /dev/null

# LDCONFIG MUST BE RUN NEXT IN ORDER TO UPDATE FILE CHANGES OR THE MAGICK COMMAND WILL NOT WORK
ldconfig /usr/local/lib 2>/dev/null

# CD BACK TO THE PARENT FOLDER
cd .. || exit 1

# PROMPT USER TO CLEAN UP BUILD FILES
echo
echo '$ do you want to remove the build files?'
echo
echo '$ [1] yes'
echo '$ [2] no'
echo
read -p '$ your choices are (1 or 2): ' cleanup
clear

del_files_fn "${cleanup}" "${pngdir}" "${imdir}" "${pngtar}" "${imtar}"

#!/bin/bash
# shellcheck disable=SC2016,SC2034,SC2046,SC2066,SC2068,SC2086,SC2162,SC2317

#####################################
##
## Install CMake v3.26.3
##
## Supported OS: Linux Debian based
##
## Updated: 4.30.23
##
## Script version: 2.0
##
#####################################

clear

if [ "$EUID" -eq '0' ]; then
    echo 'You must run this script WITHOUT root/sudo'
    echo
    exit 1
fi

##
## define global variables
##

s_ver='2.0'
build_dir='cmake-3.26.3'
target="$PWD/$build_dir"
tar_url='https://github.com/Kitware/CMake/releases/download/v3.26.3/cmake-3.26.3.tar.gz'

##
## define functions
##

fail_fn()
{
    printf "\n%s\n\n%s\n\n" \
        "$1" \
        'Please submit a support ticket in GitHub.'
    exit 1
}

exit_fn()
{
    clear
    printf "%s\n\n%s\n\n" \
        'Make sure to star this repository to show your support!' \
        'https://github.com/slyfox1186/script-repo/'
    exit 0
}

cleanup_fn()
{
    printf "\n%s\n\n%s\n%s\n\n" \
        'Do you want to cleanup the build files?' \
        '[1] Yes' \
        '[2] No'
        read -p 'Your choices are (1 or 2): ' cchoice
        case "$cchoice" in
            1)
                    cd "$target" || exit 1
                    cd ../ || exit 1
                    sudo rm -r "$build_dir"
                    exit_fn
                    ;;
            2)
                    exit_fn
                    ;;
            *)
                    read -p 'Bad user input. Press enter to try again'
                    clear
                    cleanup_fn
                    ;;
        esac         
}

success_fn()
{
    clear
    printf "\n%s\n\n" \
        "$1"
    cmake --version
    cleanup_fn
}

installed() { return $(dpkg-query -W -f '${Status}\n' "$1" 2>&1 | awk '/ok installed/{print 0;exit}{print 1}'); }

##
## create build folders
##

mkdir -p "$target"
cd "$target" || exit 1

##
## install required apt target
##

pkgs=(ccache make ninja-build openssl)

for pkg in ${pkgs[@]}
do
    if ! installed "$pkg"; then
        missing_pkgs+=" $pkg"
    fi
done

if [ -n "${missing_pkgs-}" ]; then
    for i in "$missing_pkgs"
    do
        sudo apt-get -qq -y install $i
    done
fi

##
## download the cmake tar file and extract the files into the src directory
##

printf "\n%s\n%s\n" \
    "CMake Build Script v$s_ver" \
    '============================='
sleep 2

if [ -d "$target" ]; then
    rm -fr "$target"
fi

mkdir -p "$target"

cd "$target" || exit 1

if ! curl -Lso "$target".tar.gz "$tar_url"; then
    fail_fn 'The tar file failed to download.'
fi

if ! tar -zxf "$target".tar.gz -C "$target" --strip-components 1; then
    fail_fn 'The tar command failed to extract any files.'
fi

##
## run the bootstrap file to generate any required install files
##

printf "\n%s\n\n%s\n\n" \
    'This might take a minute... please be patient' \
    "\$ ./bootstrap --prefix=/usr/local --parallel=$(nproc --all) --enable-ccache --generator=Ninja"
./bootstrap --prefix=/usr/local --parallel="$(nproc --all)" --enable-ccache --generator=Ninja &>/dev/null

##
## run the ninja commands to install cmake system-wide
##

if ninja &>/dev/null; then
    if ! sudo ninja install &>/dev/null; then
        fail_fn 'Ninja failed to install CMake.'
    else
        success_fn 'CMake has successfully been installed.'
    fi
else
    fail_fn 'Ninja failed to generate the install files.'
fi

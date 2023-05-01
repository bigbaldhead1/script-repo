#!/bin/bash
# shellcheck disable=SC2016,SC2034,SC2046,SC2066,SC2068,SC2086,SC2162,SC2317

#################################################################################
##
##  GitHub: https://github.com/slyfox1186/ffmpeg-build-script/
##
##  Supported Distros: Ubuntu
##
##  Supported architecture: x86_64
##
##  Purpose: Build FFmpeg from source code with addon development
##           libraries also compiled from source code to ensure the
##           latest in extra functionality
##
##  Cuda:    If the cuda libraries are not installed (for geforce cards only)
##           the user will be prompted by the script to install them so that
##           hardware acceleration is enabled when compiling FFmpeg
##
##  Updated: 04.29.23
##
##  Version: 5.0
##
#################################################################################

##
## define variables
##

# FFmpeg version: Whatever the latest Git pull from: https://git.ffmpeg.org/gitweb/ffmpeg.git
progname="${0:2}"
script_ver='5.0'
cuda_ver='12.1.1'
packages="$PWD"/packages
workspace="$PWD"/workspace
install_dir='/usr/bin'
CFLAGS="-I$workspace/include -I/usr/include -I/usr/local/include"
LDFLAGS="-L$workspace"/lib
LDEXEFLAGS=''
EXTRALIBS='-ldl -lpthread -lm -lz'
cnf_ops=()
nonfree_and_gpl='false'
latest='false'
export CC='gcc-12' CXX='g++-12'

# create the output directories
mkdir -p "$packages"
mkdir -p "$workspace"

##
## set the available cpu thread and core count for parallel processing (speeds up the build process)
##

if [ -f '/proc/cpuinfo' ]; then
    cpu_threads="$(grep -c ^processor '/proc/cpuinfo')"
else
    cpu_threads="$(nproc --all)"
fi
cpu_cores="$(grep ^cpu\\scores '/proc/cpuinfo' | uniq | awk '{print $4}')"

##
## define functions
##

exit_fn()
{
    printf "\n%s\n\n%s\n\n" \
    'Make sure to star this repository to show your support!' \
    'https://github.com/slyfox1186/script-repo/'
    exit 0
}

fail_fn()
{
    echo
    echo 'Please create a support ticket'
    echo
    echo 'https://github.com/slyfox1186/script-repo/issues'
    echo
    exit 1
}

fail_pkg_fn()
{
    echo
    echo "The '$1' package is not installed. It is required for this script to run."
    echo
    exit 1
}

cleanup_fn()
{
    echo '=========================================='
    echo ' Do you want to clean up the build files? '
    echo '=========================================='
    echo
    echo '[1] Yes'
    echo '[2] No'
    echo
    read -p 'Your choices are (1 or 2): ' cleanup_ans

    if [[ "${cleanup_ans}" -eq '1' ]]; then
        sudo rm -fr  "$packages" "$workspace" "$0"
        echo 'Cleanup finished.'
        exit_fn
    elif [[ "${cleanup_ans}" -eq '2' ]]; then
        exit_fn
    else
        echo 'Bad user input'
        echo
        read -p 'Press enter to try again.'
        echo
        cleanup_fn
    fi
}

ff_ver_fn()
{
    echo
    echo '============================'
    echo '       FFmpeg Version       '
    echo '============================'
    echo
    ffmpeg -version
    echo
    cleanup_fn
}

make_dir()
{
    remove_dir "$*"
    if ! mkdir "$*"; then
        printf "\n Failed to create dir %s" "$*"
        echo
        exit 1
    fi
}

remove_file()
{
    if [ -f "$*" ]; then
        sudo rm -f "$*"
    fi
}

remove_dir()
{
    if [ -d "$*" ]; then
        sudo rm -fr "$*"
    fi
}

download()
{
    dl_path="$packages"
    dl_url="$1"
    dl_file="${2:-"${1##*/}"}"

    if [[ "$dl_file" =~ tar. ]]; then
        target_dir="${dl_file%.*}"
        target_dir="${3:-"${target_dir%.*}"}"
    else
        target_dir="${3:-"${dl_file%.*}"}"
    fi

    if [ -d "$dl_path/$target_dir" ]; then
        remove_dir "$dl_path/$target_dir"
    fi

    if [ ! -f "$dl_path/$dl_file" ]; then
        echo "Downloading $dl_url as $dl_file"
        url_down_test="$dl_url"
        is_down="$(curl -LIs "$url_down_test")"
        if [ -z "$is_down" ]; then
            echo 'The download link was unresponsive.'
            echo
            echo 'Sleeping for 10 seconds before attempting to download.'
            sleep 10
            echo
        fi
        if ! curl -Lso "$dl_path/$dl_file" "$dl_url"; then
            echo
            echo "The script failed to download \"$dl_url\" and will try again in 10 seconds"
            sleep 10
            echo
            if ! curl -Lso "$dl_path/$dl_file" "$dl_url"; then
                echo
                echo "The script failed to download \"$dl_url\" two times and will exit the build"
                echo
                fail_fn
            fi
        fi
        echo 'Download Completed'
    else
        echo "$dl_file is already downloaded"
    fi

    make_dir "$dl_path/$target_dir"

    if [ -n "$3" ]; then
        if ! tar -xf "$dl_path/$dl_file" -C "$dl_path/$target_dir" 2>/dev/null >/dev/null; then
            fail_fn "Failed to extract $dl_file"
        fi
    else
        if ! tar -xf "$dl_path/$dl_file" -C "$dl_path/$target_dir" --strip-components 1 2>/dev/null >/dev/null; then
            fail_fn "Failed to extract $dl_file"
        fi
    fi

    echo "File extracted: $dl_file"
    echo

    cd "$dl_path/$target_dir" || fail_fn "Unable to change the working directory to $target_dir"
}

download_git()
{
    dl_path="$packages"
    dl_url="$1"
    dl_file="$2"
    dl_args="$3"
    target_dir="$dl_path/$dl_file"

    if [ -d "$target_dir" ]; then
        remove_dir "$target_dir"
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Downloading $dl_file"
        url_down_test="$dl_url"
        is_down="$(curl -LIs "$url_down_test")"
        if [ -z "$is_down" ]; then
            echo 'The git server was unresponsive.'
            echo
            echo 'Sleeping for 10 seconds before attempting to clone.'
            sleep 10
            echo
        fi
        if ! git clone -q "$dl_url" "$target_dir"; then
            echo
            echo "The script failed to clone the git repository: $dl_file"
            echo
            echo 'Sleeping for 10 seconds before trying one more time.'
            sleep 10
            echo
            if ! git clone -q "$dl_url" "$target_dir"; then
                fail_fn "The script failed to download \"$dl_file\" two times and will exit the build"
            fi
        fi
        echo 'Download Completed'
    fi

    echo "File extracted: $dl_file"
    echo

    cd "$target_dir" || fail_fn "Unable to change the working directory to $target_dir"
}

# create txt files to check versions
ver_file_tmp="$workspace/latest-versions-tmp.txt"
ver_file="$workspace/latest-versions.txt"
if [ ! -f "$ver_file_tmp" ] || [ ! -f "$ver_file" ]; then
    touch "$ver_file_tmp" "$ver_file" 2>/dev/null
fi

# PULL THE LATEST VERSIONS OF EACH PACKAGE FROM THE WEBSITE API
curl_timeout='5'

git_token='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'

git_1_fn()
{
    local github_repo github_url

    # SCRAPE GITHUB WEBSITE FOR LATEST REPO VERSION
    github_repo="$1"
    github_url="$2"

    if [ "$github_url" = 'releases/latest' ]; then

        if curl_cmd="$(curl -m "$curl_timeout" sSL https://api.github.com/repos/$github_repo/$github_url)"; then
            g_url="$(echo "$curl_cmd" | jq -r '.tarball_url' | sort | head -n1)"
            g_ver="${g_url##*/}"
            g_ver="${g_ver##v}"
            g_ver="${g_ver#OpenJPEG }"
            g_ver="${g_ver#OpenSSL }"
            g_ver="${g_ver#lcms}"
        fi
    fi

    if [ "$github_url" = 'tags' ]; then
        if curl_cmd="$(curl -m "$curl_timeout" sSL https://api.github.com/repos/$github_repo/$github_url)"; then
            g_ver="$(echo "$curl_cmd" | jq -r '.[0].name' | sort | head -n1)"
            g_ver="${g_ver#v}"
            g_ver="${g_ver#OpenJPEG }"
            g_ver="${g_ver#OpenSSL }"
            g_ver="${g_ver#pkgconf-}"
            g_ver="${g_ver#lcms}"
            g_url="$(echo "$curl_cmd" | jq -r '.[0].tarball_url')"
        fi
    fi

    echo "${github_repo##*/}-$g_ver" >> "$ver_file_tmp"
    awk '!NF || !seen[$0]++' "$latest_txt_tmp" > "$ver_file"
}

git_2_fn()
{
    videolan_repo="$1"
    videolan_url="$2"
    if curl_cmd="$(curl -m "$curl_timeout" -sSL "https://code.videolan.org/api/v4/projects/$videolan_repo/repository/$videolan_url")"; then
        g_ver="$(echo "$curl_cmd" | jq -r '.[0].commit.id')"
        g_sver="$(echo "$curl_cmd" | jq -r '.[0].commit.short_id')"
        g_ver1="$(echo "$curl_cmd" | jq -r '.[0].name')"
        g_ver1="${g_ver1#v}"
    fi
}

git_3_fn()
{
    gitlab_repo="$1"
    gitlab_url="$2"
    if curl_cmd="$(curl -m "$curl_timeout" -sSL "https://gitlab.com/api/v4/projects/$gitlab_repo/repository/$gitlab_url")"; then
        g_ver="$(echo "$curl_cmd" | jq -r '.[0].name')"
        g_ver="${g_ver#v}"

        g_ver1="$(echo "$curl_cmd" | jq -r '.[0].commit.id')"
        g_ver1="${g_ver1#v}"
        g_sver1="$(echo "$curl_cmd" | jq -r '.[0].commit.short_id')"
    fi
}

git_4_fn()
{
    gitlab_repo="$1"
    if curl_cmd="$(curl -m "$curl_timeout" -sSL "https://gitlab.freedesktop.org/api/v4/projects/$gitlab_repo/repository/tags")"; then
        g_ver="$(echo "$curl_cmd" | jq -r '.[0].name')"
    fi
}

git_5_fn()
{
    gitlab_repo="$1"
    if curl_cmd="$(curl -m "$curl_timeout" -sSL 'https://bitbucket.org/!api/2.0/repositories/multicoreware/x265_git/effective-branching-model')"; then
        g_ver="$(echo "$curl_cmd" | jq '.development.branch.target' | grep -Eo '[0-9a-z][0-9a-z]+' | sort | head -n 1)"
        g_sver="${g_ver::7}"
    fi
}

git_6_fn()
{
    gitlab_repo="$1"
    if curl_cmd="$(curl -m "$curl_timeout" -sSL "https://gitlab.gnome.org/api/v4/projects/$gitlab_repo/repository/tags")"; then
        g_ver="$(echo "$curl_cmd" | jq -r '.[0].name')"
        g_ver="${g_ver#v}"
    fi
}

git_7_fn()
{
    gitlab_repo="$1"
    if curl_cmd="$(curl -m "$curl_timeout" -sSL "https://git.archive.org/api/v4/projects/$gitlab_repo/repository/tags")"; then
        g_ver="$(echo "$curl_cmd" | jq -r '.[0].name')"
        g_ver="${g_ver#v}"
    fi
}

git_ver_fn()
{
    local v_flag v_tag url_tag

    v_url="$1"
    v_tag="$2"

    if [ -n "$3" ]; then
        v_flag="$3"
    fi

    if [ "$v_flag" = 'B' ] && [  "$v_tag" = '2' ]; then
        url_tag='git_2_fn' gv_url='branches'
    elif [ "$v_flag" = 'B' ] && [  "$v_tag" = '3' ]; then
        url_tag='git_3_fn' gv_url='branches'
    fi

    if [ "$v_flag" = 'X' ] && [  "$v_tag" = '5' ]; then
        url_tag='git_5_fn'
    fi

    if [ "$v_flag" = 'T' ] && [  "$v_tag" = '1' ]; then
        url_tag='git_1_fn' gv_url='tags'
    elif [ "$v_flag" = 'T' ] && [  "$v_tag" = '2' ]; then
        url_tag='git_2_fn' gv_url='tags'
    elif [ "$v_flag" = 'T' ] && [  "$v_tag" = '3' ]; then
        url_tag='git_3_fn' gv_url='tags'
    fi

    if [ "$v_flag" = 'R' ] && [  "$v_tag" = '1' ]; then
        url_tag='git_1_fn'; gv_url='releases'
    elif [ "$v_flag" = 'R' ] && [  "$v_tag" = '2' ]; then
        url_tag='git_2_fn'; gv_url='releases'
    elif [ "$v_flag" = 'R' ] && [  "$v_tag" = '3' ]; then
        url_tag='git_3_fn' gv_url='releases'
    fi

    if [ "$v_flag" = 'L' ] && [  "$v_tag" = '1' ]; then
        url_tag='git_1_fn'; gv_url='releases/latest'
    fi

    case "$v_tag" in
        2)          url_tag='git_2_fn';;
        3)          url_tag='git_3_fn';;
        4)          url_tag='git_4_fn';;
        5)          url_tag='git_5_fn';;
        6)          url_tag='git_6_fn';;
        7)          url_tag='git_7_fn';;
    esac

    "$url_tag" "$v_url" "$gv_url" 2>/dev/null
}

check_version()
{
    github_repo="$1"
    latest_txt_tmp="$ver_file_tmp"
    latest_txt="$ver_file"

    awk '!NF || !seen[$0]++' "$latest_txt_tmp" > "$latest_txt"
    check_ver="$(grep -Eo "${github_repo##*/}-[0-9\.]+" "$latest_txt" | sort | head -n1)"

        if [ -n "$check_ver" ]; then
            g_nocheck='0'
        else
            g_nocheck='1'
        fi
}

pre_check_ver()
{
    github_repo="$1"
    git_ver="$2"
    git_url_type="$3"

    check_version "$github_repo"
    if [ "$g_nocheck" -eq '1' ]; then
        git_ver_fn "$github_repo" "$git_ver" "$git_url_type"
        g_ver="${g_ver##*-}"
        g_ver3="${g_ver3##*-}"
    else
        g_ver="${check_ver##*-}"
    fi
}

execute()
{
    echo "$ $*"

    if ! output=$("$@" 2>&1); then
        fail_fn "Failed to Execute $*"
    fi
}

build()
{
    echo
    echo "building $1 - version $2"
    echo '===================================='

    if [ -f "$packages/$1.done" ]; then
    if grep -Fx "$2" "$packages/$1.done" >/dev/null; then
            echo "$1 version $2 already built. Remove $packages/$1.done lockfile to rebuild it."
            return 1
        elif $latest; then
            echo "$1 is outdated and will be rebuilt using version $2"
            return 0
        else
            echo "$1 is outdated, but will not be rebuilt. Pass in --latest to rebuild it or remove $packages/$1.done lockfile."
            return 1
        fi
    fi

    return 0
}

command_exists()
{
    if ! [[ -x $(command -v "$1") ]]; then
        return 1
    fi

    return 0
}

library_exists()
{

    if ! [[ -x "$(pkg-config --exists --print-errors "$1" 2>&1 >/dev/null)" ]]; then
        return 1
    fi

    return 0
}

build_done() { echo "$2" > "$packages/$1.done"; }

installed() { return $(dpkg-query -W -f '${Status}\n' "$1" 2>&1 | awk '/ok installed/{print 0;exit}{print 1}'); }

cuda_fail_fn()
{
    echo '======================================================'
    echo '                    Script error:'
    echo '======================================================'
    echo
    echo "Unable to locate directory: /usr/local/cuda-12.1/bin/"
    echo
    read -p 'Press enter to exit.'
    clear
    fail_fn
}

gpu_arch_fn()
{
    is_wsl="$(uname -a | grep -Eo 'WSL2')"

    if [ -n "$is_wsl" ]; then
        sudo apt -y install nvidia-utils-525 &>/dev/null
    fi

    gpu_name="$(nvidia-smi --query-gpu=gpu_name --format=csv | sort -r | head -n 1)"

    if [ "$gpu_name" = 'name' ]; then
        gpu_name="$(nvidia-smi --query-gpu=gpu_name --format=csv | sort | head -n 1)"
    fi

    case "$gpu_name" in
        'NVIDIA GeForce GT 1010')         gpu_type='1';;
        'NVIDIA GeForce GTX 1030')        gpu_type='1';;
        'NVIDIA GeForce GTX 1050')        gpu_type='1';;
        'NVIDIA GeForce GTX 1060')        gpu_type='1';;
        'NVIDIA GeForce GTX 1070')        gpu_type='1';;
        'NVIDIA GeForce GTX 1080')        gpu_type='1';;
        'NVIDIA TITAN Xp')                gpu_type='1';;
        'NVIDIA Tesla P40')               gpu_type='1';;
        'NVIDIA Tesla P4')                gpu_type='1';;
        'NVIDIA GeForce GTX 1180')        gpu_type='2';;
        'NVIDIA GeForce GTX Titan V')     gpu_type='2';;
        'NVIDIA Quadro GV100')            gpu_type='2';;
        'NVIDIA Tesla V100')              gpu_type='2';;
        'NVIDIA GeForce GTX 1660 Ti')     gpu_type='3';;
        'NVIDIA GeForce RTX 2060')        gpu_type='3';;
        'NVIDIA GeForce RTX 2070')        gpu_type='3';;
        'NVIDIA GeForce RTX 2080')        gpu_type='3';;
        'NVIDIA Quadro RTX 4000')         gpu_type='3';;
        'NVIDIA Quadro RTX 5000')         gpu_type='3';;
        'NVIDIA Quadro RTX 6000')         gpu_type='3';;
        'NVIDIA Quadro RTX 8000')         gpu_type='3';;
        'NVIDIA T1000')                   gpu_type='3';;
        'NVIDIA T2000')                   gpu_type='3';;
        'NVIDIA Tesla T4')                gpu_type='3';;
        'NVIDIA GeForce RTX 3050')        gpu_type='4';;
        'NVIDIA GeForce RTX 3060')        gpu_type='4';;
        'NVIDIA GeForce RTX 3070')        gpu_type='4';;
        'NVIDIA GeForce RTX 3080')        gpu_type='4';;
        'NVIDIA GeForce RTX 3080 Ti')     gpu_type='4';;
        'NVIDIA GeForce RTX 3090')        gpu_type='4';;
        'NVIDIA RTX A2000')               gpu_type='4';;
        'NVIDIA RTX A3000')               gpu_type='4';;
        'NVIDIA RTX A4000')               gpu_type='4';;
        'NVIDIA RTX A5000')               gpu_type='4';;
        'NVIDIA RTX A6000')               gpu_type='4';;
        'NVIDIA GeForce RTX 4080')        gpu_type='5';;
        'NVIDIA GeForce RTX 4090')        gpu_type='5';;
        'NVIDIA H100')                    gpu_type='6';;
    esac

    if [ -n "$gpu_type" ]; then
        case "$gpu_type" in
            1)        gpu_arch='compute_61,code=sm_61';;
            2)        gpu_arch='compute_70,code=sm_70';;
            3)        gpu_arch='compute_75,code=sm_75';;
            4)        gpu_arch='compute_86,code=sm_86';;
            5)        gpu_arch='compute_89,code=sm_89';;
            6)        gpu_arch='compute_90,code=sm_90';;
        esac
    fi
}

# PRINT THE OPTIONS AVAILABLE WHEN MANUALLY RUNNING THE SCRIPT
usage()
{
    echo "Usage: $progname [OPTIONS]"
    echo
    echo 'Options:'
    echo '    -h, --help                                       Display usage information'
    echo '            --version                                Display version information'
    echo '    -b, --build                                      Starts the build process'
    echo '            --enable-gpl-and-non-free                Enable GPL and non-free codecs - https://ffmpeg.org/legal.html'
    echo '    -c, --cleanup                                    Remove all working dirs'
    echo '            --latest                                 Build latest version of dependencies if newer available'
    echo
}

echo "ffmpeg-build-script v$script_ver"
echo '======================================'
echo

while (($# > 0)); do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    --version)
        echo "$script_ver"
        exit 0
        ;;
    -*)
        if [[ "$1" == '--build' || "$1" =~ '-b' ]]; then
            bflag='-b'
        fi
        if [[ "$1" == '--enable-gpl-and-non-free' ]]; then
            cnf_ops+=('--enable-nonfree')
            cnf_ops+=('--enable-gpl')
            nonfree_and_gpl='true'
        fi
        if [[ "$1" == '--cleanup' || "$1" =~ '-c' && ! "$1" =~ '--' ]]; then
            cflag='-c'
            cleanup_fn
        fi
        if [[ "$1" == '--full-static' ]]; then
            LDEXEFLAGS='-static'
        fi
        if [[ "$1" == '--latest' ]]; then
            latest='true'
        fi
        shift
        ;;
    *)
        usage
        echo
        fail_fn
        ;;
    esac
done

if [ -z "$bflag" ]; then
    if [ -z "$cflag" ]; then
        usage
    fi
    exit 0
fi

echo "The script will utilize $cpu_threads CPU cores for parallel processing to accelerate the build speed."
echo

if "$nonfree_and_gpl"; then
    echo 'The script has been configured to run with GPL and non-free codecs enabled'
fi

if [ -n "$LDEXEFLAGS" ]; then
    echo 'The script has been configured to run in full static mode.'
fi

# set global variables
export JAVA_HOME='/usr/lib/jvm/java-17-openjdk-amd64'

# libbluray requries that this variable be set
PATH="\
/usr/lib/ccache:\
$JAVA_HOME/bin:\
$PATH\
"
export PATH

# set the pkg-config path
PKG_CONFIG_PATH="\
$workspace/lib/pkgconfig:\
$workspace/lib/x86_64-linux-gnu/pkgconfig:\
/usr/local/lib/x86_64-linux-gnu/pkgconfig:\
/usr/local/lib/pkgconfig:\
/usr/local/share/pkgconfig:\
/usr/lib/x86_64-linux-gnu/pkgconfig:\
/usr/lib/pkgconfig:\
/usr/share/pkgconfig:\
/usr/lib64/pkgconfig\
"
export PKG_CONFIG_PATH

if ! command_exists 'make'; then
    fail_pkg_fn 'make'
fi

if ! command_exists 'g++'; then
    fail_pkg_fn 'g++'
fi

if ! command_exists 'curl'; then
    fail_pkg_fn 'curl'
fi

if ! command_exists 'jq'; then
    fail_pkg_fn 'jq'
fi

if ! command_exists 'cargo'; then
    echo 'The '\''cargo'\'' command was not found.'
    echo
    echo 'The rav1e encoder will not be available.'
fi

if ! command_exists 'python3'; then
    echo 'The '\''python3'\'' command was not found.'
    echo
    echo 'The '\''lv2'\'' filter and '\''dav1d'\'' decoder will not be available.'
fi

cuda_fn()
{
    clear

    local c_dist iscuda cuda_path

    printf "%s\n\n%s\n\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n" \
        'Pick your Linux distro from the list below:' \
        'Supported architecture: x86_64' \
        '[1] Debian 10' \
        '[2] Debian 11' \
        '[3] Ubuntu 18.04' \
        '[4] Ubuntu 20.04' \
        '[5] Ubuntu 22.04' \
        '[6] Ubuntu Windows (WSL)' \
        '[7] Skip this'

    read -p 'Your choices are (1 to 7): ' c_dist
    clear

    case "$c_dist" in
        1)
            wget --show progress -4cqO 'cuda-12.1.1.deb' 'https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda-repo-debian10-12-1-local_12.1.1-530.30.02-1_amd64.deb'
            sudo dpkg -i 'cuda-12.1.1.deb'
            sudo cp /var/cuda-repo-debian10-12-1-local/cuda-*-keyring.gpg '/usr/share/keyrings/'
            sudo add-apt-repository contrib
            ;;
        2)
            wget --show progress -4cqO 'cuda-12.1.1.deb' 'https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda-repo-debian11-12-1-local_12.1.1-530.30.02-1_amd64.deb'
            sudo dpkg -i 'cuda-12.1.1.deb'
            sudo cp /var/cuda-repo-debian11-12-1-local/cuda-*-keyring.gpg '/usr/share/keyrings/'
            sudo add-apt-repository contrib
            ;;
        3)
            wget --show progress -4cq 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin'
            sudo mv 'cuda-ubuntu1804.pin' '/etc/apt/preferences.d/cuda-repository-pin-600'
            wget --show progress -4cqO 'cuda-12.1.1.deb' 'https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda-repo-ubuntu1804-12-1-local_12.1.1-530.30.02-1_amd64.deb'
            sudo dpkg -i 'cuda-12.1.1.deb'
            sudo cp /var/cuda-repo-ubuntu1804-12-1-local/cuda-*-keyring.gpg '/usr/share/keyrings/'
            ;;
        4)
            wget --show progress -4cq 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin'
            sudo mv 'cuda-ubuntu2004.pin' '/etc/apt/preferences.d/cuda-repository-pin-600'
            wget --show progress -4cqO 'cuda-12.1.1.deb' 'https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda-repo-ubuntu2004-12-1-local_12.1.1-530.30.02-1_amd64.deb'
            sudo dpkg -i 'cuda-12.1.1.deb'
            sudo cp /var/cuda-repo-ubuntu2004-12-1-local/cuda-*-keyring.gpg '/usr/share/keyrings/'
            ;;
        5)
            wget --show progress -4cq 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin'
            sudo mv 'cuda-ubuntu2204.pin' '/etc/apt/preferences.d/cuda-repository-pin-600'
            wget --show progress -4cqO 'cuda-12.1.1.deb' 'https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda-repo-ubuntu2204-12-1-local_12.1.1-530.30.02-1_amd64.deb'
            sudo dpkg -i 'cuda-12.1.1.deb'
            sudo cp /var/cuda-repo-ubuntu2204-12-1-local/cuda-*-keyring.gpg '/usr/share/keyrings/'
            ;;
        6)
            wget --show progress -4cq 'https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin'
            sudo mv 'cuda-wsl-ubuntu.pin' '/etc/apt/preferences.d/cuda-repository-pin-600'
            wget --show progress -4cqO 'cuda-12.1.1.deb' 'https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda-repo-wsl-ubuntu-12-1-local_12.1.1-1_amd64.deb'
            sudo dpkg -i 'cuda-12.1.1.deb'
            sudo cp /var/cuda-repo-wsl-ubuntu-12-1-local/cuda-*-keyring.gpg '/usr/share/keyrings/'
            ;;
        7)
            exit_fn
            ;;
        *)
            fail_fn 'Bad User Input. Run the script again.'
            ;;
    esac

    # UPDATE THE APT PACKAGES THEN INSTALL THE CUDA-SDK-TOOLKIT
    sudo apt update
    sudo apt -y install cuda

    # CHECK IF THE CUDA FOLDER EXISTS TO ENSURE IT WAS INSTALLED
    iscuda="$(sudo find /usr/local/ -type f -name nvcc)"
    cuda_path="$(sudo find /usr/local/ -type f -name nvcc | grep -Eo '^.*\/bi[n]?')"

    if [ -z "$cuda_path" ]; then
        cuda_fail_fn
    else
        export PATH="$cuda_path:$PATH"
    fi
}

##
## required build packages
##

build_pkgs_fn()
{
    echo
    echo 'Installing required development packages'
    echo '=========================================='

    pkgs=(ant autoconf autogen automake binutils bison build-essential cargo ccache ccdiff checkinstall clang \
          clang-tools cmake cmake-curses-gui cmake-extras cmake-qt-gui curl dbus dbus-x11 dos2unix doxygen flex \
          flexc++ freeglut3-dev g++ g++-11 g++-12 gawk gcc gcc-11 gcc-12 gh git-all gnustep-gui-runtime \
          golang gperf gtk-doc-tools help2man javacc jfsutils jq junit liblcms2-dev libavif-dev libbz2-dev libcairo2-dev \
          libcdio-paranoia-dev libcurl4-gnutls-dev libdmalloc-dev libglib2.0-dev libgvc6 libheif-dev libjemalloc-dev liblz-dev \
          liblzma-dev liblzo2-dev libmathic-dev libmimalloc-dev libmusicbrainz5-dev libncurses5-dev libnet-nslookup-perl \
          libnuma-dev libopencv-dev libperl-dev libpstoedit-dev libraqm-dev libraw-dev librsvg2-dev librust-jemalloc-sys-dev \
          librust-malloc-buf-dev libsox-dev libsoxr-dev libssl-dev libtalloc-dev libtbbmalloc2 libtinyxml2-dev \
          libtool libtool-bin libwebp-dev libyuv-dev libzstd-dev libzzip-dev lsb-core lshw lvm2 lzma-dev make man-db mercurial \
          meson nano nasm ninja-build openjdk-17-jdk pkg-config python3 python3-pip ragel scons sox texi2html texinfo xmlto yasm \
          codespell serdi sordi libsamplerate0-dev libsndfile1-dev libgtk2.0-dev)

    for pkg in ${pkgs[@]}
    do
        if ! installed "$pkg"; then
            missing_vers+=" $pkg"
        fi
    done

    if [ -n "$missing_vers" ]; then
        for pkg in "$missing_vers"
        do
            if sudo apt -y install $pkg; then
                echo 'The required development packages were installed.'
            else
                echo 'The required development packages failed to install'
                echo
                exit 1
            fi
        done
    else
        echo 'The required development packages are already installed.'
    fi
}

##
## ADDITIONAL REQUIRED GEFORCE CUDA DEVELOPMENT PACKAGES
##

cuda_add_fn()
{
    echo
    echo 'Installing required cuda developement packages'
    echo '================================================'

    pkgs=(autoconf automake build-essential libc6 \
          libc6-dev libnuma1 libnuma-dev texinfo unzip wget)

    for pkg in ${pkgs[@]}
    do
        if ! installed "$pkg"; then
            missing_vers+=" $pkg"
        fi
    done

    if [ -n "$missing_vers" ]; then
        for pkg in "$missing_vers"
        do
            sudo apt -y install $pkg
        done
        echo 'The required cuda developement packages were installed'
    else
        echo 'The required cuda developement packages are already installed'
    fi
}

install_cuda_fn()
{
    local cuda_ans cuda_choice

    iscuda="$(sudo find /usr/local/ -type f -name nvcc)"
    cuda_path="$(sudo find /usr/local/ -type f -name nvcc | grep -Eo '^.*\/bi[n]?')"

    if [ -z "$iscuda" ]; then
        echo
        echo 'The cuda-sdk-toolkit isn'\''t installed or it is not in $PATH'
        echo '==============================================================='
        echo
        echo 'What do you want to do next?'
        echo
        echo '[1] Install the toolkit and add it to $PATH'
        echo '[2] Only add it to $PATH'
        echo '[3] Continue the build'
        echo
        read -p 'Your choices are (1 to 3): ' cuda_ans
        echo
        if [[ "$cuda_ans" -eq '1' ]]; then
            cuda_fn
            cuda_add_fn
        elif [[ "$cuda_ans" -eq '2' ]]; then
            if [ -d "$cuda_path" ]; then
                PATH="$PATH:$cuda_path"
                export PATH
            else
                echo 'The script was unable to add cuda to your $PATH because the required folder was not found: /usr/local/cuda-12.1/bin'
                echo
                read -p 'Press enter to exit'
                echo
                exit 1
            fi
        elif [[ "$cuda_ans" -eq '3' ]]; then
            echo
        else
            echo
            echo 'Error: Bad user input!'
            echo '======================='
            fail_fn
        fi
    else
        echo
        echo "The cuda-sdk-toolkit v12.1 is already installed."
        echo '================================================='
        echo
        echo 'Do you want to update/reinstall it?'
        echo
        echo '[1] Yes'
        echo '[2] No'
        echo
        read -p 'Your choices are (1 or 2): ' cuda_choice
        echo
        if [[ "$cuda_choice" -eq '1' ]]; then
            cuda_fn
            cuda_add_fn
        elif [[ "$cuda_choice" -eq '2' ]]; then
            PATH="$PATH:$cuda_path"
            export PATH
            echo 'Continuing the build...'
        else
            echo
            echo 'Bad user input.'
            echo
            read -p 'Press enter to try again.'
            clear
            install_cuda_fn
        fi
    fi
}

ffmpeg_install_choice()
{
    printf "%s\n\n%s\n%s\n\n" \
        'Would you like to install the FFmpeg binaries system-wide? [/usr/bin]' \
        '[1] Yes ' \
        '[2] No'
    read -p 'Your choices are (1 or 2): ' install_choice

    case "$install_choice" in
            1)
                sudo cp -f "$workspace/bin/ffmpeg" "$install_dir/ffmpeg"
                sudo cp -f "$workspace/bin/ffprobe" "$install_dir/ffprobe"
                sudo cp -f "$workspace/bin/ffplay" "$install_dir/ffplay"
                ;;
            2)
                printf "\n%s\n\n%s\n" \
                    'The FFmpeg binaries are located:' \
                    "$workspace/bin"
                ;;
            *)
                echo 'Bad user input. Press enter to try again.'
                clear
                ffmpeg_install_choice
                ;;
    esac
}

ffmpeg_install_check()
{
    ff_binaries=(ffmpeg ffprobe ffplay)

    for i in ${ff_binaries[@]}
    do
        if [ ! -f "/usr/bin/$i" ]; then
            echo "Failed to copy: /usr/bin/$i"
        fi
    done
}

##
## install cuda
##

echo
install_cuda_fn

##
## build tools
##

# install required apt packages
build_pkgs_fn

##
## install cmake latest version (some poackages get bent out of shape with the one source by APT)
##

if [ ! -f '/usr/local/bin/cmake' ]; then
    curl -Lso cmake-ffmpeg.sh https://raw.githubusercontent.com/slyfox1186/script-repo/main/shell/ffmpeg/cmake-3.26.3-ffmpeg.sh; bash cmake-ffmpeg.sh
    execute rm cmake-ffmpeg.sh
    echo
fi

##
## add ccache to PATH to speed up rebuilds
##

export PATH="/usr/lib/ccache:$PATH"

##
## being source code building
##

git_test()
{
    git_url="$1"
    git_dir="$2"
    git_url+=" $3"
    eval "git clone '$git_url' $git_dir/"
}

# begin source code building
if build 'giflib' '5.2.1'; then
    download 'https://cfhcable.dl.sourceforge.net/project/giflib/giflib-5.2.1.tar.gz' 'giflib-5.2.1.tar.gz'
    # PARELLEL BUILDING NOT AVAILABLE FOR THIS LIBRARY
    execute make
    execute make PREFIX="$workspace" install
    build_done 'giflib' '5.2.1'
fi

pre_check_ver 'pkgconf/pkgconf' '1' 'T'
if build 'pkg-config' "$g_ver"; then
    download "$g_url" "pkgconf-$g_ver.tar.gz"
    execute ./autogen.sh
    execute ./configure --silent --prefix="$workspace" --with-pc-path="$workspace"/lib/pkgconfig --with-internal-glib --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'pkg-config' "$g_ver"
fi

pre_check_ver 'yasm/yasm' '1' 'T'
if build 'yasm' "$g_ver"; then
    download "$https://github.com/yasm/yasm/archive/refs/tags/v$g_ver.tar.gz" "yasm-$g_ver.tar.gz"
    make_dir 'build'
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DBUILD_SHARED_LIBS='OFF' -DUSE_OMP='OFF' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'yasm' "$g_ver"
fi

if build 'nasm' '2.16.02rc1'; then
    download "https://www.nasm.us/pub/nasm/releasebuilds/2.16.02rc1/nasm-2.16.02rc1.tar.xz" "nasm-2.16.02rc1.tar.xz"
    execute ./configure --prefix="$workspace" --enable-ccache --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'nasm' '2.16.02rc1'
fi

pre_check_ver 'madler/zlib' '1' 'T'
if build 'zlib' "$g_ver"; then
    download "https://github.com/madler/zlib/releases/download/v$g_ver/zlib-$g_ver.tar.gz" "zlib-$g_ver.tar.gz"
    execute ./configure --prefix="$workspace" --static
    execute make "-j$cpu_threads"
    execute make install
    build_done 'zlib' "$g_ver"
fi

if build 'm4' '1.4.19'; then
    download 'https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz' 'm4-1.4.19.tar.xz'
    execute ./configure --prefix="$workspace" --enable-c++ --with-dmalloc --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'm4' '1.4.19'
fi

if build 'autoconf' 'git'; then
    download_git 'https://git.savannah.gnu.org/git/autoconf.git' 'autoconf-git'
    execute autoreconf -fi
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'autoconf' 'git'
fi

if build 'automake' 'git'; then
    download_git 'https://git.savannah.gnu.org/git/automake.git' 'automake-git'
    execute ./bootstrap
    execute autoreconf -fi
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'automake' 'git'
fi

if build 'libtool' '2.4.7'; then
    download 'https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.xz' 'libtool-2.4.7.tar.xz'
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libtool' '2.4.7'
fi

if $nonfree_and_gpl; then
    pre_check_ver 'openssl/openssl' '1' 'L'
    if build 'openssl' "$g_ver"; then
        download "$g_url" "openssl-$g_ver.tar.gz"
        execute ./config --prefix="$workspace" --openssldir="$workspace" --with-zlib-include="$workspace"/include/ --with-zlib-lib="$workspace"/lib no-shared zlib
        execute make "-j$cpu_threads"
        execute make install_sw
        build_done 'openssl' "$g_ver"
    fi
    cnf_ops+=('--enable-openssl')
else
    if build 'gmp' '6.2.1'; then
        download 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz'
        execute ./configure --prefix="$workspace" --enable-static --disable-shared
        execute make "-j$cpu_threads"
        execute make install
        build_done 'gmp' '6.2.1'
    fi

    if build 'nettle' '3.8.1'; then
        download 'https://ftp.gnu.org/gnu/nettle/nettle-3.8.1.tar.gz'
        execute ./configure --prefix="$workspace" --libdir="$workspace"/lib --enable-static --disable-shared \
        --disable-openssl --disable-documentation CPPFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
        execute make "-j$cpu_threads"
        execute make install
        build_done 'nettle' '3.8.1'
    fi

    if build 'gnutls' '3.8.0'; then
        download 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.0.tar.xz'
        execute ./configure --prefix="$workspace" --enable-static --disable-shared --disable-doc --disable-tools \
            --disable-cxx --disable-tests --disable-gtk-doc-html --disable-libdane --disable-nls --enable-local-libopts \
            --disable-guile --with-included-libtasn1 --with-included-unistring --without-p11-kit CPPFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
        execute make "-j$cpu_threads"
        execute make install
        build_done 'gnutls' '3.8.0'
    fi
    cnf_ops+=('--enable-gmp' '--enable-gnutls')
fi

pre_check_ver 'kitware/cmake' '1' 'L'
if build 'cmake' "$g_ver" "$packages/$1.done"; then
    download "$g_url" "cmake-$g_ver.tar.gz"
    make_dir 'build'
    execute cmake -B 'build' -DCMAKE_BUILD_TYPE:STRING="Release" -DBUILD_TESTING:BOOL='0' -DCPACK_BINARY_DEB:BOOL='1' -DCMAKE_USE_SYSTEM_CURL:BOOL='0' \
        -DCPACK_BINARY_TBZ2:BOOL='0' -DCMAKE_INSTALL_PREFIX:PATH="/home/jman/tmp/ffmpeg-build/workspace" -DCPACK_ENABLE_FREEBSD_PKG:BOOL='0' \
        -DENABLE_CCACHE:BOOL='0' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'cmake' "$g_ver"
fi

##
## video libraries
##

if command_exists 'python3'; then
    # dav1d needs meson and ninja along with nasm to be built
    if command_exists 'pip3'; then
        # meson and ninja can be installed via pip3
        for r in asciidoc asciidoc3 lxml markdown meson ninja pygments rdflib xmltojson; do
      if ! command_exists $r; then
        pip install $r --quiet --upgrade
      fi
    done
    fi
    if command_exists 'meson'; then
        git_ver_fn '198' '2' 'T'
        if build 'dav1d' "$g_sver"; then
            download "https://code.videolan.org/videolan/dav1d/-/archive/$g_ver/$g_ver.tar.bz2" "dav1d-$g_sver.tar.bz2"
            CFLAGSBACKUP="$CFLAGS"
            make_dir 'build'
            execute meson setup 'build' --prefix="$workspace" --libdir="$workspace"/lib --pkg-config-path="$PKG_CONFIG_PATH" \
                --buildtype='release' --default-library='static' --optimization='s' --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'dav1d' "$g_sver"
        fi
        cnf_ops+=('--enable-libdav1d')
    fi
fi

pre_check_ver 'google/googletest' '1' 'L'
if build 'googletest' "$g_ver"; then
    download "$g_url" "googletest-$g_ver.tar.gz"
    make_dir 'build'
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DBUILD_GMOCK='OFF'-DBUILD_SHARED_LIBS='OFF' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'googletest' "$g_ver"
fi

if build 'abseil' 'git'; then
    download_git 'https://github.com/abseil/abseil-cpp.git' 'abseil-git'
    make_dir 'build'
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DCMAKE_EXPORT_COMPILE_COMMANDS='ON'-DABSL_PROPAGATE_CXX_STD='ON'\
        -DBUILD_SHARED_LIBS='OFF' -G 'Ninja' -Wno-dev
    execute cmake --build build --target all --parallel='32'
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'abseil' 'git'
fi
git_ver_fn 'google/googletest' '1' 'L'
if build 'libgav1' "$g_var"; then
    # version 1.3.0, 1.2.4, and 1.2.3 fail to build successfully
    CPPFLAGS=
    download "$g_url" "libgav1-$g_var.tar.gz"
    make_dir 'libgav1_build'
    execute git -C "$packages/libgav1-$g_var" clone -b '20220623.0' --depth '1' 'https://github.com/abseil/abseil-cpp.git' 'third_party/abseil-cpp'
    execute cmake -S . -B 'libgav1_build' -DCMAKE_INSTALL_PREFIX="$workspace" -DCMAKE_EXPORT_COMPILE_COMMANDS='0'-DABSL_ENABLE_INSTALL='0'\
        -DABSL_PROPAGATE_CXX_STD='0'-DCMAKE_INSTALL_SBINDIR='/usr/sbin' -DBUILD_SHARED_LIBS='1' -DCMAKE_STRIP='/usr/bin/strip' -G 'Ninja' -Wno-dev
    execute cmake -S . -B 'third_party/abseil-cpp' -DCMAKE_INSTALL_PREFIX="$workspace" -DCMAKE_EXPORT_COMPILE_COMMANDS='0'-DABSL_ENABLE_INSTALL='0'\
        -DABSL_PROPAGATE_CXX_STD='0'-DCMAKE_INSTALL_SBINDIR='/usr/sbin' -DCMAKE_STRIP='/usr/bin/strip' -G 'Ninja' -Wno-dev
    execute ninja -C 'libgav1_build'
    execute ninja -C 'libgav1_build' install
    execute ninja -C 'third_party/abseil-cpp'
    execute ninja -C 'third_party/abseil-cpp' install
    build_done 'libgav1' "$g_var"
fi

git_ver_fn '24327400' '3' 'T'
if build 'svtav1' "$g_ver"; then
    download "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v$g_ver/SVT-AV1-v$g_ver.tar.bz2" "SVT-AV1-$g_sver.tar.bz2"
    cd 'Build/linux' || exit 1
    execute bash build.sh prefix="$workspace" static bindir="$workspace/bin" enable-avx512 enable-lto disable-shared \
        native gen='Ninja' release jobs='32' enable-pgop cc='/usr/lib/ccache/clang-14' cxx='/usr/lib/ccache/clang++-14'
    execute ninja -C 'Release'
    execute ninja -C 'Release' install
    execute cp 'Release/SvtAv1Dec.pc' "$workspace"/lib/pkgconfig
    execute cp 'Release/SvtAv1Enc.pc' "$workspace"/lib/pkgconfig
    build_done 'svtav1' "$g_ver"
fi
cnf_ops+=('--enable-libsvtav1')

if command_exists 'cargo'; then
    pre_check_ver 'xiph/rav1e' '1' 'L'
    if build 'rav1e' "$g_ver"; then
        download "https://github.com/xiph/rav1e/archive/refs/tags/v$g_ver.tar.gz" "rav1e-$g_ver.tar.gz"
        execute cargo install --all-features --version '0.9.14+cargo-0.66' cargo-c
        execute cargo cinstall --prefix="$workspace" --library-type='staticlib' --crt-static --release
        build_done 'rav1e' "$g_ver"
    fi
    avif_tag='-DAVIF_CODEC_RAV1E=0'
    cnf_ops+=('--enable-librav1e')
else
    avif_tag='-DAVIF_CODEC_RAV1E=1'
fi

if $nonfree_and_gpl; then
    git_ver_fn '536' '2' 'B'
    if build 'x264' "$g_sver"; then
        download "https://code.videolan.org/videolan/x264/-/archive/$g_ver/x264-$g_ver.tar.bz2" "x264-$g_sver.tar.bz2"
        execute ./configure --prefix="$workspace" --enable-static --enable-pic CXXFLAGS+=' -fPIC'
        execute make "-j$cpu_threads"
        execute make install
        execute make install-lib-static
        build_done 'x264' "$g_sver"
    fi
    cnf_ops+=('--enable-libx264')
fi

if $nonfree_and_gpl; then
    # API CALL is BROKEN FOR LATEST VERSION. THIS IS AT LEAST STABLE AND WILL BUILD WITHOUT FAILING
    git_ver_fn 'videolan/x265' '1' 'T'
    if build 'x265' '3.4'; then
        download 'https://github.com/videolan/x265/archive/refs/tags/3.4.tar.gz' "x265-3.4.tar.gz"
        cd 'build/linux' || exit
        rm -fr {8,10,12}bit 2>/dev/null
        mkdir -p {8,10,12}bit
        cd 12bit || exit 1
        execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${workspace}" -DENABLE_SHARED='OFF' -DBUILD_SHARED_LIBS='OFF' \
            -DHIGH_BIT_DEPTH='ON' -DENABLE_HDR10_PLUS='ON' -DEXPORT_C_API='OFF' -DENABLE_CLI='OFF' -DMAIN12='ON' -G 'Ninja' -Wno-dev
        execute ninja
        cd ../10bit || exit 1
        execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${workspace}" -DENABLE_SHARED='OFF' -DBUILD_SHARED_LIBS='OFF' \
            -DHIGH_BIT_DEPTH='ON' -DENABLE_HDR10_PLUS='ON' -DEXPORT_C_API='OFF' -DENABLE_CLI='OFF' -G 'Ninja' -Wno-dev
        execute ninja
        cd ../8bit || exit 1
        ln -sf ../10bit/libx265.a 'libx265_main10.a'
        ln -sf ../12bit/libx265.a 'libx265_main12.a'
        execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${workspace}" -DENABLE_SHARED='OFF' -DBUILD_SHARED_LIBS='OFF' \
            -DEXTRA_LIB="x265_main10.a;x265_main12.a;-ldl" -DEXTRA_LINK_FLAGS='-L.' -DLINKED_10BIT='ON' -DLINKED_12BIT='ON' -G 'Ninja' -Wno-dev
        execute ninja
        mv libx265.a  libx265_main.a

        execute ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF

        execute ninja install

        if [ -n "$LDEXEFLAGS" ]; then
            sed -i.backup 's/-lgcc_s/-lgcc_eh/g' "$workspace"/lib/pkgconfigx265.pc
        fi

        build_done 'x265' '3.4'
    fi
    cnf_ops+=('--enable-libx265')
fi

pre_check_ver 'openvisualcloud/svt-hevc' '1' 'L'
if build 'SVT-HEVC' "$g_ver"; then
    download "$g_url" "SVT-HEVC-$g_ver.tar.gz"
    cd 'Build/linux' || exit 1
    execute ./build.sh
    execute cp 'Release/SvtHevcEnc.pc' "$workspace"/lib/pkgconfig
    build_done 'SVT-HEVC' "$g_ver"
fi

pre_check_ver 'webmproject/libvpx' '1' 'T'
if build 'libvpx' "$g_ver"; then
    download "$g_url" "libvpx-$g_ver.tar.gz"
    execute ./configure --prefix="$workspace" --disable-unit-tests --disable-shared --disable-examples --as='yasm' \
        --target='x86_64-linux-gcc' --enable-ccache --enable-vp9-highbitdepth --enable-better-hw-compatibility \
        --enable-vp8 --enable-vp9 --enable-postproc --enable-vp9-postproc --enable-realtime-only --enable-onthefly-bitpacking \
        --enable-coefficient-range-checking --enable-runtime-cpu-detect --enable-small --enable-multi-res-encoding --enable-vp9-temporal-denoising \
        --enable-libyuv
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libvpx' "$g_ver"
fi
cnf_ops+=('--enable-libvpx')

if $nonfree_and_gpl; then
    if build 'xvidcore' '1.3.7'; then
        download 'https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.bz2' 'xvidcore-1.3.7.tar.bz2'
        cd 'build/generic' || exit 1
        execute ./configure --prefix="$workspace" --enable-static --disable-shared
        execute make "-j$cpu_threads"
        execute make install

        if [ -f "$workspace"/lib/libxvidcore.4.dylib ]; then
            execute sudo rm "$workspace"/lib/libxvidcore.4.dylib
        fi

        if [ -f "$workspace"/lib/libxvidcore.so ]; then
            execute sudo rm "$workspace"/lib/libxvidcore.so*
        fi

        cd '=build' || exit 1
        execute ln -s 'libxvidcore.so.4.3' "$workspace"/lib/libxvidcore.so.4@
        execute ln -s 'libxvidcore.so.4@' "$workspace"/lib/libxvidcore.so

        build_done 'xvidcore' '1.3.7'
    fi
    cnf_ops+=('--enable-libxvid')
fi

if $nonfree_and_gpl; then
    pre_check_ver 'georgmartius/vid.stab' '1' 'T'
    if build 'vid_stab' "$g_ver"; then
        download "$g_url" "vid.stab-$g_ver.tar.gz"
        make_dir 'build'
        execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DBUILD_SHARED_LIBS='OFF' -DCMAKE_BUILD_TYPE='Release' \
             -DUSE_OMP='ON' -G 'Ninja' -Wno-dev
        execute ninja -C 'build'
        execute ninja -C 'build' install
        build_done 'vid_stab' "$g_ver"
    fi
    cnf_ops+=('--enable-libvidstab')
fi

if build 'av1' 'd192cdf'; then
    download 'https://aomedia.googlesource.com/aom/+archive/d192cdfc229d3d4edf6a0acd2e5b71fb4880d28e.tar.gz' 'av1-d192cdf.tar.gz' 'av1'
    make_dir "$packages"/aom_build
    cd "$packages"/aom_build || exit 1
    make_dir 'build'
    execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX:PATH="$workspace" -DCMAKE_INSTALL_LIBEXECDIR:PATH="$workspace" \
        -DBIN_INSTALL_DIR:STRING="$workspace/bin" -DINCLUDE_INSTALL_DIR:PATH="$workspace/include" \
        -DLIB_INSTALL_DIR:STRING="$workspace/lib" -DBUILD_CONVERTSTACKED:BOOL='0' -DBUILD_SHARED_LIBS:BOOL='1' \
        -DBUILD_SHIBATCH:BOOL='0' -DBUILD_TIMESTRETCH:BOOL='0' -DCMAKE_BUILD_TYPE='Release' -DCONFIG_ACCOUNTING:STRING='0' \
        -DCONFIG_ANALYZER:STRING='0' -DCONFIG_AV1_DECODER:STRING='1' -DCONFIG_AV1_ENCODER:STRING='1' \
        -DCONFIG_AV1_HIGHBITDEPTH:STRING='1' -DCONFIG_AV1_TEMPORAL_DENOISING:STRING='0' -DCONFIG_BIG_ENDIAN:STRING='0' \
        -DCONFIG_BITRATE_ACCURACY_BL:STRING='0' -DCONFIG_BITRATE_ACCURACY:STRING='0' -DCONFIG_BITSTREAM_DEBUG:STRING='0' \
        -DCONFIG_COEFFICIENT_RANGE_CHECKING:STRING='0' -DCONFIG_COLLECT_COMPONENT_TIMING:STRING='0' \
        -DCONFIG_COLLECT_PARTITION_STATS:STRING='0' -DCONFIG_COLLECT_RD_STATS:STRING='0' -DCONFIG_DEBUG:STRING='0' \
        -DCONFIG_DENOISE:STRING='1' -DCONFIG_DISABLE_FULL_PIXEL_SPLIT_8X8:STRING='1' -DCONFIG_ENTROPY_STATS:STRING='0' \
        -DCONFIG_EXCLUDE_SIMD_MISMATCH:STRING='0' -DCONFIG_FPMT_TEST:STRING='0' -DCONFIG_GCC:STRING='0' -DCONFIG_GCOV:STRING='0' \
        -DCONFIG_GPROF:STRING='0' -DCONFIG_INSPECTION:STRING='0' -DCONFIG_INTERNAL_STATS:STRING='0' -DCONFIG_INTER_STATS_ONLY:STRING='0' \
        -DCONFIG_LIBYUV:STRING='1' -DCONFIG_MAX_DECODE_PROFILE:STRING="2" -DCONFIG_MISMATCH_DEBUG:STRING='0' \
        -DCONFIG_MULTITHREAD:STRING='0' -DCONFIG_NN_V2:STRING='0' -DCONFIG_NORMAL_TILE_MODE:STRING='0' -DCONFIG_OPTICAL_FLOW_API:STRING='0' \
        -DCONFIG_OS_SUPPORT:STRING='0' -DCONFIG_OUTPUT_FRAME_SIZE:STRING='0' -DCONFIG_PARTITION_SEARCH_ORDER:STRING='0' \
        -DCONFIG_PIC:STRING='0' -DCONFIG_RATECTRL_LOG:STRING='0' -DCONFIG_RD_COMMAND:STRING='0' -DCONFIG_RD_DEBUG:STRING='0' \
        -DCONFIG_REALTIME_ONLY:STRING='0' -DCONFIG_RT_ML_PARTITIONING:STRING='0' -DCONFIG_RUNTIME_CPU_DETECT:STRING='1' \
        -DCONFIG_SALIENCY_MAP:STRING='0' -DCONFIG_SHARED:STRING='1' -DCONFIG_SIZE_LIMIT:STRING='0' -DCONFIG_SPATIAL_RESAMPLING:STRING='1' \
        -DCONFIG_SPEED_STATS:STRING='0' -DCONFIG_TFLITE:STRING='0' -DCONFIG_THREE_PASS:STRING='0' -DCONFIG_TUNE_BUTTERAUGLI:STRING='0' \
        -DCONFIG_TUNE_VMAF:STRING='0' -DCONFIG_WEBM_IO:STRING='1' -DDECODE_HEIGHT_LIMIT:STRING='0' -DDECODE_WIDTH_LIMIT:STRING='0' \
        -DENABLE_AVX2:BOOL='0' -DENABLE_AVX:BOOL='0' -DENABLE_CCACHE:BOOL='0' -DENABLE_DOCS:BOOL='1' -DENABLE_EXAMPLES:BOOL='1' \
        -DENABLE_INTEL_SIMD:BOOL='0' -DENABLE_MMX:BOOL='0' -DENABLE_NASM:BOOL='1' -DENABLE_NEON:BOOL='0' -DENABLE_PLUGINS:BOOL='0' \
        -DENABLE_SSE2:BOOL='0' -DENABLE_SSE3:BOOL='0' -DENABLE_SSE4_1:BOOL='0' -DENABLE_SSE4_2:BOOL='0' -DENABLE_SSE:BOOL='0' \
        -DENABLE_SSSE3:BOOL='0' -DENABLE_TESTDATA:BOOL='1' -DENABLE_TESTS:BOOL='1' -DENABLE_TOOLS:BOOL='1' -DENABLE_UNICODE:BOOL='0' \
        -DENABLE_VSX:BOOL='0' -DENABLE_WERROR:BOOL='1' -DLARGE_FILES:BOOL='0' -DSTATIC_LINK_JXL:STRING='0' -G 'Ninja' "$packages"/av1
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'av1' 'd192cdf'
fi
cnf_ops+=('--enable-libaom')

pre_check_ver 'sekrit-twc/zimg' '1' 'L'
if build 'zimg' "$g_ver"; then
    download "$g_url" "zimg-$g_ver.tar.gz"
    execute "$workspace"/bin/libtoolize -fiq
    execute autoreconf -fi
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'zimg' "$g_ver"
fi
cnf_ops+=('--enable-libzimg')

if build "libpng" '1.6.39'; then
    download "https://github.com/glennrp/libpng/archive/refs/tags/v1.6.39.tar.gz" 'libpng-1.6.39.tar.gz'
    execute autoreconf -fi
    execute ./configure --prefix="$workspace" --enable-static --disable-shared --enable-unversioned-links \
        --enable-hardware-optimizations
    execute make "-j$cpu_threads"
    execute make install-header-links
    execute make install-library-links
    execute make install
  build_done "libpng" '1.6.39'
fi

pre_check_ver 'AOMediaCodec/libavif' '1' 'L'
if build 'avif' "$g_ver"; then
    export CFLAGS="-I$CFLAGS -I$workspace/include"
    download "$g_url" "avif-$g_ver.tar.gz"
    cd 'ext' || exit 1
    execute rm 'googletest.cmd' 'libgav1_android.sh' 'libgav1.cmd' 'libsharpyuv.cmd' 'svt.cmd'
    echo '$ for i in *.cmd; do ./"$i"; done'
    for i in *.cmd; do bash "$i"; done &>/dev/null
    execute bash svt.sh &>/dev/null
    cd ../
    make_dir 'build'
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DAVIF_BUILD_APPS='OFF'-DAVIF_CODEC_AOM='OFF'-DAVIF_LOCAL_AOM='OFF'\
        -DAVIF_LOCAL_DAV1D='OFF'-DAVIF_LOCAL_JPEG='OFF'-DAVIF_LOCAL_LIBYUV='OFF'-DAVIF_LOCAL_RAV1E='OFF'-DAVIF_LOCAL_SVT='OFF'\
        -DAVIF_LOCAL_ZLIBPNG='OFF'-DBUILD_SHARED_LIBS='ON' -DCMAKE_ASM_FLAGS_DEBUG='-g' -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_C_FLAGS_DEBUG='-g' -DCMAKE_C_FLAGS_RELEASE='-O3 -DCMAKE_C_FLAGS'_RELWITHDEBINFO='-O2 -g' \
        -DZLIB_INCLUDE_DIR="$packages/avif-0.11.1/ext/zlib" \
        -Wno-dev -Wno-deprecated -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'avif' "$g_ver"
fi

pre_check_ver 'ultravideo/kvazaar' '1' 'L'
if build 'kvazaar' "$g_ver"; then
    download "$g_url" "kvazaar-$g_ver.tar.gz"
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared --enable-fast-install='yes'
    execute make "-j$cpu_threads"
    execute make install
    build_done 'kvazaar' "$g_ver"
fi
cnf_ops+=('--enable-libkvazaar')

##
## audio libraries
##

if command_exists 'python3'; then
    if command_exists 'meson'; then
        pre_check_ver 'lv2/lv2' '1' 'T'
        if build 'lv2' "$g_ver"; then
            download "$g_url" "lv2-$g_ver.tar.gz"
            execute meson setup 'build' --prefix="$workspace" --buildtype='release' --default-library='static' \
                --pkg-config-path="$workspace/lib/pkgconfig" --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'lv2' "$g_ver"
        fi

        git_ver_fn '7131569' '3' 'T'
        if build 'waflib' "$g_ver"; then
            download "https://gitlab.com/ita1024/waf/-/archive/$g_ver/waf-$g_ver.tar.bz2" "autowaf-$g_ver.tar.bz2"
            build_done 'waflib' "$g_ver"
        fi

        git_ver_fn '5048975' '3' 'T'
        if build 'serd' "$g_ver"; then
            download "https://gitlab.com/drobilla/serd/-/archive/v$g_ver/serd-v$g_ver.tar.bz2" "serd-$g_ver.tar.bz2"
            execute meson setup 'build' --prefix="$workspace" --buildtype='release' --default-library='static' \
                --pkg-config-path="$workspace/lib/pkgconfig" --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'serd' "$g_ver"
        fi

        pre_check_ver 'pcre2project/pcre2' '1' 'L'
        if build 'pcre2' "$g_ver"; then
            download "$g_url" "pcre2-$g_ver.tar.gz"
            execute ./autogen.sh
            execute ./configure --prefix="$workspace" --enable-static --disable-shared
            execute make "-j$cpu_threads"
            execute make install
            build_done 'pcre2' "$g_ver"
        fi

        git_ver_fn '14889806' '3' 'B'
        if build 'zix' "$g_sver1"; then
            download "https://gitlab.com/drobilla/zix/-/archive/$g_ver1/zix-$g_ver1.tar.bz2" "zix-$g_sver1.tar.bz2"
            execute meson setup 'build' --prefix="$workspace" --buildtype='release' --default-library='static' \
                --pkg-config-path="$workspace/lib/pkgconfig" --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'zix' "$g_sver1"
        fi

          git_ver_fn '11853362' '3' 'B'
        if build 'sord' "$g_sver1"; then
            CFLAGS+="$CFLAGS -I$workspace/include/serd-0"
            download "https://gitlab.com/drobilla/sord/-/archive/$g_ver1/sord-$g_ver1.tar.bz2" "sord-$g_sver1.tar.bz2"
            execute meson setup build --prefix="$workspace" --buildtype='release' --default-library='static' \
                --pkg-config-path="$workspace/lib/pkgconfig:$workspace/lib/x86_64-linux-gnu/pkgconfig" --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'sord' "$g_sver1"
        fi

        git_ver_fn '11853194' '3' 'T'
        if build 'sratom' "$g_sver1"; then
            download "https://gitlab.com/lv2/sratom/-/archive/$g_ver1/sratom-$g_ver1.tar.bz2" "sratom-$g_sver1.tar.bz2"
            execute meson setup build --prefix="$workspace" --buildtype='release' --default-library='static' \
                --pkg-config-path="$workspace/lib/pkgconfig:$workspace/lib/x86_64-linux-gnu/pkgconfig" --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'sratom' "$g_sver1"
        fi

        git_ver_fn '11853176' '3' 'T'
        if build 'lilv' "$g_ver"; then
            download "https://gitlab.com/lv2/lilv/-/archive/v$g_ver/lilv-v$g_ver.tar.bz2" "lilv-$g_ver.tar.bz2"
            execute meson setup build --prefix="$workspace" --buildtype='release' --default-library='static' \
                --pkg-config-path="$workspace/lib/pkgconfig:$workspace/lib/x86_64-linux-gnu/pkgconfig" --strip
            execute ninja -C 'build'
            execute ninja -C 'build' install
            build_done 'lilv' "$g_ver"
        fi
        CFLAGS+=" -I$workspace/include/lilv-0"
        cnf_ops+=('--enable-lv2')
    fi
fi

if build 'opencore' '0.1.6'; then
    download 'https://master.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.6.tar.gz?viasf=1' 'opencore-amr-0.1.6.tar.gz'
    execute ./configure --prefix="$workspace" --enable-static --disable-shared --enable-fast-install
    execute make "-j$cpu_threads"
    execute make install
    build_done 'opencore' '0.1.6'
fi
cnf_ops+=('--enable-libopencore_amrnb' '--enable-libopencore_amrwb')

if build 'lame' '3.100'; then
    download 'https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download?use_mirror=gigenet' 'lame-3.100.tar.gz'
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'lame' '3.100'
fi
cnf_ops+=('--enable-libmp3lame')

pre_check_ver 'xiph/opus' '1' 'L'
if build 'opus' "$g_ver"; then
    download "$g_url" "opus-$g_ver.tar.gz"
    make_dir 'build'
    execute autoreconf -isf
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DBUILD_SHARED_LIBS='1' -DCMAKE_C_FLAGS_DEBUG='-g' \
        -DBUILD_SHARED_LIBS='1' -DCPACK_SOURCE_ZIP='1' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'opus' "$g_ver"
fi
cnf_ops+=('--enable-libopus')

pre_check_ver 'xiph/ogg' '1' 'L'
if build 'libogg' "$g_ver"; then
    download "$g_url" "libogg-$g_ver.tar.gz"
    execute mkdir -p 'm4' 'build'
    execute autoreconf -fi
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace"  -DCMAKE_BUILD_TYPE='Release' -DBUILD_SHARED_LIBS='OFF' \
        -DCPACK_BINARY_DEB='OFF'-DBUILD_TESTING='ON'-DCPACK_SOURCE_ZIP='OFF' -DBUILD_SHARED_LIBS='OFF' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'libogg' "$g_ver"
fi

pre_check_ver 'xiph/vorbis' '1' 'L'
if build 'libvorbis' "$g_ver"; then
    download "$g_url" "libvorbis-$g_ver.tar.gz"
    make_dir 'build'
    execute autoreconf -fi
    execute cmake -S . -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DBUILD_SHARED_LIBS='OFF' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'libvorbis' "$g_ver"
fi
cnf_ops+=('--enable-libvorbis')

# pre_check_ver 'xiph/theora' '1' 'L'
# this repo does not return the correct latest version when the API CALL is used.
if build 'libtheora' '1.0'; then
    download 'https://github.com/xiph/theora/archive/refs/tags/v1.0.tar.gz' "libtheora-1.0.tar.gz"
    execute ./autogen.sh
    sed 's/-fforce-addr//g' 'configure' >'configure.patched'
    chmod +x 'configure.patched'
    execute mv 'configure.patched' 'configure'
    execute rm 'config.guess'
    execute curl -Lso 'config.guess' 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess'
    chmod +x 'config.guess'
    execute ./configure --prefix="$workspace" --with-ogg-libraries="$workspace"/lib --with-ogg-includes="$workspace"/include \
        --with-vorbis-libraries="$workspace"/lib --with-vorbis-includes="$workspace"/include --enable-static --disable-shared \
        --disable-oggtest --disable-vorbistest --disable-examples --disable-asm --disable-spec
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libtheora' '1.0'
fi
cnf_ops+=('--enable-libtheora')

if $nonfree_and_gpl; then
    pre_check_ver 'mstorsjo/fdk-aac' '1' 'T'
    if build 'fdk_aac' "$g_ver"; then
    download "https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v$g_ver.tar.gz" "fdk_aac-$g_ver.tar.gz"
        execute ./autogen.sh
        execute ./configure --prefix="$workspace" --bindir="$workspace"/bin --enable-static --disable-shared --enable-pic \
            CXXFLAGS='-fno-exceptions -fno-rtti'
        execute make "-j$cpu_threads"
        execute make install
        build_done 'fdk_aac' "$g_ver"
    fi
    cnf_ops+=('--enable-libfdk-aac')
fi

##
## image libraries
##

pre_check_ver 'mm2/Little-CMS' '1' 'L'
if build 'lcms' "$g_ver"; then
    download "$g_url" "lcms-$g_ver.tar.gz"
    make_dir 'build'
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'lcms' "$g_ver"
fi
cnf_ops+=('--enable-lcms2')

pre_check_ver 'uclouvain/openjpeg' '1' 'L'
if build 'openjpeg' "$g_ver"; then
    download "$g_url" "openjpeg-$g_ver.tar.gz"
    make_dir 'build'
    execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DCMAKE_LIBRARY_PATH="$workspace" \
        -DBUILD_PKGCONFIG_FILES='O' -DBUILD_SHARED_LIBS='OFF' -DBUILD_STATIC_LIBS='ON' -DBUILD_THIRDPARTY='ON'\
        -DCMAKE_ADDR2LINE='/usr/bin/addr2line' -DCMAKE_BUILD_TYPE='Release' -DCMAKE_C_FLAGS='-O3 -march=native -DNDEBUG' \
        -DCMAKE_C_FLAGS='-O3 -mavx2 -DNDEBUG' -DCMAKE_C_FLAGS='-O3 -msse4.1 -DNDEBUG' -DCMAKE_STRIP='/usr/bin/strip' \
        -DCPACK_BINARY_STGZ='ON'-DCPACK_BINARY_TGZ='ON'-DCPACK_BINARY_TZ='ON'-DCPACK_SOURCE_TBZ2='ON'-DCPACK_SOURCE_TGZ='ON'\
        -DCPACK_SOURCE_TXZ='ON'-DCPACK_SOURCE_TZ='ON'-DLCMS2_INCLUDE_DIR='/usr/include' \
        -DLCMS2_LIBRARY='/usr/lib/x86_64-linux-gnu/liblcms2.so' -Dpkgcfg_lib_PC_LCMS2_lcms2='/usr/lib/x86_64-linux-gnu/liblcms2.so' \
        -DPKG_CONFIG_EXECUTABLE='/usr/bin/pkg-config' -DPNG_LIBRARY_RELEASE='/usr/lib/x86_64-linux-gnu/libpng.so' \
        -DPNG_PNG_INCLUDE_DIR='/usr/include' -DTIFF_INCLUDE_DIR='/usr/include/x86_64-linux-gnu' \
        -DTIFF_LIBRARY_RELEASE='/usr/lib/x86_64-linux-gnu/libtiff.so' -DZLIB_INCLUDE_DIR='/usr/include' \
        -DZLIB_LIBRARY_RELEASE='/usr/lib/x86_64-linux-gnu/libz.so' -G 'Ninja' -Wno-Dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'openjpeg' "$g_ver"
fi
cnf_ops+=('--enable-libopenjpeg')

git_ver_fn '4720790' '3' 'T'
if build 'libtiff' "$g_ver"; then
    download "https://gitlab.com/libtiff/libtiff/-/archive/v$g_ver/libtiff-v$g_ver.tar.bz2" "libtiff-$g_ver.tar.bz2"
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libtiff' "$g_ver"
fi

if build 'libwebp' 'git'; then
    CPPFLAGS=
    download_git 'https://chromium.googlesource.com/webm/libwebp' 'libwebp-git'
    execute autoreconf -fi
    make_dir 'build'
    execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" CMAKE_PREFIX_PATH="$workspace/lib/pkgconfig" \
        -DBUILD_SHARED_LIBS='OFF' -DCMAKE_BUILD_TYPE='Release' -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
        -DCMAKE_INSTALL_INCLUDEDIR="$workspace/include" -DWEBP_LINK_STATIC='ON'-DWEBP_BUILD_DWEBP='ON'\
        -DWEBP_BUILD_CWEBP='ON'-DZLIB_INCLUDE_DIR="/usr/include" -DTIFF_INCLUDE_DIR='/usr/include/x86_64-linux-gnu' \
        -DPNG_PNG_INCLUDE_DIR='/usr/include' LCMS2_INCLUDE_DIR='/usr/include' -G 'Ninja' -Wno-dev
    execute ninja -C 'build' all
    execute ninja -C 'build' install
    build_done 'libwebp' 'git'
fi
cnf_ops+=('--enable-libwebp')

##
## other libraries
##

git_ver_fn '1665' '6' 'T'
if build 'xml2' "$g_ver"; then
    download "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v$g_ver/libxml2-v$g_ver.tar.bz2" "xml2-$g_ver.tar.bz2"
    make_dir build
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared --enable-fast-install --with-aix-soname='both' \
        --with-ftp --with-minimum --with-threads --with-thread-alloc --with-zlib='/usr/lib/x86_64-linux-gnu/pkgconfig' --with-lzma='/usr/lib/x86_64-linux-gnu/pkgconfig'
    execute make "-j$cpu_threads"
    execute make install
    build_done 'xml2' "$g_ver"
fi
cnf_ops+=('--enable-libxml2')

pre_check_ver 'dyne/frei0r' '1' 'L'
if build 'frei0r' "$g_ver"; then
    download "$g_url" "frei0r-$g_ver.tar.gz"
    make_dir 'build'
    execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DWITHOUT_OPENCV='OFF'\
        -DCMAKE_CXX_COMPILER_RANLIB="/usr/bin/gcc-ranlib-12" -DCMAKE_CXX_FLAGS_DEBUG="-g" -DCMAKE_EXPORT_COMPILE_COMMANDS='ON'\
        -DWEBP_ENABLE_SWAP_16BIT_CSP='ON'-DBUILD_SHARED_LIBS='OFF' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'frei0r' "$g_ver"
fi
cnf_ops+=('--enable-frei0r')

pre_check_ver 'avisynth/avisynthplus' '1' 'L'
if build 'avisynth' "$g_ver"; then
    download_git 'https://github.com/AviSynth/AviSynthPlus.git' "avisynth-$g_ver"
    make_dir 'build'
    execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX:PATH="$workspace" -DBIN_INSTALL_DIR:STRING="$workspace/bin" \
        -DINCLUDE_INSTALL_DIR:PATH="$workspace/include" -DLIB_INSTALL_DIR:STRING="$workspace/lib" \
        -DBUILD_CONVERTSTACKED:BOOL='0' -DBUILD_SHARED_LIBS:BOOL='0' -DBUILD_SHIBATCH:BOOL='0' \
        -DBUILD_TIMESTRETCH:BOOL='0' -DENABLE_INTEL_SIMD:BOOL='0' -DENABLE_PLUGINS:BOOL='0' \
        -DENABLE_UNICODE:BOOL='0' -DLARGE_FILES:BOOL='0' -G 'Ninja' -Wno-dev
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'avisynth' "$g_ver"
fi
cnf_ops+=('--enable-avisynth')

git_ver_fn '363' '2' 'T'
if build 'udfread' "$g_ver1"; then
    download "https://code.videolan.org/videolan/libudfread/-/archive/$g_ver1/libudfread-$g_ver1.tar.bz2" "udfread-$g_ver1.tar.bz2"
    execute autoreconf -fi
    execute ./configure --prefix="$workspace" --enable-static --disable-shared --with-pic --with-gnu-ld
    execute make "-j$cpu_threads"
    execute make install
    build_done 'udfread' "$g_ver1"
fi

git_ver_fn '206' '2' 'T'
if build 'libbluray' "$g_ver1"; then
    download "https://code.videolan.org/videolan/libbluray/-/archive/$g_ver1/$g_ver1.tar.gz" "libbluray-$g_ver1.tar.gz"
    execute autoreconf -fi
    execute ./configure --prefix="$workspace" --enable-static --disable-shared --without-libxml2
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libbluray' "$g_ver1"
fi
unset JAVA_HOME
cnf_ops+=('--enable-libbluray')

pre_check_ver 'mediaarea/zenLib' '1' 'L'
if build 'zenLib' "$g_ver"; then
    download "https://github.com/MediaArea/ZenLib/archive/refs/tags/v$g_ver.tar.gz" "zenLib-$g_ver.tar.gz"
    cd Project/CMake || exit 1
    execute cmake -S . -DCMAKE_INSTALL_PREFIX:PATH="$workspace" -DBIN_INSTALL_DIR:STRING="$workspace/bin" \
    -DINCLUDE_INSTALL_DIR:PATH="$workspace/include" -DLIB_INSTALL_DIR:STRING="$workspace/lib" \
    -DBUILD_SHARED_LIBS:BOOL='0' -DENABLE_UNICODE:BOOL='0' -DLARGE_FILES:BOOL='0' -G 'Ninja' -Wno-dev
    execute ninja
    execute ninja install
    build_done 'zenLib' "$g_ver"
fi

pre_check_ver 'MediaArea/MediaInfoLib' '1' 'T'
if build 'MediaInfoLib' "$g_ver"; then
    download "https://github.com/MediaArea/MediaInfoLib/archive/refs/tags/v$g_ver.tar.gz" "MediaInfoLib-$g_ver.tar.gz"
    cd 'Project/GNU/Library' || exit 1
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'MediaInfoLib' "$g_ver"
fi

pre_check_ver 'MediaArea/MediaInfo' '1' 'T'
if build 'MediaInfoCLI' "$g_ver"; then
    download "https://github.com/MediaArea/MediaInfo/archive/refs/tags/v$g_ver.tar.gz" "MediaInfo-$g_ver.tar.gz"
    cd 'Project/GNU/CLI' || exit 1
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'MediaInfoCLI' "$g_ver"
fi

if command_exists 'meson'; then
    pre_check_ver 'harfbuzz/harfbuzz' '1' 'L'
    if build 'harfbuzz' "$g_ver"; then
        download "$g_url" "harfbuzz-$g_ver.tar.gz"
        execute autoreconf -fi
        execute ./configure --prefix="$workspace" --enable-static --disable-shared
        execute make "-j$cpu_threads"
        execute make install
        build_done 'harfbuzz' "$g_ver"
    fi
fi

if build 'c2man' 'git'; then
    download_git 'https://github.com/fribidi/c2man.git' 'c2man-git'
    execute ./Configure -desO -D prefix="$workspace" -D bin="$workspace"/bin -D bash='/bin/bash' -D cc='/usr/bin/cc' \
        -D d_gnu='/usr/lib/x86_64-linux-gnu' -D find='/usr/bin/find' -D gcc='/usr/lib/ccache/gcc-12' -D gzip='/usr/bin/gzip' \
        -D installmansrc="$workspace"/share/man -D ldflags=" -L $workspace/lib -L/usr/local/lib" -D less='/usr/bin/less' \
        -D libpth="$workspace/lib /usr/local/lib /lib /usr/lib" \
        -D locincpth="$workspace/include /usr/local/include /opt/local/include /usr/gnu/include /opt/gnu/include /usr/GNU/include /opt/GNU/include" \
        -D yacc='/usr/bin/yacc' -D loclibpth="$workspace/lib /usr/local/lib /opt/local/lib /usr/gnu/lib /opt/gnu/lib /usr/GNU/lib /opt/GNU/lib" \
        -D make='/usr/bin/make' -D more='/usr/bin/more' -D osname='Ubuntu' -D perl='/usr/bin/perl' -D privlib="$workspace"/lib/c2man \
        -D privlibexp="$workspace"/lib/c2man -D sleep='/usr/bin/sleep' -D tail='/usr/bin/tail' -D tar='/usr/bin/tar' -D uuname='Linux' \
        -D vi='/usr/bin/vi' -D zip='/usr/bin/zip'
    execute make depend
    execute make "-j$cpu_threads"
    execute sudo make install
    build_done 'c2man' 'git'
fi

pre_check_ver 'fribidi/fribidi' '1' 'L'
if build 'fribidi' "$g_ver"; then
    download "$g_url" "fribidi-$g_ver.tar.gz"
    execute ./autogen.sh
    execute meson setup 'build' --prefix="$workspace" --buildtype='release' --default-library='static' \
        --pkg-config-path="$workspace/lib/pkgconfig:$workspace/lib/x86_64-linux-gnu/pkgconfig" --strip -Ddocs=false
    execute ninja -C 'build'
    execute ninja -C 'build' install
    execute libtool --finish "$workspace/lib"
    build_done 'fribidi' "$g_ver"
fi
cnf_ops+=('--enable-libfribidi')

pre_check_ver 'libass/libass' '1' 'L'
if build 'libass' "$g_ver"; then
    download "$g_url" "libass-$g_ver.tar.gz"
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libass' "$g_ver"
fi
cnf_ops+=('--enable-libass')

git_ver_fn '890' '4'
if build 'fontconfig' "$g_ver"; then
    extracommands=(-D{harfbuzz,png,bzip2,brotli,zlib,tests}"=disabled")
    download "https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/$g_ver/fontconfig-$g_ver.tar.bz2" "fontconfig-$g_ver.tar.bz2"
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'fontconfig' "$g_ver"
fi
cnf_ops+=('--enable-libfontconfig')

git_ver_fn '7950' '4'
if build 'freetype' "$g_ver"; then
    extracommands=(-D{harfbuzz,png,bzip2,brotli,zlib,tests}"=disabled")
    download "https://gitlab.freedesktop.org/freetype/freetype/-/archive/$g_ver/freetype-$g_ver.tar.bz2" "freetype-$g_ver.tar.bz2"
    execute ./autogen.sh
    execute meson setup 'build' --prefix="$workspace" --buildtype='release' --default-library='static' \
        --pkg-config-path="$workspace/lib/pkgconfig:$workspace/lib/x86_64-linux-gnu/pkgconfig" --strip
    execute ninja -C 'build'
    execute ninja -C 'build' install
    build_done 'freetype' "$g_ver"
fi
cnf_ops+=('--enable-libfreetype')

pre_check_ver 'libsdl-org/SDL' '1' 'L'
if build 'libsdl' "$g_ver"; then
    download "$g_url" "libsdl-$g_ver.tar.gz"
    execute ./autogen.sh
    execute ./configure --prefix="$workspace" --enable-static --disable-shared
    execute make "-j$cpu_threads"
    execute make install
    build_done 'libsdl' "$g_ver"
fi

if $nonfree_and_gpl; then
    pre_check_ver 'Haivision/srt' '1' 'L'
    if build 'srt' "$g_ver"; then
        download "$g_url" "srt-$g_ver.tar.gz"
        export OPENSSL_ROOT_DIR="$workspace"
        export OPENSSL_LIB_DIR="$workspace"/lib
        export OPENSSL_INCLUDE_DIR="$workspace"/include
        make_dir 'build'
        execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX:PATH="$workspace" -DCMAKE_BUILD_TYPE:STRING='Release' \
            -DENABLE_APPS:BOOL='0' -DENABLE_CXX11:BOOL='0' -DENABLE_CXX_DEPS:BOOL='0' -DENABLE_ENCRYPTION:BOOL='0' \
            -DENABLE_INET_PTON:BOOL='0' -DENABLE_LOGGING:BOOL='0' -DENABLE_MONOTONIC_CLOCK:BOOL='0' \
            -DENABLE_NEW_RCVBUFFER:BOOL='0' -DENABLE_SHARED:BOOL='1' -DENABLE_SOCK_CLOEXEC:BOOL='0' \
            -DENABLE_STATIC:BOOL='0' -DUSE_OPENSSL_PC:BOOL='0' -DUSE_STATIC_LIBSTDCXX='0' -G 'Ninja' -Wno-dev
        execute ninja -C 'build'
        execute ninja -C 'build' install

        if [ -n "$LDEXEFLAGS" ]; then
            sed -i.backup 's/-lgcc_s/-lgcc_eh/g' "$workspace"/lib/pkgconfigsrt.pc
        fi

        build_done 'srt' "$g_ver"
    fi
        cnf_ops+=('--enable-libsrt')
fi

#####################
## HWaccel library ##
#####################

pre_check_ver 'khronosgroup/opencl-headers' '1' 'L'
if build 'opencl' "$g_ver"; then
    CFLAGS+=" -DLIBXML_STATIC_FOR_DLL -DNOLIBTOOL"
    download "$g_url" "opencl-$g_ver.tar.gz"
    execute cmake -B 'build' -DCMAKE_INSTALL_PREFIX="$workspace" -DBUILD_SHARED_LIBS='OFF'
    execute cmake --build build --target install
    build_done 'opencl' "$g_ver"
fi
cnf_ops+=('--enable-opencl')

# Vaapi doesn't work well with static links FFmpeg.
if [ -z "$LDEXEFLAGS" ]; then
    # If the libva development SDK is installed, enable vaapi.
    if library_exists 'libva'; then
        if build 'vaapi' '1'; then
            build_done 'vaapi' '1'
        fi
        cnf_ops+=('--enable-vaapi')
    fi
fi

pre_check_ver 'GPUOpen-LibrariesAndSDKs/AMF' '1' 'L'
if build 'amf' "$g_ver"; then
    download "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/archive/refs/tags/v$g_ver.tar.gz" "AMF-$g_ver.tar.gz"
    execute rm -fr "$workspace"/include/AMF
    execute mkdir -p "$workspace"/include/AMF
    execute cp -fr "$packages"/AMF-"$g_ver"/amf/public/include/* "$workspace"/include/AMF/
    build_done 'amf' "$g_ver"
fi
cnf_ops+=('--enable-amf')

if which 'nvcc' &>/dev/null; then
    pre_check_ver 'FFmpeg/nv-codec-headers' '1' 'L'
    if build 'nv-codec' "$g_ver"; then
        download "$g_url" "nv-codec-$g_ver.tar.gz"
        execute make PREFIX="$workspace" "-j$cpu_threads"
        execute make install PREFIX="$workspace"
        build_done 'nv-codec' "$g_ver"
    fi

    CFLAGS+=" -I/usr/local/cuda-12/targets/x86_64-linux/include -I/usr/local/cuda-12/include -I$workspace/usr/include -I$packages/nv-codec-n12.0.16.0/include"
    export CFLAGS
    LDFLAGS+=" -L/usr/local/cuda-12/targets/x86_64-linux/lib -L/usr/local/cuda-12/lib64"
    export LDFLAGS
    LDPATH+=' -lcudart'
    export LDPATH

    cnf_ops+=('--enable-cuda-nvcc' '--enable-cuvid' '--enable-cuda-llvm')

    if [ -z "$LDEXEFLAGS" ]; then
        cnf_ops+=('--enable-libnpp')
    fi

    gpu_arch_fn

    # https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
    cnf_ops+=("--nvccflags=-gencode arch=$gpu_arch")
fi

##
## BUILD FFMPEG
##

# CLONE FFMPEG FROM THE LATEST GIT RELEASE
if build 'FFmpeg' 'git'; then
    download_git 'https://github.com/FFmpeg/FFmpeg.git' 'FFmpeg-git'
    ./configure \
            "${cnf_ops[@]}" \
            --prefix="$workspace" \
            --arch="$(uname -m)" \
            --cpu="$cpu_cores" \
            --disable-debug \
            --disable-doc \
            --disable-shared \
            --enable-ffnvcodec \
            --enable-pthreads \
            --enable-small \
            --enable-static \
            --enable-version3 \
            --extra-cflags="$CFLAGS" \
            --extra-ldexeflags="$LDEXEFLAGS" \
            --extra-ldflags="$LDFLAGS" \
            --extra-libs="$EXTRALIBS" \
            --pkg-config-flags='--static'
    execute make "-j$cpu_threads"
    execute make install
fi

# PROMPT THE USER TO INSTALL THE FFMPEG BINARIES SYSTEM-WIDE
ffmpeg_install_choice

# CHECK THAT FILES WERE COPIED TO THE INSTALL DIRECTORY
ffmpeg_install_check

# DISPLAY FFMPEG'S VERSION
ff_ver_fn

# PROMPT THE USER TO CLEAN UP THE BUILD FILES
cleanup_fn

# DISPLAY A MESSAGE AT THE SCRIPT'S END
exit_fn

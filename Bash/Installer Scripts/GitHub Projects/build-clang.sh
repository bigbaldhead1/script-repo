#!/usr/bin/env bash

# Script to build LLVM Clang-18 with GOLD enabled
# Updated: 04.04.24
# Script version: 2.0
# Added multiple script arguments including the ability to set the version of Clang to install.

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Bind variables
cleanup="false"
custom_version=""

# Set PATH to include ccache directory
export PATH="/usr/lib/ccache:$PATH"

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "For help or to report a bug, create an issue at: https://github.com/slyfox1186/script-repo/issues"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

check_root() {
    if [[ "$EUID" -eq 0 ]]; then
        fail "You must not run this script as root or with sudo."
    fi
}

install_required_packages() {
    local pkgs=(
        autoconf autoconf-archive automake autopoint binutils binutils-dev
        build-essential ccache cmake curl doxygen jq libc6-dev libedit-dev
        librust-atomic-dev libtool libxml2-dev libzstd-dev m4 ninja-build
        zlib1g-dev
    )

    local missing_packages=()
    for pkg in ${pkgs[@]}; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            missing_packages+=("$pkg")
        fi
    done

    if [[ "${#missing_packages[@]}" -gt 0 ]]; then
        sudo apt-get update
        sudo apt-get install "${missing_packages[@]}"
    else
        log "All required packages are already installed."
        echo
    fi
}

set_highest_clang_version() {
    local available_versions=($(apt-cache search --names-only '^clang-[0-9]+$' | cut -d' ' -f1 | sort -rV))
    if [[ ${#available_versions[@]} -eq 0 ]]; then
        fail "No clang versions found in the package manager."
    fi

    local highest_version=${available_versions[0]}
    if ! dpkg-query -W -f='${Status}' "$highest_version" 2>/dev/null | grep -q "ok installed"; then
        log "Installing $highest_version..."
        sudo apt-get -y install "$highest_version"
    fi

    CC="${highest_version}"
    CXX="clang++-${highest_version#clang-}"
}

get_llvm_release_version() {
    if [[ -n "$custom_version" ]]; then
        llvm_version="$custom_version"
    else
        llvm_version=$(curl -fsS https://github.com/llvm/llvm-project/tags/ | grep -oP 'llvmorg-[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        llvm_version="${llvm_version#llvmorg-}"
    fi
}

set_compiler_flags() {
    CFLAGS="-O2 -fPIE -mtune=native -DNDEBUG -fstack-protector-strong"
    CFLAGS+=" -D_FORTIFY_SOURCE=2 -Wno-unused-parameter"
    CXXFLAGS="$CFLAGS"
    LDFLAGS="-Wl,-rpath,$install_prefix/lib -Wl,--as-needed"
    export CC CXX CFLAGS CXXFLAGS LDFLAGS
}

build_llvm_clang() {
    local llvm_tar_url="https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-$llvm_version.tar.gz"

    local llvm_tar_filename="$cwd/llvmorg-$llvm_version.tar.gz"

    if [[ -f "$llvm_tar_filename" ]]; then
        log "The LLVM source file $llvm_tar_filename is already downloaded."
    else
        log "Downloading LLVM source from $llvm_tar_url..."
        wget --show-progress -cqO "$llvm_tar_filename" "$llvm_tar_url"
        log "Download completed"
        echo
    fi

    log "Extracting LLVM source to $workspace..."
    tar -zxf "$llvm_tar_filename" -C "$workspace" --strip-components 1
    log "LLVM source code extracted to $workspace"
    echo

    local system_triplet=$(curl -fsSL "https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess" | bash)

    cd "$workspace" || fail "Failed to change directory to $workspace"

    log "Configuring Clang with CMake"
    echo

    cmake -S llvm -B build \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_COMPILER="$CXX" \
          -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
          -DCMAKE_C_COMPILER="$CC" \
          -DCMAKE_C_FLAGS="$CFLAGS" \
          -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
          -DCMAKE_INSTALL_PREFIX="$install_prefix" \
          -DCUDA_TOOLKIT_ROOT_DIR="/usr/local/cuda" \
          -DLLVM_BUILD_DOCS=OFF \
          -DLLVM_BUILD_EXAMPLES=OFF \
          -DLLVM_BUILD_TESTS=OFF \
          -DLLVM_BUILD_TOOLS=ON \
          -DLLVM_CCACHE_BUILD=ON \
          -DLLVM_ENABLE_ASSERTIONS=OFF \
          -DLLVM_ENABLE_LTO=OFF \
          -DLLVM_ENABLE_PIC=ON \
          -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;openmp" \
          -DLLVM_ENABLE_RTTI=OFF \
          -DLLVM_ENABLE_ZLIB=ON \
          -DLLVM_ENABLE_ZSTD=ON \
          -DLLVM_INCLUDE_EXAMPLES=OFF \
          -DLLVM_INCLUDE_EXAMPLES=OFF \
          -DLLVM_INCLUDE_RUNTIMES=ON \
          -DLLVM_INCLUDE_TESTS=ON \
          -DLLVM_INCLUDE_TOOLS=ON \
          -DLLVM_NATIVE_ARCH=$(uname -m) \
          -DLLVM_OPTIMIZED_TABLEGEN=ON \
          -DLLVM_USE_LINKER=lld \
          -DLLVM_DEFAULT_TARGET_TRIPLE="$system_triplet" \
          -G Ninja -Wno-dev
    echo
    log "Building Clang with Ninja"
    ninja "-j$(nproc --all)" -C build || fail "Failed to execute ninja -j$(nproc --all)"
    echo
    log "Installing Clang with Ninja"
    sudo ninja -C build install || fail "Failed to execute sudo ninja -C build install"
}

create_symlinks() {
    local llvm_version_trim="${llvm_version%%.*}"
    local versioned_clang="clang-$llvm_version_trim"
    local versioned_clangpp="clang++-$llvm_version_trim"

    local tools=(
        clang-$llvm_version_trim clang++-$llvm_version_trim clang-format
        clang-tidy clangd llvm-ar llvm-nm llvm-objdump llvm-dis llc lli opt
    )

    for tool in ${tools[@]}; do
        if [[ "$tool" == "clang++-$llvm_version_trim" ]]; then
            sudo ln -sf "$install_prefix/bin/clang++" "/usr/local/bin/$tool"
        else
            sudo ln -sf "$install_prefix/bin/$tool" "/usr/local/bin/$tool"
            local non_versioned_tool="${tool%-*}"
            if [[ ! "$tool" == "$non_versioned_tool" ]]; then
                sudo ln -sf "$install_prefix/bin/$tool" "/usr/local/bin/$non_versioned_tool"
            fi
        fi
    done
}

cleanup_build_files() {
    rm -fr "$cwd"
}

list_llvm_versions() {
    echo "Fetching the list of available LLVM versions..."
    echo
    curl -fsS "https://api.github.com/repos/llvm/llvm-project/tags" |
        jq -r '.[].name' | grep -Eo 'llvmorg-[0-9]+\.[0-9]+\.[0-9]+' |
        sed 's/llvmorg-//' | sort -ruV
    exit 0
}

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Display this help message"
    echo "  -c, --cleanup       Remove build files after installation"
    echo "  -v, --version <ver> Specify a custom version of Clang to download and build"
    echo "  -l, --list          List available LLVM versions"
    echo
    echo "Description:"
    echo "  This script builds LLVM Clang with GOLD enabled from source code."
    echo "  It downloads the source code, installs required dependencies, and"
    echo "  compiles the program with optimized settings."
    echo
    echo "Examples:"
    echo "  $0                     # Build the latest LLVM Clang with default settings"
    echo "  $0 -c                  # Build the latest LLVM Clang and clean up the build files"
    echo "  $0 -v 17.0.6           # Build LLVM Clang version 17.0.6"
    echo "  $0 -c -v 17.0.6        # Build LLVM Clang version 17.0.6 and clean up the build files"
    echo "  $0 -l                  # List available LLVM versions"
    echo
    exit 0
}

main() {
    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_help
                ;;
            -c|--cleanup)
                cleanup=true
                ;;
            -v|--version)
                if [[ -n "$2" ]]; then
                    custom_version="$2"
                    shift
                else
                    warn "Version argument requires a value"
                    display_help
                fi
                ;;
            -l|--list)
                list_llvm_versions
                ;;
            *)
                warn "Invalid argument: $1"
                display_help
                ;;
        esac
        shift
    done

    cwd="$PWD/llvm-build-script"
    workspace="$cwd/workspace"

    [[ -d "$workspace" ]] && sudo rm -fr "$workspace"
    mkdir -p "$workspace/build"

    check_root
    install_required_packages
    set_highest_clang_version
    get_llvm_release_version

    install_prefix="/usr/local/llvm-$llvm_version"

    set_compiler_flags
    build_llvm_clang
    create_symlinks

    [[ "$cleanup" == "true" ]] && cleanup_build_files

    echo
    log "The script has completed"
    log "Make sure to star this repository to show your support:"
    log "https://github.com/slyfox1186/script-repo"
}

main "$@"

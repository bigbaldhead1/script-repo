#!/usr/bin/env bash


if [ "$EUID" -eq 0 ]; then
    echo "You must run this script without root or sudo."
    exit 1
fi

count=0

cwd="$PWD/build-gnu-safer-scripts"

[[ -d "$cwd" ]] && sudo rm -fr "$cwd"
mkdir -p "$cwd/completed"

exit_fn() {
    echo
    echo "Make sure to star this repository to show your support!"
    echo "https://github.com/slyfox1186/script-repo"
    exit 0
}

fail() {
    echo
    echo "$1"
    echo "To report a bug create an issue at: https://github.com/slyfox1186/script-repo/issues"
    exit 1
}

pkgs=(
    asciidoc autogen autoconf autoconf-archive automake binutils bison
    build-essential bzip2 ccache cmake curl libc6-dev libintl-perl
    libpth-dev libtool libtool-bin lzip lzma-dev m4 meson nasm ninja-build
    texinfo xmlto yasm wget zlib1g-dev
)

for pkg in "${pkgs[@]}"; do
    missing_pkg="$(sudo dpkg -l | grep -o "$pkg")"

    if [ -z "$missing_pkg" ]; then
        missing_pkgs+="$pkg "
    fi
done

if [[ -n "$missing_pkgs" ]]; then
    sudo apt-get install $missing_pkgs
fi

sudo bash -c 'bash <(curl -fsSL https://ld.optimizethis.net)'

case $(uname -m) in
    x86_64)                     arch_ver="pkg-config" ;;
    aarch64*|armv8*|arm|armv7*) arch_ver="pkg-config-arm" ;;
    *)                          fail "Unrecognized architecture: $(uname -m)" ;;
esac

cd "$cwd" || exit 1

scripts=(
    "$arch_ver" "coreutils.sh" "m4" "autoconf-2.71" "autoconf-archive" "libtool" "bash"
    "make" "sed" "tar" "gawk" "grep" "nano" "parallel.sh" "get"
)

for script in "${scripts[@]}"; do
    ((count++))
    wget --show-progress -t 2 -cq "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/GNU%20Software/build-$script"
    mv "build-$script" "$count-build-$script.sh" 2>/dev/null
done

for file in $(find ./ -maxdepth 1 -type f | sort -V | sed 's/\.\///g'); do
    if echo "1" | sudo bash "$file"; then
        sudo mv "$file" "$cwd/completed"
    else
        if [ ! -d "$cwd/failed" ]; then
            mkdir -p "$cwd/failed"
        fi
        sudo mv "$file" "$cwd/failed"
    fi
done

if [ -d "$cwd/failed" ]; then
    echo "One of the scripts failed to build successfully."
    echo
    echo "You can find the failed script at: $cwd/failed"
    exit_fn
fi

sudo rm -fr "$cwd"

exit_fn

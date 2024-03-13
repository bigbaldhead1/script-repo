RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color
export RED GREEN YELLOW BLUE NC

## WHEN LAUNCHING CERTAIN PROGRAMS FROM THE TERMINAL, SUPPRESS ANY WARNING MESSAGES ##
gedit() { "$(type -P gedit)" "$@" &>/dev/null; }
geds() { sudo -Hu root "$(type -P gedit)" "$@" &>/dev/null; }
gnome-text-editor() { "$(type -P gnome-text-editor)" "$@" &>/dev/null; }
gnome-text-editors() { sudo -Hu root "$(type -P gnome-text-editor)" "$@" &>/dev/null; }

## GET THE OS AND ARCH OF THE ACTIVE COMPUTER ##
this_pc() {
    . /etc/os-release
    local OS="$NAME"
    local VER="$VERSION_ID"

    clear
    printf "%s\n%s\n\\n" \
        "Operating System: $OS" \
        "Specific Version: $VER"
}

## FIND COMMANDS ##
ffind() {
    local fname="$1"
    local ftype="$2"
    local fpath="$3"
    local find_cmd

    # Check if any argument is passed
    if [[ "$#" -eq 0 ]]; then
        read -p "Enter the name to search for: " fname
        read -p "Enter a type of FILE (d|f|blank for any): " ftype
        read -p "Enter the starting path (blank for current directory): " fpath
    fi

    # Default to the current directory if fpath is empty
    fpath=${fpath:-.}

    # Construct the find command based on the input
    find_cmd="find \"$fpath\" -iname \"$fname\""
    if [[ -n "$ftype" ]]; then
        if [[ "$ftype" == "d" || "$ftype" == "f" ]]; then
            find_cmd="$find_cmd -type $ftype"
        else
            echo "Invalid FILE type. Please use "d" for directories or "f" for files."
            return 1
        fi
    fi

    # Execute the command
    eval "$find_cmd"
}

## UNCOMPRESS FILES ##
untar() {
    local archive

    for archive in *.*; do
        local ext="${archive##*.}"

        [[ ! -d "$PWD"/"${archive%%.*}" ]] && mkdir -p "$PWD/${archive%%.*}"

        unset flag
        case "$ext" in
            7z|zip) 7z x -o./"${archive%%.*}" ./"$archive";;
            bz2)    flag="jxf";;
            gz|tgz) flag="zxf";;
            xz|lz)  flag="xf";;
        esac

        [[ -n "$flag" ]] && tar "$flag" ./"$archive" -C ./"${archive%%.*}" --strip-components 1
    done
}

## CREATE FILES ##
mf() {
    local file

    if [[ -z "$1" ]]; then
        read -p "Enter FILE name: " file
        [[ ! -f "$file" ]] && touch "$file"
        chmod 744 "$i"
    else
        [[ ! -f "$1" ]] && touch "$1"
        chmod 744 "$1"
    fi

    clear; ls -1AhFv --color --group-directories-first
}

mdir() {
    local dir

    if [[ -z "$1" ]]; then
        read -p "Enter directory name: " dir
        mkdir -p  "$PWD/$dir"
        cd "$PWD/$dir" || exit 1
    else
        mkdir -p "$1"
        cd "$PWD/$1" || exit 1
    fi

    clear; ls -1AhFv --color --group-directories-first
}

## AWK COMMANDS ##

# Removed all duplicate lines: outputs to terminal
rmd() {
    awk '!seen[[${0}]]++' "$1"
}

# Remove consecutive duplicate lines: outputs to terminal
rmdc() {
    awk 'f!=${0}&&f=${0}' "$1"
}

# Remove all duplicate lines and removes trailing spaces before comparing: replaces the file
rmdf() {
    perl -i -lne "s/\s*$//; print if ! $x{$_}++" "$1"
    gnome-text-editor "$1"
}

## FILE COMMANDS ##

# Copy file
cpf() {
    [[ ! -d "$HOME/tmp" ]] && mkdir -p "$HOME/tmp"
    cp "$1" "$HOME/tmp/$1"
    chown -R "$USER":"$USER" "$HOME/tmp/$1"
    chmod -R 744 "$HOME/tmp/$1"
    clear; ls -1AhFv --color --group-directories-first
}

# MOVE file
mvf() {
    [[ ! -d "$HOME/tmp" ]] && mkdir -p "$HOME/tmp"
    mv "$1" "$HOME/tmp/$1"
    chown -R "$USER":"$USER" "$HOME/tmp/$1"
    chmod -R 744 "$HOME/tmp/$1"
    clear; ls -1AhFv --color --group-directories-first
}

## APT COMMANDS ##

# Download an APT package + all its dependencies in one go

dl_apt() {
    wget -cq "$(apt --print-uris -qq --reinstall install $1 2>/dev/null | cut -d""\""" -f2)"
    clear; ls -1AhFv --color --group-directories-first
}

# Clean OS
clean() {
    sudo apt -y autoremove
    sudo apt clean
    sudo apt autoclean
    sudo apt -y purge
}

# Update OS
update() {
    sudo apt update
    sudo apt -y full-upgrade
}

# Fix broken APT packages
fix() {
    [[ -f /tmp/apt.lock ]] && sudo rm /tmp/apt.lock
    sudo dpkg --configure -a
    sudo apt --fix-broken install
    sudo apt -f -y install
    sudo apt -y autoremove
    sudo apt clean
    sudo apt autoclean
}

list() {
    local search_cache

    if [[ -n "$1" ]]; then
        sudo apt list "*$1*" 2>/dev/null | awk -F"/" '{print $1}'
    else
        read -p "Enter the string to search: " search_cache
        echo
        sudo apt list "*$1*" 2>/dev/null | awk -F"/" '{print $1}'
    fi
}

listd() {
    local search_cache
    if [[ -n "$1" ]]; then
        sudo apt list -- "*$1*"-dev 2>/dev/null | awk -F"/" '{print $1}'
    else
        read -p "Enter the string to search: " search_cache
        echo
        sudo apt list -- "*$1*"-dev 2>/dev/null | awk -F"/" '{print $1}'
    fi
}

# Use sudo APT to search for all apt packages by passing a name to the function
apts() {
    local input
    if [[ -n "$1" ]]; then
        sudo apt search "$1 ~i" -F "%p"
    else
        read -p "Enter the string to search: " input
        clear
        sudo apt search "$input ~i" -F "%p"
    fi
}

# Use APT cache to search for all apt packages by passing a name to the function
csearch() {
    local cache

    if [[ -n "$1" ]]; then
        apt-cache search --names-only "${1}.*" | awk '{print $1}'
    else
        read -p "Enter the string to search: " cache
        echo
        apt-cache search --names-only "${cache}.*" | awk '{print $1}'
    fi
}

# Fix missing gpnu keys used to update packages
fix_key() {
    local FILE url
    clear

    if [[ -z "$1" ]] && [[ -z "$2" ]]; then
        read -p "Enter the FILE name to store in /etc/apt/trusted.gpg.d: " file
        read -p "Enter the gpg key url: " url
        clear
    else
        file="$1"
        url="$2"
    fi

    curl -fsS# "$url" | gpg --dearmor | sudo tee "/etc/apt/trusted.gpg.d/$file"

    if curl -fsS# "$url" | gpg --dearmor | sudo tee "/etc/apt/trusted.gpg.d/$file"; then
        echo "The key was successfully added!"
    else
        echo "The key FAILED to add!"
    fi
}

# TAKE OWNERSHIP COMMAND #

toa() {
    clear
    sudo chown -R "$USER":"$USER" "$PWD"
    sudo chmod -R 744 "$PWD"
    clear; ls -1AvhF --color --group-directories-first
}

tod() {
    local directory
    clear

    if [[ -z "$1" ]]; then
        read -p "Enter the folder name/path: " directory
    else
        directory="$1"
    fi

    sudo chown -R "$USER":"$USER" "$directory"
    sudo chmod -R 744 "$directory"

    clear; ls -1AvhF --color --group-directories-first
}

tome() {
    # Check if a filename is provided as an argument
    if [[ $# -ne 1 ]]; then
        echo "Usage: change_ownership_and_permissions <file>"
        return 1
    fi

    # Check if the FILE exists
    if [[ ! -f "$1" ]]; then
        echo "Error: File "$1" does not exist."
        return 1
    fi

    # Change ownership of the FILE to the current user
    user=$(whoami)
    sudo chown "$user" "$1"

    # Verify if the ownership has been changed successfully
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to change ownership of "$1"."
        return 1
    fi

    # Change permissions to chmod 777
    sudo chmod 777 "$1"

    # Verify if the permissions have been changed successfully
    if [[ $? -eq 0 ]]; then
        echo "Ownership and permissions of "$1" have been changed to $user and chmod 777."
    else
        echo "Error: Failed to change permissions of "$1"."
        return 1
    fi
}

# DPKG COMMANDS #

## Show all installed packages
showpkgs() {
    dpkg --get-selections | grep -v deinstall > "$HOME"/tmp/packages.list
    gnome-text-editor "$HOME"/tmp/packages.list
}

# Pipe all development packages names to file
getdev() {
    apt-cache search dev | grep "\-dev" | cut -d " " -f1 | sort > "dev-packages.list"
    gnome-text-editor "dev-packages.list"
}

## SSH-KEYGEN ##

# Create a new private and public SSH key pair
new_key() {
    local bits comment name pass type
    clear

    printf "%s\n\\n" "Encryption type: [[ rsa | dsa | ecdsa ]]"
    read -p "Your choice: " type
    clear

    printf "%s\n%s\n\\n" \
        "[[i]] Choose the key bit size" \
        "[[i]] Values encased in "()" are recommended"

    if [[ "$type" == "rsa" ]]; then
        printf "%s\n\\n" "[[i]] rsa: [[ 512 | 1024 | (2048) | 4096 ]]"
    elif [[ "$type" == "dsa" ]]; then
        printf "%s\n\\n" "[[i]] dsa: [[ (1024) | 2048 ]]"
    elif [[ "$type" == "ecdsa" ]]; then
        printf "%s\n\\n" "[[i]] ecdsa: [[ (256) | 384 | 521 ]]"
    fi

    read -p "Your choice: " bits
    clear

    printf "%s\n%s\n\\n" \
        "[[i]] Choose a password" \
        "[[i]] For no password just press enter"
    read -p "Your choice: " pass
    clear

    printf "%s\n\\n" "[[i]] For no comment just press enter"
    read -p "Your choice: " comment
    clear

    printf "%s\n\\n" "[[i]] Enter the ssh key name"
    read -p "Your choice: " name
    clear

    printf "%s\n%s\n%s\n%s\n%s\n\\n" \
        "[[i]] Your choices" \
        "[[i]] Type: $type" \
        "[[i]] bits: $bits" \
        "[[i]] Password: $pass" \
        "[[i]] comment: $comment" \
        "[[i]] Key name: $name"
    read -p "Press enter to continue or ^c to exit"
    clear

    ssh-keygen -q -b "$bits" -t "$type" -N "$pass" -C "$comment" -f "$name"

    chmod 600 "$PWD/$name"
    chmod 644 "$PWD/${name}.pub"
    clear

    printf "%s\n\\n" "File: $PWD/$name"
    cat "$PWD/$name"

    printf "\n%s\n\\n" "File: $PWD/${name}.pub"
    cat "$PWD/${name}.pub"
    echo
}

# Export the public SSH key stored inside a private SSH key
keytopub() {
    local opub okey
    clear
    ls -1AhFv --color --group-directories-first

    printf "%s\n\\n" "Enter the full paths for each file"
    read -p "Private key: " okey
    read -p "Public key: " opub
    clear
    if [[ -f "$okey" ]]; then
        chmod 600 "$okey"
    else
        printf "%s\n\\n" "Warning: FILE missing = $okey"
        read -p "Press Enter to exit."
        exit 1
    fi
    ssh-keygen -b "4096" -y -f "$okey" > "$opub"
    chmod 644 "$opub"
    cp "$opub" "$HOME"/.ssh/authorized_keys
    chmod 600 "$HOME"/.ssh/authorized_keys
    unset "$okey"
    unset "$opub"
}

# Install ColorDiff package
cdiff() { clear; colordiff "$1" "$2"; }

# gzip
gzip() { clear; gzip -d "$@"; }

# get system time
gettime() { clear; date +%r | cut -d " " -f1-2 | grep -E "^.*$"; }

## SOURCE FILES ##
sbrc() {
    . "$HOME/.bashrc" && printf "%s\n\\n" "The command was a success!" || printf "%s\n\\n" "The command failed!"
    echo; ls -1AhFv --color --group-directories-first
}

spro() {
    . "$HOME/.profile" && printf "%s\n\\n" "The command was a success!" || printf "%s\n\\n" "The command failed!"
    echo; ls -1AhFv --color --group-directories-first
}

## ARIA2 COMMANDS ##

# Aria2 daemon in the background
aria2_on() {
    if aria2c --conf-path="$HOME/.aria2/aria2.conf"; then
        echo
        echo "Command Executed Successfully"
    else
        echo
        echo "Command Failed"
    fi
}

# Stop aria2 daemon
aria2_off() { clear; killall aria2c; }

myip() {
    echo "LAN: $(ip route get 1.2.3.4 | awk '{print $7}')"
    echo "WAN: $(curl -fsS "https://checkip.amazonaws.com")"
}

# WGET command
mywget() {
    local outfile url
    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        read -p "Please enter the output file name: " outfile
        read -p "Please enter the URL: " url
        echo
        wget --out-file="$outfile" "$url"
    else
        wget --out-file="$1" "$2"
    fi
}

# RM COMMANDS ##

# Remove directory
rmd() {
    local dir

    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        read -p "Please enter the directory name to remove: " dir
        sudo rm -r "$dir"
    else
        sudo rm -r "$1"
    fi
}

# Remove file
rmf() {
    local file

    if [[ -z "$1" ]]; then
        read -p "Please enter the file name to remove: " file
        sudo rm "$file"
    else
        sudo rm "$1"
    fi
}

## IMAGEMAGICK ##
function imow() {
    local file_path="/usr/local/bin/imow.sh"
    if [[ ! -f "$file_path" ]]; then
        local dir="$(mktemp -d)"
        cd "$dir" || echo "Failed to cd into the tmp directory: $dir"; return 1
        curl -Lso imow.sh "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/ImageMagick/scripts/optimize-jpg.sh"
        sudo mv imow.sh "$file_path"
        sudo rm -fr "$dir"
        sudo chown "$USER":"$USER"
        sudo chmod 777 "$file_path"
    fi
    clear
    if ! bash "$file_path" --dir "$PWD" --overwrite; then
        echo "Failed to execute: $file_path --dir $PWD --overwrite"
        return 1
    fi
}

# Downsample image to 50% of the original dimensions using sharper settings
im50() {
    local pic

    for pic in *.jpg; do
        convert "$pic" -monitor -colorspace sRGB -filter LanczosRadius -distort Resize 50% -colorspace sRGB "${pic%.jpg}-50.jpg"
    done
}

## Show NVME temperature ##
nvme_temp() {
    if [[ -d "/dev/nvme0n1" ]]; then
        local n0=$(sudo nvme smart-log /dev/nvme0n1)
    fi
    if [[ -d "/dev/nvme1n1" ]]; then
        local n1=$(sudo nvme smart-log /dev/nvme0n1)
    fi
    if [[ -d "/dev/nvme2n1" ]]; then
        local n2=$(sudo nvme smart-log /dev/nvme0n1)
    fi
    echo "nvme0n1: $n0"
    echo
    echo "nnvme1n1: $n1"
    echo
    echo "nnvme2n1: $n2"
}

## Refresh thumbnail cache
rftn() {
    sudo rm -fr "$HOME/.cache/thumbnails/"*
    sudo file "$HOME/.cache/thumbnails"
}

## FFMPEG COMMANDS ##

cuda_purge() {
    local choice

    echo "Do you want to completely remove the cuda-sdk-toolkit?"
    echo "WARNING: Do not reboot your PC without reinstalling the nvidia-driver first!"
    echo "[[1]] Yes"
    echo "[[2]] Exit"
    echo
    read -p "Your choices are (1 or 2): " choice
    clear

    if [[ "$choice" -eq 1 ]]; then
        echo "Purging the CUDA-SDK-Toolkit from your PC"
        echo "================================================"
        echo
        sudo sudo apt -y --purge remove "*cublas*" "cuda*" "nsight*"
        sudo sudo apt -y autoremove
        sudo sudo apt update
    else
        return 0
    fi
}

ffdl() {
    clear
    curl -m 10 -Lso "ff.sh" "https://ffdl.optimizethis.net"
    bash "ff.sh"
    sudo rm "ff.sh"
    clear; ls -1AhFv --color --group-directories-first
}

ffs() { curl -m 10 -Lso "ff" "https://raw.githubusercontent.com/slyfox1186/ffmpeg-build-script/main/build-ffmpeg"; }

dlfs() {
    local f
    clear

    wget --show-progress -qN - -i "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/SlyFox1186%20Scripts/favorite-installer-scripts.txt"

    scripts=(build-ffmpeg build-all-git-safer build-all-gnu-safer build-magick)

    for f in ${scripts[[@]]}
    do
        chown -R "$USER":"$USER" "$f"
        chmod -R 744 "$PWD" "$f"
        [[ "$f" == "build-all-git-safer" || "$f" == "build-all-gnu-safer" ]] && mv "$f" "${f%-safer}"
        [[ -n "favorite-installer-scripts.txt" ]] && sudo rm "favorite-installer-scripts.txt"
    done

    clear; ls -1AhFv --color --group-directories-first
}

## List large files by type
large_files() {
    local choice
    clear

    if [[ -z "$1" ]]; then
        printf "%s\n\\n" "Input the FILE extension to search for without a dot: "
        read -p "Enter your choice: " choice
        clear
    else
        choice="$1"
    fi

    sudo find "$PWD" -type f -name "*.$choice" -printf "%s %h\\n" | sort -ru -o "large-files.txt"

    if [[ -f "large-files.txt" ]]; then
        sudo gnome-text-editor "large-files.txt"
        sudo rm "large-files.txt"
    fi
}

## MediaInfo
mi() {
    local file

    if [[ -z "$1" ]]; then
        ls -1AhFv --color --group-directories-first
        echo
        read -p "Please enter the relative FILE path: " file
        echo
        mediainfo "$file"
    else
        mediainfo "$1"
    fi
}

## LIST PPA REPOS
list_ppa() {
    local entry

    for apt in $(find /etc/apt/ -type f -name \*.list); do
        grep -Po "(?<=^deb\s).*?(?=#|$)" "$apt" | while read entry; do
            local host=$(echo "$entry" | cut -d/ -f3)
            local user=$(echo "$entry" | cut -d/ -f4)
            local ppa=$(echo "$entry" | cut -d/ -f5)
            #echo sudo apt-add-repository ppa:$USER/${ppa}
            if [[ "ppa.launchpad.net" = "$host" ]]; then
                echo sudo apt-add-repository ppa:"$USER/$ppa"
            else
                echo sudo apt-add-repository \"deb "$entry"\"
            fi
        done
    done
}

# Create a tar.gz file with max compression settings
7z_gz() {
    local source output
    if [[ -n "$1" ]]; then
        if [[ -f "$1".tar.gz ]]; then
            sudo rm "$1".tar.gz
        fi
        7z a -ttar -so -an "$1" | 7z a -tgz -mx9 -mpass1 -si "$1".tar.gz
    else
        read -p "Please enter the source folder path: " source
        read -p "Please enter the destination archive path (w/o extension): " output
        echo
        if [[ -f "$output.tar.gz" ]]; then
            sudo rm "$output.tar.gz"
        fi
        7z a -ttar -so -an "$source" | 7z a -tgz -mx9 -mpass1 -si "$output.tar.gz"
    fi
}

# Create a tar.xz file with max compression settings using 7zip
7z_xz() {
    local source output
    if [[ -n "$1" ]]; then
        if [[ -f "$1.tar.xz" ]]; then
            sudo rm "$1.tar.xz"
        fi
        7z a -ttar -so -an "$1" | 7z a -txz -mx9 -si "$1.tar.xz"
    else
        read -p "Please enter the source folder path: " source
        read -p "Please enter the destination archive path (w/o extension): " output
        echo
        [[ -f "$output.tar.xz" ]] && sudo rm "$output.tar.xz"
        fi
        7z a -ttar -so -an "$source" | 7z a -txz -mx9 -si "$output.tar.xz"
    fi
}

# Create a .7z file with max compression settings

7z_1() {
    local choice
    if [[ -d "$1" ]]; then
        local source_dir="$1"
        7z a -y -t7z -m0=lzma2 -mx1 "$source_dir.7z" ./"$source_dir"/*
    else
        read -p "Please enter the source folder path: " source_dir
        7z a -y -t7z -m0=lzma2 -mx1 "$source_dir.7z" ./"$source_dir"/*
    fi

    printf "\n%s\n\n%s\n%s\n\\n" \
        "Do you want to delete the original file?" \
        "[[1]] Yes" \
        "[[2]] No"
    read -p "Your choices are (1 or 2): " choice
    echo

    case "$choice" in
        1)  sudo rm -fr "$source_dir";;
        2)  ;;
        "") ;;
        *)  echo "Bad user input."
            return 1
            ;;
    esac
}

7z_5() {
    local choice
    if [[ -d "$1" ]]; then
        local source_dir="$1"
        7z a -y -t7z -m0=lzma2 -mx5 "$source_dir.7z" ./"$source_dir"/*
    else
        read -p "Please enter the source folder path: " source_dir
        7z a -y -t7z -m0=lzma2 -mx5 "$source_dir.7z" ./"$source_dir"/*
    fi

    printf "\n%s\n\n%s\n%s\n\\n" \
        "Do you want to delete the original file?" \
        "[[1]] Yes" \
        "[[2]] No"
    read -p "Your choices are (1 or 2): " choice
    echo

    case "$choice" in
        1)  sudo rm -fr "$source_dir";;
        2)  ;;
        "") ;;
        *)  echo "Bad user input."
            return 1
            ;;
    esac
}

7z_9() {
    if [[ -d "$1" ]]; then
        local source_dir="$1"
        7z a -y -t7z -m0=lzma2 -mx9 "$source_dir.7z" ./"$source_dir"/*
    else
        read -p "Please enter the source folder path: " source_dir
        7z a -y -t7z -m0=lzma2 -mx9 "$source_dir.7z" ./"$source_dir"/*
    fi

    printf "\n%s\n\n%s\n%s\n\\n" \
        "Do you want to delete the original file?" \
        "[[1]] Yes" \
        "[[2]] No"
    read -p "Your choices are (1 or 2): " choice
    echo

    case "$choice" in
        1)  sudo rm -fr "$source_dir";;
        2)  ;;
        "") ;;
        *)  echo "Bad user input."
            return 1
            ;;
    esac
}

## tar commands ##

tar_gz() {
    local source output
    if [[ -n "$1" ]]; then
        if [[ -f "$1".tar.gz ]]; then
            sudo rm "$1".tar.gz
        fi
        tar -cJf "$1".tar.gz "$1"
    else
        read -p "Please enter the source folder path: " source
        echo
        read -p "Please enter the destination archive path (w/o extension): " output
        echo
        [[ -f "$output.tar.gz" ]] && sudo rm "$output.tar.gz"
        tar -cJf "$output.tar.gz" "$source"
    fi
}

tar_bz2() {
    local source output
    if [[ -n "$1" ]]; then
        if [[ -f "$1".tar.bz2 ]]; then
            sudo rm "$1".tar.bz2
        fi
        tar -cvjf "$1".tar.bz2 "$1"
    else
        read -p "Please enter the source folder path: " source
        echo
        read -p "Please enter the destination archive path (w/o extension): " output
        echo
        [[ -f "$output".tar.bz2 ]] && sudo rm "$output".tar.bz2
        tar -cvjf "$output".tar.bz2 "$source"
    fi
}

tar_xz_1() {
    local source output
    if [[ -n "$1" ]]; then
        [[ -f "$1.tar.xz" ]] && sudo rm "$1.tar.xz"
        tar -cvJf - "$1" | xz -1 -c - > "$1.tar.xz"
    else
        read -p "Please enter the source folder path: " source
        read -p "Please enter the destination archive path (w/o extension): " output
        echo
        [[ -f "$output.tar.xz" ]] && sudo rm "$output.tar.xz"
        tar -cvJf - "$source" | xz -1 -c - > "$output.tar.xz"
    fi
}

tar_xz_5() {
    local source output
    if [[ -n "$1" ]]; then
        [[ -f "$1.tar.xz" ]] && sudo rm "$1.tar.xz"
        tar -cvJf - "$1" | xz -5 -c - > "$1.tar.xz"
    else
        read -p "Please enter the source folder path: " source
        echo
        read -p "Please enter the destination archive path (w/o extension): " output
        clear
        [[ -f "$output.tar.xz" ]] && sudo rm "$output.tar.xz"
        tar -cvJf - "$source" | xz -5 -c - > "$output.tar.xz"
    fi
}

tar_xz_9() {
    local source output
    if [[ -n "$1" ]]; then
        [[ -f "$1.tar.xz" ]] && sudo rm "$1.tar.xz"
        tar -cvJf - "$1" | xz -9 -c - > "$1.tar.xz"
    else
        read -p "Please enter the source folder path: " source
        echo
        read -p "Please enter the destination archive path (w/o extension): " output
        echo
        if [[ -f "$output.tar.xz" ]]; then
            sudo rm "$output.tar.xz"
        fi
        tar -cvJf - "$source" | xz -9 -c - > "$output.tar.xz"
    fi
}

## FFMPEG COMMANDS ##
ffr() {
    sudo bash "$1" --build --enable-gpl-and-non-free --latest
}

ffrv() {
    sudo bash -v "$1" --build --enable-gpl-and-non-free --latest
}

## Write caching ##
wcache() {
    local choice

    lsblk
    echo
    read -p "Enter the drive id to turn off write caching (/dev/sdX w/o /dev/): " choice

    sudo hdparm -W 0 /dev/"${choice}"
}

rmd() {
    local dir
    if [[ -z "$*" ]]; then
        clear; ls -1AvhF --color --group-directories-first
        echo
        read -p "Enter the directory path(s) to delete: " dir
     else
        dir="$*"
    fi
    sudo rm -fr "$dir"
    echo; ls -1AvhF --color --group-directories-first
}


rmf() {
    local files
    if [[ -z "$*" ]]; then
        clear; ls -1AvhF --color --group-directories-first
        echo
        read -p "Enter the FILE path(s) to delete: " files
     else
        files="$*"
    fi
    sudo rm "$files"
    echo; ls -1AvhF --color --group-directories-first
}

## LIST INSTALLED PACKAGES BY ORDER OF IMPORTANCE
list_pkgs() {
    dpkg-query -Wf '${Package;-40}${Priority}\n' | sort -b -k2,2 -k1,1
}

## FIX USER FOLDER PERMISSIONS up = user permissions
fix_up() {
    sudo find "$HOME/.gnupg" -type f -exec chmod 600 {} \;
    sudo find "$HOME/.gnupg" -type d -exec chmod 700 {} \;
    sudo find "$HOME/.ssh" -type d -exec chmod 700 {} \;
    sudo find "$HOME/.ssh/id_rsa.pub" -type f -exec chmod 644 {} \;
    sudo find "$HOME/.ssh/id_rsa" -type f -exec chmod 600 {} \;
}

## Count files in the directory
count_dir() {
    local keep_count
    keep_count=$(find . -maxdepth 1 -type f | wc -l)
    printf "%s %d\n\\n" "The total directory file count is (non-recursive):" "$keep_count"
}

count_dirr() {
    local keep_count
    clear
    keep_count=$(find . -type f | wc -l)
    printf "%s %d\n\\n" "The total directory file count is (recursive):" "$keep_count"
}

## TEST GCC & CLANG ##
test_gcc() {
    local choice
    local random_dir=$(mktemp -d)

    # CREATE A TEMPORARY C FILE TO RUN OUR TESTS AGAINST
    cat > "$random_dir/hello.c" <<'EOF'
#include <stdio.h>
int main(void)
{
   printf("Hello World!\\n");
   return 0;
}
EOF

    if [[ -n "$1" ]]; then
        "$1" -Q -v "$random_dir/hello.c"
    else
        read -p "Enter the GCC binary you wish to test (example: gcc-11): " choice
        echo
        "$choice" -Q -v "$random_dir/hello.c"
    fi
    sudo rm -fr "$random_dir"
}

test_clang() {
    local choice
    local random_dir=$(mktemp -d)

    # CREATE A TEMPORARY C FILE TO RUN OUR TESTS AGAINST
    cat > "$random_dir/hello.c" <<'EOF'
#include <stdio.h>
int main(void)
{
   printf("Hello World!\\n");
   return 0;
}
EOF

    if [[ -n "$1" ]]; then
        "$1" -Q -v "$random_dir/hello.c"
    else
        clear
        read -p "Enter the GCC binary you wish to test (example: gcc-11): " choice
        echo
        "$choice" -Q -v "$random_dir/hello.c"
    fi
    sudo rm -fr "$random_dir"
}

gcc_native() {
    echo "Checking GCC default target..."
    gcc -dumpmachine

    echo "Checking GCC version..."
    gcc --version

    echo "Inspecting GCC verbose output for -march=native..."
    # Create a temporary empty file
    local temp_source=$(mktemp /tmp/dummy_source.XXXXXX.c)
    trap 'rm -f "$temp_source"' EXIT

    # Using echo to create an empty file
    echo "" > "$temp_source"

    # Using GCC with -v to get verbose information, including the default march
    gcc -march=native -v -E "$temp_source" 2>&1 | grep -- '-march='
}

## UNINSTALL DEBIAN FILES ##
rm_deb() {
    local fname

    if [[ -n "$1" ]]; then
        sudo dpkg -r "$(dpkg -f \"$1\" Package)"
    else
        read -p "Please enter the Debian FILE name: " fname
        clear
        sudo dpkg -r "$(dpkg -f \"$fname\" Package)"
    fi
}

## KILLALL COMMANDS ##
tkapt() {
    local program
    local list=(apt apt-get aptitude dpkg)
    for program in ${list[[@]]}; do
        sudo killall -9 "$program" 2>/dev/null
    done
}

gc() {
    local url
    if [[ -n "$1" ]]; then
        nohup google-chrome "$1"
    else
        read -p "Enter a URL: " url
        nohup google-chrome "$url" 2>&1
    fi
}

kill_process() {
    local id pids
    local program="$1"

    if [[ -z "$program" ]]; then
        echo "Usage: kill_process NAME"
        return 1
    fi

    echo -e "Checking for running instances of: '$program'\\n"

    # Find all PIDs for the given process
    local pids=$(pgrep -f "$program")

    if [[ -z "$pids" ]]; then
        echo "No instances of "$program" are running."
        return 0
    fi

    echo "Found instances of '$program' with PIDs: $pids"
    echo "Attempting to kill all instances of: '$program'"

    for id in $pids; do
        echo "Killing PID $id..."
        sudo kill -9 "$id" || {
            echo "Failed to kill PID $id. Check your permissions."
            continue
        }
    done

    echo -e "\\nAll instances of '$program' were attempted to be killed."
}

## nohup commands
nh() {
    nohup "$1" &>/dev/null &
    echo; ls -1AvhF --color --group-directories-first
}

nhs() {
    nohup sudo "$1" &>/dev/null &
    echo; ls -1AvhF --color --group-directories-first
}

nhe() {
    nohup "$1" &>/dev/null &
    exit
    exit
}

nhse() {
    nohup sudo "$1" &>/dev/null &
    exit
    exit
}

## NAUTILUS COMMANDS
nopen() {
    nohup nautilus -w "$1" &>/dev/null &
    exit
}

tkan() {
    local parent_dir="$PWD"
    sudo killall -9 nautilus
    sleep 1
    nohup nautilus -w "$parent_dir" &>/dev/null &
    exit
}

## UPDATE ICON CACHE ##
icon pkgs
    pkgs=(gtk-update-icon-cache hicolor-icon-theme)
    for i in ${pkgs[[@]]}; do
        if ! sudo dpkg -l | grep "$icon"; then
            sudo apt -y install $icon
            echo
        fi
    done

    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor
}

## aria2c
adl() {
    # Check if two arguments are provided
    if [[ "$#" -eq 2 ]]; then
       local file="$1"
       local url="$2"
    else
        # If not two arguments, prompt for input
        read -p "Enter the filename and extension: " file
        read -p "Enter the URL: " url
    fi

    # Check for an existing file with the same name and prompt to overwrite
    if [[ -f "$file" ]]; then
        read -p "File $file exists. Overwrite? (y/n): " -n 1 -r
        echo
        if [[ "$REPLY" =~ ^[[Yy]]$ ]]; then
            rm -f "$file"
        else
            echo "Download canceled."
            return 1
        fi
    fi

    # Use aria2c to download the file with the given filename
    if aria2c --console-log-level=notice \
               -x32 \
               -j16 \
               --split=32 \
               --allow-overwrite=true \
               --allow-piece-length-change=true \
               --always-resume=true \
               --auto-file-renaming=false \
               --min-split-size=8M \
               --disk-cache=64M \
               --file-allocation=none \
               --no-file-allocation-limit=8M \
               --continue=true \
               --out="$filename" \
               "$url"
    then
           google_speech "Download completed." 2>/dev/null
    else
           google_speech "Download failed." 2>/dev/null
    fi
    echo; ls -1AvhF --color --group-directories-first
}

## GET FILE SIZES ##
big_files() {
    if [[ -n "$1" ]]; then
        local count="$1"
    else
        read -p "Enter how many files to list in the results: " count
        echo
    fi
    echo "$count largest files"
    echo
    sudo find "$PWD" -type f -exec du -Sh {} + | sort -hr | head -n"$count"
    echo
    echo "$count largest folders"
    echo
    sudo du -Bm "$PWD" 2>/dev/null | sort -hr | head -n"$count"
}

big_vids() {
    if [[ -n "$1" ]]; then
        local count="$1"
    else
        read -p "Enter the max number of results: " count
        echo
    fi
    echo "Listing the $count largest videos"
    echo
    sudo find "$PWD" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) -exec du -Sh {} + | grep -Ev "\(x265\)" | sort -hr | head -n"$count"
}

big_img() { clear; sudo find . -size +10M -type f -name "*.jpg" 2>/dev/null; }

jpgsize() {
    local random_dir size

    random_dir=$(mktemp -d)
    read -p "Enter the image size (units in MB): " size
    find . -size +"$size"M -type f -iname "*.jpg" > "$random_dir/img-sizes.txt"
    sed -i "s/^..//g" "$random_dir/img-sizes.txt"
    sed -i "s|^|$PWD\/|g" "$random_dir/img-sizes.txt"
    echo
    nohup gnome-text-editor "$random_dir/img-sizes.txt" &>/dev/null &
}

## SED COMMANDS ##
fsed() {
    echo "This command is for sed to act only on files"
    echo

    if [[ -z "$1" ]]; then
        read -p "Enter the original text: " otext
        read -p "Enter the replacement text: " rtext
        echo
    else
        otext="$1"
        rtext="$2"
    fi

     sudo sed -i "s/${otext}/${rtext}/g" $(find . -maxdepth 1 -type f)
}

## CMAKE commands
c_cmake() {
    local dir
    if ! sudo dpkg -l | grep -o cmake-curses-gui; then
        sudo apt -y install cmake-curses-gui
    fi
    echo

    if [[ -z "$1" ]]; then
        read -p "Enter the relative source directory: " dir
    else
        dir="$1"
    fi

    cmake $dir -B build -G Ninja -Wno-dev
    ccmake $dir
}

##########################
## SORT IMAGES BY WIDTH ##
##########################

jpgs() {
    sudo find . -type f -iname "*.jpg" -exec identify -format " $PWD/%f: %wx%h " {} > /tmp/img-sizes.txt \;
    cat /tmp/img-sizes.txt | sed 's/\s\//\n\//g' | sort -h
    sudo rm /tmp/img-sizes.txt
}

######################################
## DOWNLOAD IMPORTANT BUILD SCRIPTS ##
######################################

gitdl() {
    clear
    wget -cq "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/FFmpeg/build-ffmpeg"
    wget -cq "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/ImageMagick/build-magick"
    wget -cq "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/GNU%20Software/build-gcc"
    wget -cq "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/FFmpeg/repo.sh"
    sudo chmod -R build-gcc build-magick build-ffmpeg repo.sh -- *
    sudo chown -R "$USER":"$USER" build-gcc build-magick build-ffmpeg repo.sh
    clear
    ls -1AvhF --color --group-directories-first
}

# COUNT ITEMS IN THE CURRENT FOLDER W/O SUBDIRECTORIES INCLUDED
countf() {
    local folder_count
    clear
    folder_count=$(ls -1 | wc -l)
    printf "%s\\n" "There are ${folder_count} files in this folder"
}

## RECURSIVELY UNZIP ZIP FILES AND NAME THE OUTPUT FOLDER THE SAME NAME AS THE ZIP FILE
zipr() {
    clear
    sudo find . -type f -iname "*.zip" -exec sh -c "unzip -o -d "${0%.*}" "$0"" "{}" \;
    sudo find . -type f -iname "*.zip" -exec trash-put "{}" \;
}

###################################
## FFPROBE LIST IMAGE DIMENSIONS ##
###################################

ffp() {
    [[ -f 00-pic-sizes.txt ]] && sudo rm 00-pic-sizes.txt
    sudo find "$PWD" -type f -iname "*.jpg" -exec bash -c "identify -format '%wx%h' {}; echo {}" > 00-pic-sizes.txt \;
}

####################
## RSYNC COMMANDS ##
####################

rsr() {
    local destination source

    # you must add an extra folder that is a period "/./" between the full path to the source folder and the source folder itself
    # or rsync will copy the files to the destination directory and it will be the full path of the source folder instead of the source
    # folder and its subfiles only.

    echo "This rsync command will recursively copy the source folder to the chosen destination."
    echo "The original files will still be located in the source folder."
    echo "If you want to move the files (which deletes the originals then use the function 'rsrd'."
    echo "Please enter the full paths of the source and destination directories."
    echo 

    read -p "Enter the source path: " source
    read -p "Enter the destination path: " destination
    local modified_source=$(echo "$source" | sed 's:/[^/]*$::')"'/./'"$(echo "$source" | sed 's:.*/::')
    echo

    rsync -aqvR --acls --perms --mkpath --info=progress2 "$modified_source" "$destination"
}

rsrd() {
    local destination source

    # you must add an extra folder that is a period "/./" between the full path to the source folder and the source folder itself
    # or rsync will copy the files to the destination directory and it will be the full path of the souce folder instead of the source
    # folder and its subfiles only.

    echo "This rsync command will recursively copy the source folder to the chosen destination."
    echo "The original files will be DELETED after they have been copied to the destination."
    echo "If you want to move the files (which deletes the originals then use the function 'rsrd'."
    echo "Please enter the full paths of the source and destination directories."
    echo

    printf "%s\n\\n"
    read -p "Enter the source path: " source
    read -p "Enter the destination path: " destination
    local modified_source="$(echo "$source" | sed 's:/[^/]*$::')"'/./'"$(echo "$source" | sed 's:.*/::')"
    echo

    rsync -aqvR --acls --perms --mkpath --remove-source-files "$modified_source" "$destination"
}

## SHELLCHECK ##
sc() {
    local file files input_char line space

    if [[ -z "$*" ]]; then
        read -p "Input the FILE path to check: " files
        echo
    else
        files="$@"
    fi

    for file in ${files[[@]]}; do
        box_out_banner() {
            input_char=$(echo "$@" | wc -c)
            line=$(for i in $(seq 0 ${input_char}); do printf "-"; done)
            tput bold
            line="$(tput setaf 3)$line"
            space=${line//-/ }
            echo " $line"
            printf "|" ; echo -n "$space" ; printf "%s\\n" "|";
            printf "| " ;tput setaf 4; echo -n "$@"; tput setaf 3 ; printf "%s\\n" " |";
            printf "|" ; echo -n "$space" ; printf "%s\\n" "|";
            echo " $line"
            tput sgr 0
        }
        box_out_banner "Parsing: $file"
        shellcheck --color=always -x --severity=warning --source-path="$PATH:$HOME/tmp:/etc:/usr/local/lib64:/usr/local/lib:/usr/local64:/usr/lib:/lib64:/lib:/lib32" "$file"
        echo
    done
}

###############
## CLIPBOARD ##
###############

# COPY ANY TEXT. DOES NOT NEED TO BE IN QUOTES
# EXAMPLE: ct This is so cool
# OUTPUT WHEN PASTED: This is so cool
# USAGE: cp <file name here>

cc() {
    if [[ -z "$*" ]]; then
        echo
        echo "%s\n\n%s\n%s\n\\n"
        echo "The command syntax is shown below"
        echo "cc INPUT"
        echo "Example: cc $PWD"
        return 1
    else
        local pipe="$@"
    fi
    echo "$pipe" | xclip -i -rmlastnl -select clipboard
}

# COPY A FILE"S FULL PATH
# USAGE: cp <file name here>

cfp() {
    if [[ -z "$*" ]]; then
        clear
        printf "%s\n\n%s\n%s\n\\n" \
            "The command syntax is shown below" \
            "cfp INPUT" \
            "Example: cfp $PWD"
        return 1
    else
        local pipe="$@"
    fi

    readlink -fn "$pipe" | xclip -i -select clipboard
    clear
}

# COPY THE CONTENT OF A FILE
# USAGE: cf <file name here>

cfc() {
    clear

    if [[ -z "$1" ]]; then
        clear
        printf "%s\n\n%s\n%s\n\\n" \
            "The command syntax is shown below" \
            "cc INPUT" \
            "Example: cc $PWD"
        return 1
    else
        cat "$1" | xclip -i -rmlastnl -select clipboard
    fi
}

########################
## PKG-CONFIG COMMAND ##
########################

# SHOW THE PATHS PKG-CONFIG COMMAND SEARCHES BY DEFAULT
pkg-config-path() {
    clear
    pkg-config --variable pc_path pkg-config | tr ":" "\\n"
}

######################################
## SHOW BINARY RUNPATH IF IT EXISTS ##
######################################

show_rpath() {
    local find_rpath
    clear

    if [[ -z "$1" ]]; then
        read -p "Enter the full path to the binary/program: " find_rpath
    else
        find_rpath="$1"
    fi

    clear
    sudo chrpath -l "$(type -p ${find_rpath})"
}

######################################
## DOWNLOAD CLANG INSTALLER SCRIPTS ##
######################################

dl_clang() {
    clear
    if [[ ! -d "$HOME/tmp" ]]; then
        mkdir -p "$HOME/tmp"
    fi
    wget --show-progress -cqO "$HOME/tmp/build-clang-16" "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/GitHub%20Projects/build-clang-16"
    wget --show-progress -cqO "$HOME/tmp/build-clang-17" "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/GitHub%20Projects/build-clang-17"
    sudo chmod rwx "$HOME/tmp/build-clang-16" "$HOME/tmp/build-clang-17"
    sudo chown "$USER":"$USER" "$HOME/tmp/build-clang-16" "$HOME/tmp/build-clang-17"
    clear
    ls -1AvhF--color --group-directories-first
}

#################
## PYTHON3 PIP ##
#################

pip_up() {
    local list_pkgs pkg

    list_pkgs=$(pip list | awk '{print $1}')

    pip install --upgrade pip

    for pkg in ${list_pkgs[[@]]}
    do
        if [[ $pkg != wxPython ]]; then
            pip install --user --upgrade $pkg
        fi
        echo
    done
}

####################
## REGEX COMMANDS ##
####################

bvar() {
    local choice fext flag fname
    clear

    if [[ -z "$1" ]]; then
        read -p "Please enter the FILE path: " fname
        fname_tmp="$fname"
    else
        fname="$1"
        fname_tmp="$fname"
    fi

    fext="${fname#*.}"
    if [[ -n "$fext" ]]; then
        fname+=".txt"
        mv "${fname_tmp}" "$fname"
    fi

    cat < "$fname" | sed -e "s/\(\$\)\([[A-Za-z0-9\_]]*\)/\1{\2}/g" -e "s/\(\$\)\({}\)/\1/g" -e "s/\(\$\)\({}\)\({\)/\1\3/g"

    printf "%s\n\n%s\n%s\n\\n" \
        "Do you want to permanently change this file?" \
        "[[1]] Yes" \
        "[[2]] Exit"
    read -p "Your choices are ( 1 or 2): " choice
    clear
    case "${choice}" in
        1)
                sed -i -e "s/\(\$\)\([[A-Za-z0-9\_]]*\)/\1{\2}/g" -i -e "s/\(\$\)\({}\)/\1/g" -i -e "s/\(\$\)\({}\)\({\)/\1\3/g" "$fname"
                mv "$fname" "${fname_tmp}"
                clear
                cat < "${fname_tmp}"
                ;;
        2)
                mv "$fname" "${fname_tmp}"
                return 0
                ;;
        *)
                unset choice
                bvar "${fname_tmp}"
                ;;
    esac
}

###########################
## CHANGE HOSTNAME OF PC ##
###########################

chostname() {
    local name
    clear

    if [[ -z "$1" ]]; then
        read -p "Please enter the new hostname: " name
    else
        name="$1"
    fi

    sudo nmcli g hostname "$name"
    clear
    printf "%s\n\\n" "The new hostname is listed below."
    hostname
}

############
## DOCKER ##
############

drp() {
    local choice restart_policy
    clear

    printf "%s\n\n%s\n%s\n%s\n%s\n\\n" \
        "Change the Docker restart policy" \
        "[[1]] Restart Always" \
        "[[2]] Restart Unless Stopped " \
        "[[3]] On Failure" \
        "[[4]] No"
    read -p "Your choices are (1 to 4): " choice
    clear

    case "${choice}" in
        1)      restart_policy="always" ;;
        2)      restart_policy="unless-stopped" ;;
        3)      restart_policy="on-failure" ;;
        4)      restart_policy="no" ;;
        *)
                clear
                printf "%s\n\\n" "Bad user input. Please try again..."
                return 1
                ;;
    esac

    docker update --restart="${restart_policy}"
}

rm_curly() {
    local content FILE transform_string
    # FUNCTION TO TRANSFORM THE STRING
    transform_string()
    {
        content=$(cat "$1")
        echo "${content//\$\{/\$}" | sed "s/\}//g"
    }

    # LOOP OVER EACH ARGUMENT
    for FILE in "$@"
    do
        if [[ -f "$file" ]]; then
            # PERFORM THE TRANSFORMATION AND OVERWRITE THE FILE
            transform_string "$file" > "$file.tmp"
            mv "$file.tmp" "$file"
            echo "Modified file: $file"
        else
            echo "File not found: $file"
        fi
    done
}

#########################
## MOUNT NETWORK DRIVE ##
#########################

mnd() {
    clear

    # Define variables
    local drive_ip="192.168.2.2"
    local drive_name="Cloud"
    local mount_point="m"  # Mount point set to /m

    # Function to check if the drive is already mounted
    is_mounted() {
        sudo mountpoint -q "/$mount_point"
    }

    # Function to mount the drive
    mount_drive() {
        if is_mounted; then
            echo "Drive '$drive_name' is already mounted at $mount_point."
        else
            sudo mkdir -p "/$mount_point"
            sudo mount -t drvfs "\\\\$drive_ip\\$drive_name" "/$mount_point" && echo "Drive '$drive_name' mounted successfully at $mount_point."
        fi
    }

    # Function to unmount the drive
    unmount_drive() {
        if is_mounted; then
            sudo umount "/$mount_point" && echo "Drive '$drive_name' unmounted successfully from $mount_point."
        else
            echo "Drive '$drive_name' is not mounted."
        fi
    }

    # Main menu for user interaction
    echo "Select an option:"
    echo "1) Mount the network drive"
    echo "2) Unmount the network drive"
    read -p "Enter your choice (1/2): " user_choice

    case $user_choice in
        1) mount_drive ;;
        2) unmount_drive ;;
        *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
}

##################
## PORT NUMBERS ##
##################

check_port() {
    local port="$1"
    local -A pid_protocol_map
    local pid name protocol choice process_found=false

    if [ -z "$port" ]; then
        read -p 'Enter the port number: ' port < /dev/tty
    fi

    echo -e "\\nChecking for processes using port $port...\\n"

    # Collect information
    while IFS= read -r line; do
        pid=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | awk '{print $1}')
        protocol=$(echo "$line" | awk '{print $8}')

        if [ -n "$pid" ] && [ -n "$name" ]; then
            process_found=true
            # Ensure protocol is only listed once per process
            [[ "${pid_protocol_map[$pid,$name]}" != *"$protocol"* ]] && pid_protocol_map["$pid,$name"]+="$protocol "
        fi
    done < <(sudo lsof -i :"$port" -nP | grep -v "COMMAND")

    # Process information
    for key in "${!pid_protocol_map[@]}"; do
        IFS=',' read -r pid name <<< "$key"
        protocol=${pid_protocol_map[$key]}
        # Removing trailing space
        protocol="${protocol% }"

        # Display process and protocol information
        echo -e "Process: $name (PID: $pid) using ${protocol// /, }"

        if [[ $protocol == *"TCP"* && $protocol == *"UDP"* ]]; then
            echo -e "\\nBoth the TCP and UDP protocols are being used by the same process.\\n"
            read -p "Do you want to kill it? (yes/no): " choice < /dev/tty
        else
            read -p "Do you want to kill this process? (yes/no): " choice < /dev/tty
        fi

        case "$choice" in
            [Yy][Ee][Ss]|[Yy]|"")
                echo -e "\\nKilling process $pid...\\n"
                if sudo kill -9 "$pid" 2>/dev/null; then
                    echo -e "Process $pid killed successfully.\\n"
                else
                    echo -e "Failed to kill process $pid. It may have already exited or you lack the necessary permissions.\\n"
                fi
                ;;
            [Nn][Oo]|[Nn])
                echo -e "\\nProcess $pid not killed.\\n" ;;
            *)
                echo -e "\\nInvalid response. Exiting.\\n"
                return 1
                ;;
        esac
    done

    if [[ "$process_found" = "false" ]]; then
        echo -e "No process is using port $port.\\n"
    fi
}

dlu() {
    local domain_list=()

    if [[ -z "$1" ]]; then
        read -p "Enter the domain(s) to pass: " -a domain_list
    else
        domain_list=("$@")
    fi

    if [[ -f /usr/local/bin/domain_lookup.py ]]; then
        python3 /usr/local/bin/domain_lookup.py "${domain_list[@]}"
    else
        printf "\n%s\n\\n" "The Python script not found at /usr/local/bin/domain_lookup.py"
    fi
}

venv() {
    # Go into a folder containing source code and call venv to set up a python virtual environment.
    # Check if already activated
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo -e "\\n${YELLOW}Deactivating current virtual environment...${NC}\\n"
        deactivate
        return 0
    fi
    
    # Check if the venv directory exists
    if [[ -d "venv" ]]; then
        echo -e "\\n${YELLOW}Activating virtual environment...${NC}\\n"
        . venv/bin/activate
    else
        echo -e "\\n${YELLOW}Creating and activating virtual environment...${NC}\\n"
        python3 -m venv venv
        . venv/bin/activate
    fi
}

## SERVICES SELECTOR SCRIPT
sss() {
    local script="/usr/local/bin/services-selector.sh"
    [[ ! -f "$script" ]] && sudo wget -NO "$script" "https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Misc/services-selector.sh"
    sudo bash "$script"
}

#!/usr/bin/env bash

clear

printf "%s\n%s\n\n" \
    'Install ~/.bash_functions' \
    '================================='

#
# SET VARIABLES
#

file="${HOME}"/.bash_functions

#
# CREATE FUNCTIONS
#

script_fn()
{
cat > "$file" <<'EOF'
#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2001,SC2162,SC2317

export user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

######################################################################################
## WHEN LAUNCHING CERTAIN PROGRAMS FROM THE TERMINAL, SUPPRESS ANY WARNING MESSAGES ##
######################################################################################

gedit() { "$(type -P gedit)" "${@}" &>/dev/null; }
geds() { "$(type -P sudo)" -H -u root "$(type -P gedit)" "${@}" &>/dev/null; }

gted() { "$(type -P gted)" "${@}" &>/dev/null; }
gteds() { "$(type -P sudo)" -H -u root "$(type -P gted)" "${@}" &>/dev/null; }

################################################
## GET THE OS AND ARCH OF THE ACTIVE COMPUTER ##
################################################

mypc()
{
    local OS VER
    
    source '/etc/os-release'
    OS="$NAME"
    VER="$VERSION_ID"

    clear
    printf "%s\n%s\n\n"           \
        "Operating System: ${OS}" \
        "Specific Version: ${VER}"
}

###################
## FIND COMMANDS ##
###################

ffind()
{
    local fname fpath ftype
    clear

    read -p 'Enter the name to search for: ' fname
    echo
    read -p 'Enter a type of file (d|f|blank): ' ftype
    echo
    read -p 'Enter the starting path: ' fpath
    clear

    if [ -n "${fname}" ] && [ -z "${ftype}" ] && [ -z "${fpath}" ]; then
        sudo find . -iname "${fname}" | while read line; do echo "${line}"; done
    elif [ -n "${fname}" ] && [ -z "${ftype}" ] && [ -n "${fpath}" ]; then
        sudo find "${fpath}" -iname "${fname}" | while read line; do echo "${line}"; done
    elif [ -n "${fname}" ] && [ -n "${ftype}" ] && [ -n "${fpath}" ]; then
        sudo find "${fpath}" -type "${ftype}" -iname "${fname}" | while read line; do echo "${line}"; done
    elif [ -n "${fname}" ] && [ -z "${ftype}" ] && [ "${fpath}" ]; then
        sudo find . -iname "${fname}" | while read line; do echo "${line}"; done
    elif [ -n "${fname}" ] && [ -n "${ftype}" ] && [ "${fpath}" = '.' ]; then
        sudo find . -type "${ftype}" -iname "${fname}" | while read line; do echo "${line}"; done
     fi
}

######################
## UNCOMPRESS FILES ##
######################

untar()
{
    clear
    local ext jflag

    for i in *.*
    do
        ext="${i##*.}"

        [[ ! -d "${PWD}"/"${i%%.*}" ]] && mkdir -p "${PWD}"/"${i%%.*}"

        case "${ext}" in
            7z|zip)             7z x -o"${PWD}"/"${i%%.*}" "${PWD}"/"${i}";;
            bz2|gz|tgz|xz)
                                jflag=""
                                gflag=""
                                xflag=""
                                [[ "${ext}" = 'bz2' && "${ext}" != 'gz' && "${ext}" != 'tgz' ]] && jflag="xfj"
                                [[ "${ext}" != 'bz2' && "${ext}" = 'gz' || "${ext}" = 'tgz' ]] && gflag="zxf"
                                [[ "${ext}" = 'xz' && "${ext}" != 'bz2' && "${ext}" != 'gz' && "${ext}" != 'tgz' ]] && xflag="xf"
                                tar -${xflag}${gflag}${jflag} "${PWD}"/"${i}" -C "${PWD}"/"${i%%.*}" 2>/dev/null
                                ;;
        esac
    done
}
            
##################
## CREATE FILES ##
##################

mf()
{
    local i
    clear

    if [ -z "${1}" ]; then
        read -p 'Enter file name: ' i
        clear
        if [ ! -f "${i}" ]; then touch "${i}"; fi
        chmod 744 "${i}"
    else
        if [ ! -f "${1}" ]; then touch "${1}"; fi
        chmod 744 "${1}"
    fi

    clear; ls -1AhFv --color --group-directories-first
}

mdir()
{
    local dir
    clear

    if [[ -z "${1}" ]]; then
        read -p 'Enter directory name: ' dir
        clear
        mkdir -p  "${PWD}/$dir"
        cd "${PWD}/$dir" || exit 1
    else
        mkdir -p "${1}"
        cd "${PWD}/${1}" || exit 1
    fi

    clear; ls -1AhFv --color --group-directories-first
}

##################
## AWK COMMANDS ##
##################

# REMOVED ALL DUPLICATE LINES: OUTPUTS TO TERMINAL
rmd() { clear; awk '!seen[${0}]++' "${1}"; }

# REMOVE CONSECUTIVE DUPLICATE LINES: OUTPUTS TO TERMINAL
rmdc() { clear; awk 'f!=${0}&&f=${0}' "${1}"; }

# REMOVE ALL DUPLICATE LINES AND REMOVES TRAILING SPACES BEFORE COMPARING: REPLACES THE file
rmdf()
{
    clear
    perl -i -lne 's/\s*$//; print if ! $x{$_}++' "${1}"
    gted "${1}"
}

###################
## file COMMANDS ##
###################

# COPY file
cpf()
{
    clear

    if [ ! -d "${HOME}/tmp" ]; then
        mkdir -p "${HOME}/tmp"
    fi

    cp "${1}" "${HOME}/tmp/${1}"

    chown -R "${USER}":"${USER}" "${HOME}/tmp/${1}"
    chmod -R 744 "${HOME}/tmp/${1}"

    clear; ls -1AhFv --color --group-directories-first
}

# MOVE file
mvf()
{
    clear

    if [ ! -d "${HOME}/tmp" ]; then
        mkdir -p "${HOME}/tmp"
    fi

    mv "${1}" "${HOME}/tmp/${1}"

    chown -R "${USER}":"${USER}" "${HOME}/tmp/${1}"
    chmod -R 744 "${HOME}/tmp/${1}"

    clear; ls -1AhFv --color --group-directories-first
}

##################
## APT COMMANDS ##
##################

# DOWNLOAD AN APT PACKAGE + ALL ITS DEPENDENCIES IN ONE GO
aptdl()
{
    clear
    wget -c "$(apt --print-uris -qq --reinstall install ${1} 2>/dev/null | cut -d''\''' -f2)"
    clear; ls -1AhFv --color --group-directories-first
}

# CLEAN
clean()
{
    clear
    sudo apt -y autoremove
    sudo apt clean
    sudo apt autoclean
    sudo apt -y purge
}

# UPDATE
update()
{
    clear
    sudo apt update
    sudo apt -y full-upgrade
    sudo apt -y autoremove
    sudo apt clean
    sudo apt autoclean
    sudo apt -y purge
}

# FIX BROKEN APT PACKAGES
fix()
{
    clear
    if [ -f /tmp/apt.lock ]; then
        sudo rm /tmp/apt.lock
    fi
    sudo dpkg --configure -a
    sudo apt --fix-broken install
    sudo apt -f -y install
    sudo apt -y autoremove
    sudo apt clean
    sudo apt autoclean
    sudo apt update
}

list()
{
    local search_cache
    clear

    if [ -n "${1}" ]; then
        sudo apt list "*${1}*" 2>/dev/null | awk -F'/' '{print $1}'
    else
        read -p 'Enter the string to search: ' search_cache
        clear
        sudo apt list "*${1}*" 2>/dev/null | awk -F'/' '{print $1}'
    fi
}

listd()
{
    local search_cache
    clear

    if [ -n "${1}" ]; then
        sudo apt list -- "*${1}*"-dev 2>/dev/null | awk -F'/' '{print $1}'
    else
        read -p 'Enter the string to search: ' search_cache
        clear
        sudo apt list -- "*${1}*"-dev 2>/dev/null | awk -F'/' '{print $1}'
    fi
}

# USE SUDO APT TO SEARCH FOR ALL APT PACKAGES BY PASSING A NAME TO THE FUNCTION
apts()
{
    local search
    clear

    if [ -n "${1}" ]; then
        sudo apt search "${1} ~i" -F "%p"
    else
        read -p 'Enter the string to search: ' search
        clear
        sudo apt search "${search} ~i" -F "%p"
    fi
}

# USE APT CACHE TO SEARCH FOR ALL APT PACKAGES BY PASSING A NAME TO THE FUNCTION
csearch()
{
    clear
    local cache

    if [ -n "${1}" ]; then
        apt-cache search --names-only "${1}.*" | awk '{print $1}'
    else
        read -p 'Enter the string to search: ' cache
        clear
        apt-cache search --names-only "${cache}.*" | awk '{print $1}'
    fi
}

# FIX MISSING GPNU KEYS USED TO UPDATE PACKAGES
fix_key()
{
    clear

    local file url

    if [[ -z "${1}" ]] && [[ -z "${2}" ]]; then
        read -p 'Enter the file name to store in /etc/apt/trusted.gpg.d: ' file
        echo
        read -p 'Enter the gpg key url: ' url
        clear
    else
        file="${1}"
        url="${2}"
    fi

    curl -S# "${url}" | gpg --dearmor | sudo tee "/etc/apt/trusted.gpg.d/${file}"

    if curl -S# "${url}" | gpg --dearmor | sudo tee "/etc/apt/trusted.gpg.d/${file}"; then
        echo 'The key was successfully added!'
    else
        echo 'The key FAILED to add!'
    fi
}

##########################
# TAKE OWNERSHIP COMMAND #
##########################
toa()
{
    clear
    chown -R "${USER}":"${USER}" "${PWD}"
    chmod -R 744 "${PWD}"
    clear; ls -1AhFv --color --group-directories-first
}

#################
# DPKG COMMANDS #
#################

## SHOW ALL INSTALLED PACKAGES
showpkgs()
{
    dpkg --get-selections |
    grep -v deinstall > "${HOME}"/tmp/packages.list
    gted "${HOME}"/tmp/packages.list
}

# PIPE ALL DEVELOPMENT PACKAGES NAMES TO file
getdev()
{
    apt-cache search dev |
    grep "\-dev" |
    cut -d ' ' -f1 |
    sort > 'dev-packages.list'
    gted 'dev-packages.list'
}

################
## SSH-KEYGEN ##
################

# CREATE A NEW PRIVATE AND PUBLIC SSH KEY PAIR
new_key()
{
    clear

    local bits comment name pass type

    echo -e "Encryption type: [ rsa | dsa | ecdsa ]\\n"
    read -p 'Your choice: ' type
    clear

    echo '[i] Choose the key bit size'
    echo '[i] Values encased in() are recommended'

    if [[ "${type}" == 'rsa' ]]; then
        echo -e "[i] rsa: [ 512 | 1024 | (2048) | 4096 ]\\n"
    elif [[ "${type}" == 'dsa' ]]; then
        echo -e "[i] dsa: [ (1024) | 2048 ]\\n"
    elif [[ "${type}" == 'ecdsa' ]]; then
        echo -e "[i] ecdsa: [ (256) | 384 | 521 ]\\n"
    fi

    read -p 'Your choice: ' bits
    clear

    echo '[i] Choose a password'
    echo -e "[i] For no password just press enter\\n"
    read -p 'Your choice: ' pass
    clear

    echo '[i] Choose a comment'
    echo -e "[i] For no comment just press enter\\n"
    read -p 'Your choice: ' comment
    clear

    echo -e "[i] Enter the ssh key name\\n"
    read -p 'Your choice: ' name
    clear

    echo -e "[i] Your choices\\n"
    echo -e "[i] Type: ${type}"
    echo -e "[i] bits: ${bits}"
    echo -e "[i] Password: ${pass}"
    echo -e "[i] comment: ${comment}"
    echo -e "[i] Key name: ${name}\\n"
    read -p 'Press enter to continue or ^c to exit'
    clear

    ssh-keygen -q -b "${bits}" -t "${type}" -N "${pass}" -C "${comment}" -f "${name}"

    chmod 600 "${PWD}/${name}"
    chmod 644 "${PWD}/${name}".pub
    clear

    echo -e "file: ${PWD}/${name}\\n"
    cat "${PWD}/${name}"

    echo -e "\\nfile: ${PWD}/${name}.pub\\n"
    cat "${PWD}/${name}.pub"
    echo
}

# EXPORT THE PUBLIC SSH KEY STORED INSIDE A PRIVATE SSH KEY
keytopub()
{
    clear; ls -1AhFv --color --group-directories-first

    local opub okey

    echo -e "Enter the full paths for each file\\n"
    read -p 'Private key: ' okey
    read -p 'Public key: ' opub
    clear
    if [ -f "${okey}" ]; then
        chmod 600 "${okey}"
    else
        echo -e "Warning: file missing = ${okey}\\n"
        read -p 'Press Enter to exit.'
        exit 1
    fi
    ssh-keygen -b '4096' -y -f "${okey}" > "${opub}"
    chmod 644 "${opub}"
    cp "${opub}" "${HOME}"/.ssh/authorized_keys
    chmod 600 "${HOME}"/.ssh/authorized_keys
    unset "${okey}"
    unset "${opub}"
}

# install colordiff package :)
cdiff() { clear; colordiff "${1}" "${2}"; }

# GZIP
gzip() { clear; gzip -d "${@}"; }

# get system time
gettime() { clear; date +%r | cut -d " " -f1-2 | grep -E '^.*$'; }

##################
## SOURCE FILES ##
##################

sbrc()
{
    clear

    source "${HOME}"/.bashrc && echo -e "The command was a success!\\n" || echo -e "The command failed!\\n"
    sleep 1

    clear; ls -1AhFv --color --group-directories-first
}

spro()
{
    clear

    source "${HOME}"/.profile && echo -e "The command was a success!\\n" || echo -e "The command failed!\\n"
    sleep 1

    clear; ls -1AhFv --color --group-directories-first
}

####################
## ARIA2 COMMANDS ##
####################

# ARIA2 DAEMON IN THE BACKGROUND
aria2_on()
{
    clear

    if aria2c --conf-path="${HOME}"/.aria2/aria2.conf; then
        echo -e "\\nCommand Executed Successfully\\n"
    else
        echo -e "\\nCommand Failed\\n"
    fi
}

# STOP ARIA2 DAEMON
aria2_off() { clear; killall aria2c; }

# RUN ARIA2 AND DOWNLOAD FILES TO THE CURRENT FOLDER
aria2()
{
    clear

    local file link

    if [[ -z "${1}" ]] && [[ -z "${2}" ]]; then
        read -p 'Enter the output file name: ' file
        echo
        read -p 'Enter the download url: ' link
        clear
    else
        file="${1}"
        link="${2}"
    fi

    aria2c --out="${file}" "${link}"
}

myip()
{
    clear
    printf "%s\n%s\n\n"                                   \
        "LAN: $(ip route get 1.2.3.4 | awk '{print $7}')" \
        "WAN: $(curl -s 'https://checkip.amazonaws.com')"
}

# WGET COMMAND
mywget()
{
    clear; ls -1AhFv --color --group-directories-first

    local outfile url

    if [ -z "${1}" ] || [ -z "${2}" ]; then
        read -p 'Please enter the output file name: ' outfile
        echo
        read -p 'Please enter the URL: ' url
        clear
        wget --out-file="${outfile}" "${url}"
    else
        wget --out-file="${1}" "${2}"
    fi
}

################
# RM COMMANDS ##
################

# RM DIRECTORY
rmd()
{
    clear

    local i

    if [ -z "${1}" ] || [ -z "${2}" ]; then
        read -p 'Please enter the directory name to remove: ' i
        clear
        sudo rm -r "${i}"
        clear
    else
        sudo rm -r "${1}"
        clear
    fi
}

# RM FILE
rmf()
{
    clear

    local i

    if [ -z "${1}" ]; then
        read -p 'Please enter the file name to remove: ' i
        clear
        sudo rm "${i}"
        clear
    else
        sudo rm "${1}"
        clear
    fi
}

#################
## IMAGEMAGICK ##
#################

# OPTIMIZE AND OVERWRITE THE ORIGINAL IMAGES
imow()
{
    local apt_pkgs cnt_queue cnt_total dimensions fext missing_pkgs pip_lock random_dir tmp_file v_noslash

    clear

    # THE FILE EXTENSION TO SEARCH FOR (DO NOT INCLUDE A '.' WITH THE EXTENSION)
    fext=jpg

    #
    # REQUIRED APT PACKAGES
    #

    apt_pkgs=(sox libsox-dev)
    for i in ${apt_pkgs[@]}
    do
        missing_pkg="$(dpkg -l | grep "${i}")"
        if [ -z "${missing_pkg}" ]; then
            missing_pkgs+=" ${i}"
        fi
    done

    if [ -n "${missing_pkgs}" ]; then
        sudo apt -y install ${missing_pkgs}
        sudo apt -y autoremove
        clear
    fi
    unset apt_pkgs i missing_pkg missing_pkgs

    #
    # REQUIRED PIP PACKAGES
    #

    pip_lock="$(find /usr/lib/python3* -name EXTERNALLY-MANAGED)"
    if [ -n "${pip_lock}" ]; then
        sudo rm "${pip_lock}"
    fi
    if ! pip show google_speech &>/dev/null; then
        pip install google_speech
    fi

    unset p pip_lock pip_pkgs missing_pkg missing_pkgs
    # DELETE ANY USELESS ZONE IDENFIER FILES THAT SPAWN FROM COPYING A FILE FROM WINDOWS NTFS INTO A WSL DIRECTORY
    find . -type f -name "*:Zone.Identifier" -delete 2>/dev/null

    # GET THE FILE COUNT INSIDE THE DIRECTORY
    cnt_queue=$(find . -maxdepth 2 -type f -iname "*.jpg" | wc -l)
    cnt_total=$(find . -maxdepth 2 -type f -iname "*.jpg" | wc -l)
    # GET THE UNMODIFIED PATH OF EACH MATCHING FILE

    for i in ./*."${fext}"
    do
        cnt_queue=$(( cnt_queue-1 ))

        cat <<EOT
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

File Path: ${PWD}

Folder: $(basename "${PWD}")

Total Files:    ${cnt_total}
Files in queue: ${cnt_queue}

Converting:  ${i}

 >> ${i%%.jpg}.mpc

    >> ${i%%.jpg}.cache

       >> ${i%%.jpg}-IM.jpg

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
EOT
        echo
        random_dir="$(mktemp -d)"
        dimensions="$(identify -format '%wx%h' "${i}")"
        convert "${i}" -monitor -filter Triangle -define filter:support=2 -thumbnail "${dimensions}" -strip \
            -unsharp '0.25x0.08+8.3+0.045' -dither None -posterize 136 -quality 82 -define jpeg:fancy-upsampling=off \
            -auto-level -enhance -interlace none -colorspace sRGB "${random_dir}/${i%%.jpg}.mpc"


        for file in "${random_dir}"/*.mpc
        do
            convert "${file}" -monitor "${file%%.mpc}.jpg"
            tmp_file="$(echo "${file}" | sed 's:.*/::')"
            mv "${file%%.mpc}.jpg" "${PWD}/${tmp_file%%.*}-IM.jpg"
            rm -f "${PWD}/${tmp_file%%.*}.jpg"
            for v in ${file}
            do
                v_noslash="${v%/}"
                rm -fr "${v_noslash%/*}"
            done
        done
    done

    if [ "${?}" -eq '0' ]; then
        google_speech 'Image conversion completed.' 2>/dev/null
        exit 0
    else
        echo
        google_speech 'Image conversion failed.' 2>/dev/null
        echo
        read -p 'Press enter to exit.'
        exit 1
    fi
}

# DOWNSAMPLE IMAGE TO 50% OF THE ORIGINAL DIMENSIONS USING SHARPER SETTINGS
im50()
{
    clear
    local i

    for i in ./*.jpg
    do
        convert "${i}" -monitor -colorspace sRGB -filter LanczosRadius -distort Resize 50% -colorspace sRGB "${i}"
    done
}

imdl()
{
    local cwd tmp_dir user_agent
    clear
    cwd="${PWD}"
    tmp_dir="$(mktemp -d)"
    user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    cd "${tmp_dir}" || exit 1
    curl -A "${user_agent}" -Lso 'imow' 'https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/ImageMagick/scripts/optimize-and-overwrite.sh'
    sudo mv imow "${cwd}"
    sudo rm -fr "${tmp_dir}"
    cd "${cwd}" || exit 1
    sudo chown "${USER}":"${USER}" imow
    sudo chmod +rwx imow
}

###########################
## SHOW NVME TEMPERATURE ##
###########################

nvme_temp()
{
    clear

    local n0 n1 n2

    n0="$(sudo nvme smart-log /dev/nvme0n1)"
    n1="$(sudo nvme smart-log /dev/nvme1n1)"
    n2="$(sudo nvme smart-log /dev/nvme2n1)"

    printf "nvme0n1:\n\n%s\n\nnvme1n1:\n\n%s\n\nnvme2n1:\n\n%s\n\n" "${n0}" "${n1}" "${n2}"
}

#############################
## REFRESH THUMBNAIL CACHE ##
#############################

rftn()
{
    clear
    sudo rm -fr "${HOME}"/.cache/thumbnails/*
    ls -al "${HOME}"/.cache/thumbnails
}

#####################
## FFMPEG COMMANDS ##
#####################

cuda_purge()
{
    clear

    local answer

    echo 'Do you want to completely remove the cuda-sdk-toolkit?'
    echo
    echo 'WARNING: Do not reboot your PC without reinstalling the nvidia-driver first!'
    echo
    echo '[1] Yes'
    echo '[2] Exit'
    echo
    read -p 'Your choices are (1 or 2): ' answer
    clear

    if [[ "${answer}" -eq '1' ]]; then
        echo 'Purging the cuda-sdk-toolkit from your computer.'
        echo '================================================'
        echo
        sudo sudo apt -y --purge remove "*cublas*" "cuda*" "nsight*"
        sudo sudo apt -y autoremove
        sudo sudo apt update
    elif [[ "${answer}" -eq '2' ]]; then
        return 0
    fi
}

ffdl()
{
    local user_agent
    clear
    curl -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' -m 10 -Lso 'ff.sh' 'https://ffdl.optimizethis.net'
    bash 'ff.sh'
    sudo rm 'ff.sh'
    clear; ls -1AhFv --color --group-directories-first
}

##############################
## LIST LARGE FILES BY TYPE ##
##############################

large_files()
{
    clear

    local answer

    if [ -z "${1}" ]; then
        printf "%s\n\n" 'Input the file extension to search for without a dot: '
        read -p 'Enter your choice: ' answer
        clear
    else
        answer="${1}"
    fi

    sudo find "${PWD}" -type f -name "*.${answer}" -printf '%s %h\n' | sort -ru -o 'large-files.txt'

    if [ -f 'large-files.txt' ]; then
        sudo gted 'large-files.txt'
        sudo rm 'large-files.txt'
    fi
}

###############
## MEDIAINFO ##
###############

mi()
{
    clear

    local i

    if [ -z "${1}" ]; then
        ls -1AhFv --color --group-directories-first
        echo
        read -p 'Please enter the relative file path: ' i
        clear
        mediainfo "${i}"
    else
        mediainfo "${1}"
    fi
}

############
## FFMPEG ##
############

cdff() { clear; cd "${HOME}/tmp/ffmpeg-build" || exit 1; cl; }
ffm() { clear; bash <(curl -sSL 'http://ffmpeg.optimizethis.net'); }
ffp() { clear; bash <(curl -sSL 'http://ffpb.optimizethis.net'); }

####################
## LIST PPA REPOS ##
####################

listppas()
{
    clear

    local apt host user ppa entry

    for apt in $(find /etc/apt/ -type f -name \*.list)
    do
        grep -Po "(?<=^deb\s).*?(?=#|$)" "${apt}" | while read entry
        do
            host="$(echo "${entry}" | cut -d/ -f3)"
            user="$(echo "${entry}" | cut -d/ -f4)"
            ppa="$(echo "${entry}" | cut -d/ -f5)"
            #echo sudo apt-add-repository ppa:${USER}/${ppa}
            if [ "ppa.launchpad.net" = "${host}" ]; then
                echo sudo apt-add-repository ppa:"${USER}/${ppa}"
            else
                echo sudo apt-add-repository \'deb "${entry}"\'
            fi
        done
    done
}

#########################
## NVIDIA-SMI COMMANDS ##
#########################

gpu_mon()
{
    clear
    nvidia-smi dmon
}

################################################################
## PRINT THE NAME OF THE DISTRIBUTION YOU ARE CURRENTLY USING ##
################################################################

my_os()
{
    local name version
    clear

    name="$(eval lsb_release -si 2>/dev/null)"
    version="$(eval lsb_release -sr 2>/dev/null)"

    clear

    printf "%s\n\n" "Linux OS: ${name} ${version}"
}

##############################################
## MONITOR CPU AND MOTHERBOARD TEMPERATURES ##
##############################################

hw_mon()
{
    clear

    local found

    # install lm-sensors if not already
    if ! which lm-sensors &>/dev/null; then
        sudo apt -y install lm-sensors
    fi

    # Add modprobe to system startup tasks if not already added
    found="$(grep -o 'drivetemp' '/etc/modules')"
    if [ -z "${found}" ]; then
        echo 'drivetemp' | sudo tee -a '/etc/modules'
    else
        sudo modprobe drivetemp
    fi

    sudo watch -n1 sensors
}

###################
## 7ZIP COMMANDS ##
###################

# CREATE A GZ FILE WITH MAX COMPRESSION SETTINGS
7z_gz()
{
    local source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.gz ]; then
            sudo rm "${1}".tar.gz
        fi
        7z a -ttar -so -an "${1}" | 7z a -tgz -mx9 -mpass1 -si "${1}".tar.gz
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.gz ]; then
            sudo rm "${output}".tar.gz
        fi
        7z a -ttar -so -an "${source}" | 7z a -tgz -mx9 -mpass1 -si "${output}".tar.gz
    fi
}

# CREATE A XZ FILE WITH MAX COMPRESSION SETTINGS USING 7ZIP
7z_xz()
{
    local source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.xz ]; then
            sudo rm "${1}".tar.xz
        fi
        7z a -ttar -so -an "${1}" | 7z a -txz -mx9 -si "${1}".tar.xz
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.xz ]; then
            sudo rm "${output}".tar.xz
        fi
        7z a -ttar -so -an "${source}" | 7z a -txz -mx9 -si "${output}".tar.xz
    fi
}

# CREATE A 7ZIP FILE WITH MAX COMPRESSION SETTINGS
7z_1()
{
    local answer source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".7z ]; then
            sudo rm "${1}".7z
        fi
        7z a -t7z -m0=lzma2 -mx1 "${1}".7z ./"${1}"/*
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".7z ]; then
            sudo rm "${output}".7z
        fi
        7z a -t7z -m0=lzma2 -mx1 "${output}".7z ./"${source}"/*
    fi

    printf "\n%s\n\n%s\n%s\n\n" \
        'Do you want to delete the original file?' \
        '[1] Yes' \
        '[2] No'
    read -p 'Your choices are (1 or 2): ' answer
    clear

    if [ -n "${1}" ]; then
        source="${1}"
    fi

    case "${answer}" in
        1)      sudo rm -fr "${source}";;
        2)      clear;;
        '')     sudo rm -fr "${source}";;
        *)      printf "\n%s\n\n" 'Bad user input...';;
    esac
}

7z_5()
{
    local answer source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".7z ]; then
            sudo rm "${1}".7z
        fi
        7z a -t7z -m0=lzma2 -mx5 "${1}".7z ./"${1}"/*
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".7z ]; then
            sudo rm "${output}".7z
        fi
        7z a -t7z -m0=lzma2 -mx5 "${output}".7z ./"${source}"/*
    fi

    printf "\n%s\n\n%s\n%s\n\n" \
        'Do you want to delete the original file?' \
        '[1] Yes' \
        '[2] No'
    read -p 'Your choices are (1 or 2): ' answer
    clear

    if [ -n "${1}" ]; then
        source="${1}"
    fi

    case "${answer}" in
        1)      sudo rm -fr "${source}";;
        2)      clear;;
        '')     sudo rm -fr "${source}";;
        *)      printf "\n%s\n\n" 'Bad user input...';;
    esac
}

7z_9()
{
    local answer source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".7z ]; then
            sudo rm "${1}".7z
        fi
        7z a -t7z -m0=lzma2 -mx9 "${1}".7z ./"${1}"/*
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".7z ]; then
            sudo rm "${output}".7z
        fi
        7z a -t7z -m0=lzma2 -mx9 "${output}".7z ./"${source}"/*
    fi

    printf "\n%s\n\n%s\n%s\n\n" \
        'Do you want to delete the original file?' \
        '[1] Yes' \
        '[2] No'
    read -p 'Your choices are (1 or 2): ' answer
    clear

    if [ -n "${1}" ]; then
        source="${1}"
    fi

    case "${answer}" in
        1)      sudo rm -fr "${source}";;
        2)      clear;;
        '')     sudo rm -fr "${source}";;
        *)      printf "\n%s\n\n" 'Bad user input...';;
    esac
}

##################
## TAR COMMANDS ##
##################

# CREATE A GZ FILE USING TAR COMMAND
tar_gz()
{
    local source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.gz ]; then
            sudo rm "${1}".tar.gz
        fi
        tar -cJf "${1}".tar.gz "${1}"
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.gz ]; then
            sudo rm "${output}".tar.gz
        fi
        tar -cJf "${output}".tar.gz "${source}"
    fi
}

tar_bz2()
{
    local source output
    clear

    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.bz2 ]; then
            sudo rm "${1}".tar.bz2
        fi
        tar -cvjf "${1}".tar.bz2 "${1}"
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.bz2 ]; then
            sudo rm "${output}".tar.bz2
        fi
        tar -cvjf "${output}".tar.bz2 "${source}"
    fi
}

tar_xz_1()
{
    local source output
    clear
    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.xz ]; then
            sudo rm "${1}".tar.xz
        fi
        tar -cvJf - "${1}" | xz -1 -c - > "${1}".tar.xz
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.xz ]; then
            sudo rm "${output}".tar.xz
        fi
        tar -cvJf - "${source}" | xz -1 -c - > "${output}".tar.xz
    fi
}

tar_xz_5()
{
    local source output
    clear
    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.xz ]; then
            sudo rm "${1}".tar.xz
        fi
        tar -cvJf - "${1}" | xz -5 -c - > "${1}".tar.xz
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.xz ]; then
            sudo rm "${output}".tar.xz
        fi
        tar -cvJf - "${source}" | xz -5 -c - > "${output}".tar.xz
    fi
}

tar_xz_9()
{
    local source output
    clear
    if [ -n "${1}" ]; then
        if [ -f "${1}".tar.xz ]; then
            sudo rm "${1}".tar.xz
        fi
        tar -cvJf - "${1}" | xz -9 -c - > "${1}".tar.xz
    else
        read -p 'Please enter the source folder path: ' source
        echo
        read -p 'Please enter the destination archive path (w/o extension): ' output
        clear
        if [ -f "${output}".tar.xz ]; then
            sudo rm "${output}".tar.xz
        fi
        tar -cvJf - "${source}" | xz -9 -c - > "${output}".tar.xz
    fi
}

#####################
## FFMPEG COMMANDS ##
#####################

ffr() { clear; bash "${1}" -b --latest --enable-gpl-and-non-free; }
ffrv() { clear; bash -v "${1}" -b --latest --enable-gpl-and-non-free; }

###################
## WRITE CACHING ##
###################

wcache()
{
    clear

    local choice

    lsblk
    echo
    read -p 'Enter the drive id to turn off write caching (/dev/sdX w/o /dev/): ' choice

    sudo hdparm -W 0 /dev/"${choice}"
}

rmd()
{
    clear

    local dirs

    if [ -z "${*}" ]; then
        clear; ls -1A --color --group-directories-first
        echo
        read -p 'Enter the directory path(s) to delete: ' dirs
     else
        dirs="${*}"
    fi

    sudo rm -fr "$dirs"
    clear
    ls -1A --color --group-directories-first
}


rmf()
{
    clear

    local files

    if [ -z "${*}" ]; then
        clear; ls -1A --color --group-directories-first
        echo
        read -p 'Enter the file path(s) to delete: ' files
     else
        files="${*}"
    fi

    sudo rm "${files}"
    clear
    ls -1A --color --group-directories-first
}

## REMOVE BOM
rmb()
{
    sed -i '1s/^\xEF\xBB\xBF//' "${1}"
}

## LIST INSTALLED PACKAGES BY ORDER OF IMPORTANCE

list_pkgs() { clear; dpkg-query -Wf '${Package;-40}${Priority}\n' | sort -b -k2,2 -k1,1; }

## FIX USER FOLDER PERMISSIONS up = user permissions

fix_up()
{
    find "${HOME}"/.gnupg -type f -exec chmod 600 {} \;
    find "${HOME}"/.gnupg -type d -exec chmod 700 {} \;
    find "${HOME}"/.ssh -type d -exec chmod 700 {} \; 2>/dev/null
    find "${HOME}"/.ssh/id_rsa.pub -type f -exec chmod 644 {} \; 2>/dev/null
    find "${HOME}"/.ssh/id_rsa -type f -exec chmod 600 {} \; 2>/dev/null
}

## SET DEFAULT PROGRAMS
set_default()
{
    local choice target name link importance

    clear

    printf "%s\n\n%s\n%s\n\n" \
        'Set default programs' \
        'Example: sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 50' \
        'Example: sudo update-alternatives --install <target> <program_name> <link> <importance>'

    read -p 'Enter the target: ' target
    read -p 'Enter the program_name: ' name
    read -p 'Enter the link: ' link
    read -p 'Enter the importance: ' importance
    clear

    printf "%s\n\n%s\n\n%s\n%s\n\n" \
        "You have chosen: sudo update-alternatives --install ${target} ${name} ${link} ${i}mportance" \
        'Would you like to continue?' \
        '[1] Yes' \
        '[2] No'

    read -p 'Your choices are (1 or 2): ' choice
    clear

    case "${choice}" in
        1)      sudo update-alternatives --install "${target}" "${name}" "${link}" "${i}mportance";;
        2)      return 0;;
        *)      return 0;;
    esac
}

## COUNT FILES IN THE DIRECTORY
cnt_dir()
{
    local keep_cnt
    clear
    keep_cnt="$(find . -maxdepth 1 -type f | wc -l)"
    printf "%s %'d\n\n" "The total directory file count is (non-recursive):" "${keep_cnt}"
}

cnt_dirr()
{
    local keep_cnt
    clear
    keep_cnt="$(find . -type f | wc -l)"
    printf "%s %'d\n\n" "The total directory file count is (recursive):" "${keep_cnt}"
}

##############
## TEST GCC ##
##############

test_gcc()
{
    local answer

# CREATE A TEMPORARY C FILE TO RUN OUR TESTS AGAINST
cat > /tmp/hello.c <<'EOT'
#include <stdio.h>
int main(void)
{
   printf("Hello World!\n");
   return 0;
}
EOT

    if [ -n "${1}" ]; then
        "${1}" -Q -v /tmp/hello.c
    else
        clear
        read -p 'Enter the GCC binary you wish to test (example: gcc-11): ' answer
        clear
        "${answer}" -Q -v /tmp/hello.c
    fi
    sudo rm /tmp/hello.c
}

############################
## UNINSTALL DEBIAN FILES ##
############################

rm_deb()
{
    local fname
    clear

    if [ -n "${1}" ]; then
        sudo dpkg -r "$(dpkg -f "${1}" Package)"
    else
        read -p 'Please enter the Debian file name: ' fname
        clear
        sudo dpkg -r "$(dpkg -f "${fname}" Package)"
    fi
}

######################
## KILLALL COMMANDS ##
######################

tkapt()
{
    local i list
    clear

    list=(apt apt apt apt apt apt apt-get aptitude dpkg)

    for i in ${list[@]}
    do
        sudo killall -9 "${i}" 2>/dev/null
    done
}

gc()
{
    local url
    clear

    if [ -n "${1}" ]; then
        nohup google-chrome "${1}" 2>/dev/null >/dev/null
    else
        read -p 'Enter a URL: ' url
        nohup google-chrome "${url}" 2>/dev/null >/dev/null
    fi
}

####################
## NOHUP COMMANDS ##
####################

nh()
{
    clear
    nohup "${1}" &>/dev/null &
    cl
}

nhs()
{
    clear
    nohup sudo "${1}" &>/dev/null &
    cl
}

nhe()
{
    clear
    nohup "${1}" &>/dev/null &
    exit
    exit
}

nhse()
{
    clear
    nohup sudo "${1}" &>/dev/null &
    exit
    exit
}

## NAUTILUS COMMANDS

nopen()
{
    clear
    nohup nautilus -w "${1}" &>/dev/null &
    exit
}

tkan()
{
    local parent_dir
    parent_dir="${PWD}"
    killall -9 nautilus
    sleep 1
    nohup nautilus -w "${parent_dir}" &>/dev/null &
    exit
}

#######################
## UPDATE ICON CACHE ##
#######################

up_icon()
{
    local i pkgs
    clear

    pkgs=(gtk-update-icon-cache hicolor-icon-theme)

    for i in ${pkgs[@]}
    do
        if ! sudo dpkg -l "${i}"; then
            sudo apt -y install "${i}"
            clear
        fi
    done

    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor
}

############
## ARIA2C ##
############

adl()
{
    local isWSL name url
    clear

    # FIND OUT IF WSL OR NATIVE LINUX IS RUNNING BECAUSE WE HAVE TO CHANGE THE FILE ALLOCATION DEPENDING ON WHICH IS RUNNING
    isWSL="$(echo "$(uname -a)" | grep -o 'WSL2')"
    if [ -n "${isWSL}" ]; then
        setalloc=prealloc
    else
        setalloc=falloc
    fi

    if [ -z "${1}" ]; then
        read -p 'Enter the file name (w/o extension): ' name
        read -p 'Enter download URL: ' url
        clear
    else
        name="${1}"
        url="${2}"
    fi

    aria2c \
        --console-log-level=notice \
        --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36' \
        -x16 \
        -j5 \
        --split=32 \
        --allow-overwrite=true \
        --allow-piece-length-change=true \
        --always-resume=true \
        --async-dns=false \
        --auto-file-renaming=false \
        --min-split-size=8M \
        --disk-cache=64M \
        --file-allocation=${setalloc} \
        --no-file-allocation-limit=8M \
        --continue=true \
        --out="${name}" \
        "${url}"

    if [ "${?}" -eq '0' ]; then
        google_speech 'Download completed.' 2>/dev/null
    else
        google_speech 'Download failed.' 2>/dev/null
    fi

    find . -type f -iname "*:Zone.Identifier" -delete 2>/dev/null
    clear; ls -1AhFv --color --group-directories-first
}

adlm()
{
    local name url
    clear

    if [ -z "${1}" ]; then
        read -p 'Enter the video name (w/o extension): ' name
        read -p 'Enter download URL: ' url
        clear
    else
        name="${1}"
        url="${2}"
    fi

    aria2c \
        --console-log-level=notice \
        --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36' \
        -x16 \
        -j5 \
        --split=32 \
        --allow-overwrite=true \
        --allow-piece-length-change=true \
        --always-resume=true \
        --async-dns=false \
        --auto-file-renaming=false \
        --min-split-size=8M \
        --disk-cache=64M \
        --file-allocation=prealloc \
        --no-file-allocation-limit=8M \
        --continue=true \
        --out="${name}"'.mp4' \
        "${url}"

    if [ "${?}" -eq '0' ]; then
        google_speech 'Download completed.' 2>/dev/null
    else
        google_speech 'Download failed.' 2>/dev/null
    fi

    find . -type f -iname "*:Zone.Identifier" -delete 2>/dev/null
    clear; ls -1AhFv --color --group-directories-first
}

####################
## GET FILE SIZES ##
####################

big_files()
{
    local cnt
    clear

    if [ -n "${1}" ]; then
        cnt="${1}"
    else
        read -p 'Enter how many files to list in the results: ' cnt
        clear
    fi

    printf "%s\n\n" "${cnt} largest files"
    sudo find "${PWD}" -type f -exec du -Sh {} + | sort -hr | head -"${cnt}"
    echo
    printf "%s\n\n" "${cnt} largest folders"
    sudo du -Bm "${PWD}" 2>/dev/null | sort -hr | head -"${cnt}"
}

big_vids()
{
    local cnt
    clear

    if [ -n "${1}" ]; then
        cnt="${1}"
    else
        read -p 'Enter the max number of results: ' cnt
        clear
    fi

    printf "%s\n\n" "Listing the ${cnt} largest videos"
    sudo find "${PWD}" -type f \( -iname '*.mkv' -o -iname '*.mp4' \) -exec du -Sh {} + | grep -Ev '\(x265\)' | sort -hr | head -n"${cnt}"
}

big_img() { clear; sudo find . -size +10M -type f -name '*.jpg' 2>/dev/null; }

jpgsize()
{
    local random_dir size
    clear

    random_dir="$(mktemp -d)"
    read -p 'Enter the image size (units in MB): ' size
    find . -size +"${size}"M -type f -iname "*.jpg" > "${random_dir}/img-sizes.txt"
    sed -i "s/^..//g" "${random_dir}/img-sizes.txt"
    sed -i "s|^|${PWD}\/|g" "${random_dir}/img-sizes.txt"
    clear
    nohup gted "${random_dir}/img-sizes.txt" &>/dev/null &
}

##################
## SED COMMANDS ##
##################

fsed()
{
    clear

    printf "%s\n\n" 'This command is for sed to act ONLY on files'

    if [ -z "${1}" ]; then
        read -p 'Enter the original text: ' otext
        read -p 'Enter the replacement text: ' rtext
        clear
    else
        otext="${1}"
        rtext="${2}"
    fi

     sudo sed -i "s/${otext}/${rtext}/g" $(find . -maxdepth 1 -type f)
}

####################
## CMAKE COMMANDS ##
####################

cmf()
{
    local rel_sdir
    if ! sudo dpkg -l | grep -o cmake-curses-gui; then
        sudo apt -y install cmake-curses-gui
    fi
    clear

    if [ -z "${1}" ]; then
        read -p 'Enter the relative source directory: ' rel_sdir
    else
        rel_sdir="${1}"
    fi

    cmake ${rel_sdir} -B build -G Ninja -Wno-dev
    ccmake ${rel_sdir}
}

##########################
## SORT IMAGES BY WIDTH ##
##########################

jpgs()
{
    clear
    sudo find . -type f -iname '*.jpg' -exec identify -format " ${PWD}/%f: %wx%h " '{}' > /tmp/img-sizes.txt \;
    cat /tmp/img-sizes.txt | sed 's/\s\//\n\//g' | sort -h
    sudo rm /tmp/img-sizes.txt
}

######################################
## DOWNLOAD IMPORTANT BUILD SCRIPTS ##
######################################

gitdl()
{
    clear
    wget -cq 'https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/FFmpeg/build-ffmpeg'
    wget -cq 'https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/ImageMagick/build-magick'
    wget -cq 'https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/GNU%20Software/build-gcc'
    wget -cq 'https://raw.githubusercontent.com/slyfox1186/script-repo/main/Bash/Installer%20Scripts/FFmpeg/repo.sh'
    sudo chmod -R build-gcc build-magick build-ffmpeg repo.sh -- *
    sudo chown -R "${USER}":"${USER}" build-gcc build-magick build-ffmpeg repo.sh
    clear
    ls -1A --color --group-directories-first
}

# COUNT ITEMS IN THE CURRENT FOLDER W/O SUBDIRECTORIES INCLUDED
cntf()
{
    local folder_cnt
    clear
    folder_cnt="$(ls -1 | wc -l)"
    printf "%s\n" "There are ${folder_cnt} files in this folder"
}

## RECURSIVELY UNZIP ZIP FILES AND NAME THE OUTPUT FOLDER THE SAME NAME AS THE ZIP FILE
zipr()
{
    clear
    sudo find . -type f -iname '*.zip' -exec sh -c 'unzip -o -d "${0%.*}" "$0"' '{}' \;
    sudo find . -type f -iname '*.zip' -exec trash-put '{}' \;
}

###################################
## FFPROBE LIST IMAGE DIMENSIONS ##
###################################

ffp()
{
    clear
    if [ -f 00-pic-sizes.txt ]; then
        sudo rm 00-pic-sizes.txt
    fi
    sudo find "${PWD}" -type f -iname '*.jpg' -exec bash -c "identify -format "%wx%h" \"{}\"; echo \" {}\"" > 00-pic-sizes.txt \;
}

####################
## RSYNC COMMANDS ##
####################

rsr()
{
    local destination modified_source source 
    clear

    # you must add an extra folder that is a period '/./' between the full path to the source folder and the source folder itself
    # or rsync will copy the files to the destination directory and it will be the full path of the source folder instead of the source
    # folder and its subfiles only.

    printf "%s\n%s\n%s\n%s\n\n"                                                                    \
        'This rsync command will recursively copy the source folder to the chosen destination.'    \
        'The original files will still be located in the source folder.'                           \
        'If you want to move the files (which deletes the originals then use the function "rsrd".' \
        'Please enter the full paths of the source and destination directories.'

    printf "%s\n\n" 
    read -p 'Enter the source path: ' source
    read -p 'Enter the destination path: ' destination
    modified_source="$(echo "${source}" | sed 's:/[^/]*$::')"'/./'"$(echo "${source}" | sed 's:.*/::')"
    clear

    rsync -aqvR --acls --perms --mkpath --info=progress2 "${modified_source}" "${destination}"
}

rsrd()
{
    local destination modified_source source 
    clear

    # you must add an extra folder that is a period '/./' between the full path to the source folder and the source folder itself
    # or rsync will copy the files to the destination directory and it will be the full path of the souce folder instead of the source
    # folder and its subfiles only.

    printf "%s\n%s\n%s\n%s\n\n"                                                                    \
        'This rsync command will recursively copy the source folder to the chosen destination.'    \
        'The original files will be DELETED after they have been copied to the destination.'       \
        'If you want to move the files (which deletes the originals then use the function "rsrd".' \
        'Please enter the full paths of the source and destination directories.'

    printf "%s\n\n" 
    read -p 'Enter the source path: ' source
    read -p 'Enter the destination path: ' destination
    modified_source="$(echo "${source}" | sed 's:/[^/]*$::')"'/./'"$(echo "${source}" | sed 's:.*/::')"
    clear

    rsync -aqvR --acls --perms --mkpath --remove-source-files "${modified_source}" "${destination}"
}

## IF A PROGRAM HELP COMMAND ONLY TAKES "--help" but not "-h" this will make "-h" work

helpfix()
{    
    if [[ "${?}" -ne '0' ]]; then
       fc -nl -1 | grep -- -h && fc -s -- -h=--help
    fi 
}

EOF
}

#
# CHECK FOR ANY PASSED ARGUMENTS TO SET THE APT PACKAGE MANAGER
#

if [[ "$1" == 'yes' ]]; then
    answer=1
else
    answer=2
fi

case "${answer}" in
    1)
            script_fn
            sed -i 's/apt /apt-fast /g' "$file"
            sed -i 's/apt list /apt-fast list /g' "$file"
            sed -i 's/local apt host /local apt-fast host /g' "$file"
            sed -i 's/for apt in /for apt-fast in /g' "$file"
            sed -i 's/apt apt-get aptitude dpkg/apt-fast apt-get aptitude dpkg/g' "$file"
            sed -i 's/apt search /apt-fast search /g' "$file"
            ;;
    2)      script_fn;;
    *)
            clear
            printf "%s\n\n" 'Bad user input. Please start over.'
            exit 1
            ;;
esac

clear
printf "%s\n%s\n\n" 'The script has completed!'

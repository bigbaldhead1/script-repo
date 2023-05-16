#!/bin/bash

############################
##
## Install Media Players
##
## 1. VLC
## 2. Kodi
## 3. SMPlayer
## 4. GNOME Videos (Totem)
## 5. Bomi
##
############################

clear

if [ $EUID -ne 0 ]; then
    echo 'you must run this as root/sudo'
    echo
    return 1
fi

##
## Functions
##

return_fn()
{
    echo
    echo 'Please star this repository to show your support!'
    echo
    echo 'https://github.com/slyfox1186/script-repo/'
    echo
    rm "$0"
    return 1
}

fail_fn()
{
    clear
    echo "APT was unable to install $1, possibly because it is already installed."
    echo
    echo 'If you think this is a bug please fill out a report.'
    echo
    echo 'https://github.com/slyfox1186/script-repo/issues'
    echo
    rm "$0"
    return 1
}

success_fn()
{
    clear
    echo "$1 was succesfully installed."
    return_fn
}

printf "%s\n\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n" \
    'Please choose a media player to install' \
    '[1] VLC' \
    '[2] Kodi' \
    '[3] SMPlayer' \
    '[4] GNOME Videos (Totem)' \
    '[5] Bomi' \
    '[6] return'

read -p 'Your choices are (1 to 6): ' media_selection
clear

case "$media_selection" in 
    1)
        echo 'Installing VLC Media Player'
        echo
        if snap install vlc; then
            success_fn 'VLC Media Player'
        else
            fail_fn 'VLC Media Player'
        fi
        ;;
    2)
        echo 'Installing Kodi Media Player'
        echo
        apt -y install software-properties-common 2>/dev/null
        add-apt-repository -y ppa:team-xbmc/ppa 2>/dev/null
        if apt -y install kodi; then
             success_fn 'Kodi Media Player'
        else
            fail_fn 'Kodi Media Player'
        fi
        ;;
    3)
        echo 'Installing SMPlayer'
        echo
        if apt -y install smplayer; then
             success_fn 'SMPlayer'
        else
            fail_fn 'SMPlayer'
        fi
        ;;
    4)
        echo 'GNOME Videos (Totem)'
        echo
        if apt -y install totem; then
             success_fn 'GNOME Videos (Totem)'
        else
            fail_fn 'GNOME Videos (Totem)'
        fi
        ;;
    5)
        echo 'Installing Bomi'
        echo
        add-apt-repository ppa:nemonein/bomi 2>/dev/null
        apt update 2>/dev/null
        if apt -y install bomi; then
             success_fn 'Bomi'
        else
            fail_fn 'Bomi'
        fi
        ;;
    6)
        return_fn
        ;;

    *)
        echo 'Bad user input: Run the script again.'
        echo
        return 1
        ;;
esac

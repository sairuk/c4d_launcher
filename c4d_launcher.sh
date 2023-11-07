#!/usr/bin/env bash

# from https://streetpea.github.io/chiaki4deck/setup/automation/
# modified by sairuk

FLATPAK=io.github.streetpea.Chiaki4deck
CONFIG=${HOME}/.config/c4d_launcher.config

# CONFIG
if [ -f $CONFIG ] 
then
    source $CONFIG
else
    echo "Error: Config file not found: $CONFIG" >/dev/stderr
    exit 1
fi

LAUNCHOPTS=()
[ ! -z $LOGIN_PASSCODE ] && LAUNCHOPTS+=" --passcode $LOGIN_PASSCODE"
[ ! -z $VIEW_MODE ] && LAUNCHOPTS+=" --${VIEW_MODE}"
[ $DUALSENSE -eq 1 ] && LAUNCHOPTS+=" --dualsense"

connect_error_loc()
{
cat << EOF > /dev/stderr
Error: Couldn't connect to your PlayStation console from your local address!
       Please check that your Steam Deck and PlayStation are on the same network 
       and that you have the right PlayStation IP address or hostname!
EOF
exit 1
}

connect_error_ext()
{
cat << EOF > /dev/stderr
Error: Couldn't connect to your PlayStation console from your external address!
       Please check that you have forwarded the necessary ports on your router
       and that you have the right external PlayStation IP address or hostname!
EOF
exit 1
}

wakeup_error()
{
cat << EOF > /dev/stderr
Error: Couldn't wake up PlayStation console from sleep!
       Please make sure you are using a PlayStation 5.
       If not, change the wakeup call to use the number of your PlayStation console
EOF
exit 2
}

timeout_error()
{
cat << EOF > /dev/stderr
Error: PlayStation console didn't become ready in $TIMEOUT seconds!
       Please change $TIMEOUT to a higher number in your script if this persists.
EOF
exit 1
}

if [ $ETHERNET -ne 0 ] || [ -f $(which iwgetid) || "$(iwgetid -r)" == "${LOCAL_SSID}" ]
then
    ADDR="${LOCAL_ADDR}"
    LOCAL=true
else
    ADDR="${EXT_ADDR}"
    LOCAL=false
fi

if [ $ALWAYS_ON -eq 0 ]
then
    if [ $NO_DISCOVER -ne 0 ]
    then
        SECONDS=0
        # Wait for console to be in sleep/rest mode or on (otherwise console isn't available)
        PS_STATUS="$(flatpak run $FLATPAK discover -h ${ADDR} 2>/dev/null)"
        while ! echo "${PS_STATUS}" | grep -q 'ready\|standby'
        do
            if [ ${SECONDS} -gt $TIMEOUT ]
            then
                if [ "${LOCAL}" = true ]
                then
                    connect_error_loc
                else
                    connect_error_ext
                fi
            fi
            sleep 1
            PS_STATUS="$(flatpak run $FLATPAK discover -h ${ADDR} 2>/dev/null)"
        done
    else
        PS_STATUS="standby"
    fi

    # Wake up console from sleep/rest mode if not already awake
    if ! echo "${PS_STATUS}" | grep -q ready
    then
    flatpak run $FLATPAK wakeup -${CONSOLE_TYPE} -h ${ADDR} -r ${REMOTEPLAY_KEY} 2>/dev/null
    fi

    if [ $NO_DISCOVER -eq 0 ]
    then
        # Wait for PlayStation to report ready status, exit script on error if it never happens.
        while ! echo "${PS_STATUS}" | grep -q ready
        do
            if [ ${SECONDS} -gt $TIMEOUT ]
            then
                if echo "${PS_STATUS}" | grep -q standby
                then
                    wakeup_error
                else
                    timeout_error
                fi
            fi
            sleep 1
            PS_STATUS="$(flatpak run $FLATPAK discover -h ${ADDR} 2>/dev/null)"
        done
    else
        sleep $TIMEOUT
    fi
fi

# Begin playing PlayStation remote play via Chiaki on your Steam Deck :)
#

flatpak run $FLATPAK ${LAUNCHOPTS} stream ${CONSOLE_NAME} ${ADDR}
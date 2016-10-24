#!/bin/sh

sleep_duration=$1

if [ -z "$sleep_duration" ]; then
        sleep_duration=0
fi

PULL_WHITELIST="/usr/sbin/sec_clt getwhitelist"
PULL_BLACKLIST="/usr/sbin/sec_clt getblacklist"

switch_security=`uci get rule_mgr.switch.security_center 2>/dev/null`

if [ $switch_security -ne "1" ]; then
    echo "switch flag is not enabled."
    exit 0
fi

/etc/init.d/rule_mgr status
if [ $? -ne "0" ]; then

    #start rule_mgr service 1stly
    /etc/init.d/rule_mgr start
    sleep 1
fi

#pull action in random duration
if [ $sleep_duration -gt "0" ]; then
    sleeptm=`cat /dev/urandom |head -c 30|md5sum | tr -d [0a-zA-Z- ]  2>/dev/null`
    sleeptm=$((${sleeptm:0:8}%$sleep_duration))                                              
    if [ $sleeptm -gt "0" ]; then
        echo "sleep $sleeptm to pull list."
        sleep $sleeptm
    fi
fi
   
echo "pull security black&white list..."

. /lib/lib.scripthelper.sh

$PULL_WHITELIST 2>&1 | pipelog dlog  
$PULL_BLACKLIST 2>&1 | pipelog dlog


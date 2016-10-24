#!/bin/sh

sleep_duration=$1

if [ -z "$sleep_duration" ]; then
        sleep_duration=0
fi

PULL_LIST="/usr/sbin/ad_filter_client --pull"

switch_ad_filter=`uci get rule_mgr.switch.ad_filter_center 2>/dev/null`

if [ -z $switch_ad_filter ]; then
    echo "switch ad_filter not set."
    exit 0
fi

if [ $switch_ad_filter -ne "1" ]; then
    echo "switch flag is not enabled."
    exit 0
fi

/etc/init.d/rule_mgr status
if [ $? -ne "0" ]; then

    #start rule_mgr service 1stly
    /etc/init.d/rule_mgr start
    sleep 1
fi

# enable ad_filter switch
echo "1" > /proc/sys/net/ipv4/http_ad_filter_switch

#pull action in random duration
if [ $sleep_duration -gt "0" ]; then
    sleeptm=`cat /dev/urandom |head -c 30|md5sum | tr -d [0a-zA-Z- ]  2>/dev/null`
    sleeptm=$((${sleeptm:0:8}%$sleep_duration))
    if [ $sleeptm -gt "0" ]; then
        echo "sleep $sleeptm to pull list."
        sleep $sleeptm
    fi
fi

echo "pull AD filter list..."

. /lib/lib.scripthelper.sh

$PULL_LIST 2>&1 | pipelog dlog


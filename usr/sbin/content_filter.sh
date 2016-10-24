#!/bin/sh

sleep_duration=$1

if [ -z "$sleep_duration" ]; then
        sleep_duration=0
fi

is_filter_enabled()
{
    switch_content_filter=`uci get rule_mgr.switch.content_filter_center -q`

    if [ -z $switch_content_filter ]; then
        echo "switch content_filter not set."
        return 0
    fi

    if [ $switch_content_filter -ne "1" ]; then
        echo "switch flag is not enabled."
        return 0
    else
        return 1
    fi
}

down_list_to_kernel()
{
    is_filter_enabled
    if [ $? -eq 0 ]; then
        echo "content_filter switch not enabled! exit!"
        exit 0
    fi
    /etc/init.d/rule_mgr status
    if [ $? -ne "0" ]; then
        #start rule_mgr service 1stly
        /etc/init.d/rule_mgr start
        sleep 1
    fi

    # enable content_filter switch
    # echo "1" > /proc/sys/net/ipv4/http_content_filter_switch

    #pull action in random duration
    if [ $sleep_duration -gt "0" ]; then
        sleeptm=`cat /dev/urandom |head -c 30|md5sum | tr -d [0a-zA-Z- ]  2>/dev/null`
        sleeptm=$((${sleeptm:0:8}%$sleep_duration))
        if [ $sleeptm -gt "0" ]; then
            echo "sleep $sleeptm to pull list."
            sleep $sleeptm
        fi
    fi

    . /lib/lib.scripthelper.sh

    PULL_LIST="/usr/sbin/content_filter_client --pull"

    $PULL_LIST 2>&1 | pipelog dlog
}

ipset_name=toolbar

down_list_to_ipset()
{
    # generate dnsmasq config
    PULL_LIST="/usr/sbin/content_filter_client --mode ipset --pull"
    $PULL_LIST > /dev/null 2>&1

    # enable dnsmasq ipset
    mv -f /tmp/dnsmasq.toolbar.conf /etc/dnsmasq.d/ > /dev/null 2>&1
    /etc/init.d/dnsmasq restart
}

clean_ipset_list()
{
    # disable dnsmasq ipset
    rm -f /tmp/dnsmasq.toolbar.conf
    rm -f /etc/dnsmasq.d/dnsmasq.toolbar.conf
    /etc/init.d/dnsmasq restart

    # destroy ipset
    ipset flush $ipset_name > /dev/null 2>&1
    ipset destroy $ipset_name > /dev/null 2>&1

    # clean content filter
    CLEAN_LIST="/usr/sbin/content_filter_client --mode ipset --clean"
    $CLEAN_LIST > /dev/null 2>&1
}

# down_list_to_kernel # currently not used

op=$2
if [ -z $op ]; then
    echo "content_filter: operator is null(should be start or stop), exit"
    exit 0
fi

if [ $op == "start" ]; then
    is_filter_enabled
    if [ $? -eq 1 ]; then
        down_list_to_ipset
    else
        echo "content_filter: switch is not enabled."
    fi
elif [ $op == "stop" ]; then
    clean_ipset_list
else
    echo "content_filter: unkonw operator(should be start or stop)."
fi

#!/bin/sh

PROXY_SWITCH_PATH="/proc/sys/net/ipv4/tcp_proxy_switch"
HTTP_INFO_SWITCH_PATH="/proc/sys/net/ipv4/http_info_switch"
APP_CTF_MGR="/usr/sbin/ctf_manger.sh"
service_name="http_info"

usage()
{
    echo "usage:"
    echo "http_info.sh on|off"
    echo "on -- enable http info for trafficd"
    echo "off -- disable http info for trafficd"
    echo ""
}

# only for R1CL in china region
is_applicable()
{
    local cc=$(nvram get CountryCode)
    cc=${cc:-"CN"}
    if [ $cc != "CN" ]; then
        echo "http_info.sh: only for China!"
        return 0
    fi
    return 1
}

create_ctf_mgr_entry()
{
    uci -q batch <<EOF > /dev/null
set ctf_mgr.$service_name=service
set ctf_mgr.$service_name.http_switch=off
commit ctf_mgr
EOF
}

enable_http_info()
{
    fastpath=`uci get misc.http_proxy.fastpath -q`
    [ -z $fastpath ] && return 0

    if [ $fastpath == "ctf" ]; then
        if [ -f $APP_CTF_MGR ]; then
            is_exist=`uci get ctf_mgr.$service_name -q`
            if [ $? -eq "1" ]; then
                create_ctf_mgr_entry
            fi
            $APP_CTF_MGR $service_name http on
        else
            echo "$service_name: no ctf mgr found!"
            return 0
        fi
    elif [ $fastpath == "hwnat" ]; then
        echo "$service_name: can work with hw_nat."
    else
        echo "$service_name: unknown fastpath! Treat as std!"
    fi

    # insert kmod
    insmod nf_conn_ext_http >/dev/null 2>&1
    insmod nf_tcp_proxy >/dev/null 2>&1
    insmod http_info >/dev/null 2>&1

    # ensure start switch
    echo "1" > $PROXY_SWITCH_PATH
    echo "1" > $HTTP_INFO_SWITCH_PATH
}

disable_http_info()
{
    echo "0" > $HTTP_INFO_SWITCH_PATH
    rmmod http_info >/dev/null 2>&1
    rmmod nf_tcp_proxy >/dev/null 2>&1

    fastpath=`uci get misc.http_proxy.fastpath -q`
    [ -z $fastpath ] && return 0

    if [ $fastpath == "ctf" ]; then
        if [ -f $APP_CTF_MGR ]; then
            $APP_CTF_MGR $service_name http off
        fi
    elif [ $fastpath == "hwnat" ]; then
        echo "$service_name: stopped."
    else
        echo "$service_name: unknown fastpath! Treat as std!"
    fi
}

op=$1
if [ -z $op ]; then
    usage
    return 0
fi

is_applicable
[ $? -eq 0 ] && return 0

if [ $op == "on" ]; then
    enable_http_info
elif [ $op == "off" ]; then
    disable_http_info
else
    echo "wrong parameters!"
    usage
fi
return 0

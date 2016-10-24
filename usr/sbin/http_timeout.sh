#!/bin/sh

CFG_PATH="/proc/sys/net/ipv4/tcp_proxy_action"
PROXY_SWITCH_PATH="/proc/sys/net/ipv4/tcp_proxy_switch"
APP_CTF_MGR="/usr/sbin/ctf_manger.sh"
service_name="http_timeout"
LIP=`uci get network.lan.ipaddr 2>/dev/null`
PROXY_PORT=8189

usage()
{
    echo "usage:"
    echo "http_timeout.sh on|off"
    echo "on -- enable http timeout proxy"
    echo "off -- disable http timeout proxy"
    echo ""
}

# only for R1CL in china region
is_applicable()
{
    local cc=$(nvram get CountryCode)
    cc=${cc:-"CN"}
    if [ $cc != "CN" ]; then
        echo "http_timeout.sh: only for China!"
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

enable_http_timeout()
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
    insmod http_timeout >/dev/null 2>&1
    echo "ADD 6 $LIP $PROXY_PORT" > $CFG_PATH

    # ensure start switch
    echo "1" > $PROXY_SWITCH_PATH
}

disable_http_timeout()
{
    rmmod http_timeout >/dev/null 2>&1
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
    enable_http_timeout
elif [ $op == "off" ]; then
    disable_http_timeout
else
    echo "wrong parameters!"
    usage
fi
return 0

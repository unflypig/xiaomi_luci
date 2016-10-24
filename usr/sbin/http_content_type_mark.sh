#!/bin/sh

# video: priority 3
video_mark=0x00300000
video_string="video/"
audio_string="audio/"

# download: priority 4
download_mark=0x00400000
download_string="application/octet-stream"

# http content type setting node
config_file="/proc/http_dpi/content_type_mark"
switch_file="/proc/sys/net/ipv4/http_content_type_switch"

APP_CTF_MGR="/usr/sbin/ctf_manger.sh"
service_name="http_content_type"

create_ctf_mgr_entry()
{
    uci -q batch <<EOF > /dev/null
set ctf_mgr.$service_name=service
set ctf_mgr.$service_name.http_switch=off
commit ctf_mgr
EOF
}

set_config()
{
    oper=$1
    if [ $oper == "add" -o $oper == "del" ]; then
        echo "$oper $video_string $video_mark" > $config_file
        echo "$oper $audio_string $video_mark" > $config_file
        echo "$oper $download_string $download_mark" > $config_file
    fi
}

enable_content_type_mark()
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

    insmod nf_conn_ext_http >/dev/null 2>&1
    insmod nf_tcp_proxy >/dev/null 2>&1
    insmod http_content_type_mark >/dev/null 2>&1
    set_config "add"
    # enable
    echo "1" > /proc/sys/net/ipv4/tcp_proxy_switch
    echo "1" > $switch_file
}


disable_content_type_mark()
{
    echo "0" > $switch_file
    set_config "del"
    rmmod http_content_type_mark >/dev/null 2>&1
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

show_usage()
{
    echo "usage:"
    echo "http_content_type_mark on|off"
    echo ""
}

op=$1
[ -z $op ] && show_usage && exit 0

if [ $op == "on" ]; then
    enable_content_type_mark
elif [ $op == "off" ]; then
    disable_content_type_mark
else
    echo "unknow command!"
    show_usage
fi


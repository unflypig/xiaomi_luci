#!/bin/sh
# Copyright (C) 2015 Xiaomi
#

wifiap_interface_find_by_device()
{
    local iface_no_list=""

    iface_no_list=`uci show wireless | awk 'BEGIN{FS="\n";}{for(i=0;i<NF;i++) { if($i~/wireless.@wifi-iface\[.\].device='$1'/) print substr($i, length("wireless.@wifi-iface[")+1, 1)}}'`

    for i in $iface_no_list
    do
        if [ `uci get wireless.@wifi-iface[$i].mode` == "ap" ]
        then
            echo $i
            return 0
        fi
    done

    return 1
}

#default interface num 1
#2.4G interface setup
local device_name=`uci get misc.wireless.if_2G`
local iface_no=`wifiap_interface_find_by_device $device_name`
[ "$iface_no" == "" ] && return 1

ssid=`uci get wireless.@wifi-iface[$iface_no].ssid`
ssid_base64=`echo -n $ssid | base64`

key=`uci get wireless.@wifi-iface[$iface_no].key`
key_base64=`echo -n $key | base64`

tbus list | grep -v netapi | while read a
do
     #call tbus function to notice device change wifi passwd
    timeout -t 2 tbus call $a notice  "{\"ssid\":\"${ssid_base64}\",\"passwd\":\"${key_base64}\"}"
done

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

maclist=`uci get wireless.@wifi-iface[$iface_no].maclist`
maclist_format=`echo -n $maclist | sed "s/ /;/g"`
filter=`uci get wireless.@wifi-iface[$iface_no].macfilter`

if [ $filter = "deny" ]; then
    policy=2
elif [ $filter = "allow" ]; then
    policy=1
else
    policy=0
fi

tbus list | grep -v netapi | while read a
do
     #call tbus function to notice device change maclist
    timeout -t 2 tbus call $a access  "{\"policy\":${policy},\"list\":\"${maclist_format}\"}"
done

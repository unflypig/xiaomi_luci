#!/bin/sh

error(){
    echo "parameter lost. exit."
    exit -1
}

[ -z "$1" ] && error

ACT=$1

DEV_I="ifb0"
DEV_O="eth0.2"
WAN_TYPE=`uci get network.wan.proto 2>/dev/null`
#if [ "$WAN_TYPE" == "pppoe" ]; then
#    DEV_O="pppoe-wan"
#fi

TCQ="/usr/sbin/tc qdisc "
TCC="/usr/sbin/tc class "
TCF="/usr/sbin/tc filter "

redir_clean(){
    #clean origin redir 1stly
    $TCQ del dev pppoe-wan ingress 2>/dev/null
    $TCQ del dev eth0.2 ingress 2>/dev/null
}


redir_add(){
    $TCQ add dev $DEV_O handle ffff: ingress
    $TCF add dev $DEV_O parent ffff: protocol all u32 match u32 0 0 action connmark action mirred egress redirect dev $DEV_I
}

main_work(){
if [ $ACT == "up" ]; then # ifb up
    redir_clean
    redir_add
elif [ $ACT == "down" ]; then #ifb down
    redir_clean
elif [ $ACT == "refresh" ]; then # wan changed
    redir_clean
    redir_add
else # others 
    error
fi
}

main_work
echo "ifb redirect work: $ACT done."

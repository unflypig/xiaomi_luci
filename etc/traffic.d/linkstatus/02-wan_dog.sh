#!/bin/sh

wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
[ -n $wan_port ] || exit 0

[ $wan_port = $PORT_NUM -a $LINK_STATUS = "linkup" ] && {
    pidof udhcpc >/dev/null || exit 0
    logger -p warn -t "trafficd" "run wwdog because wan port up"
    pidof wwdog >/dev/null || /usr/sbin/wwdog
    exit 0
}

#[ $wan_port = $PORT_NUM -a $LINK_STATUS = "linkdown" ] && {
#    pidof pppd > /dev/null || exit 0
#    logger -p warn -t "trafficd" "run pppoe-check because wan port down"
#    pidof pppoe-check >/dev/null || /usr/sbin/pppoe-check
#    exit 0
#}

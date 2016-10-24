#!/bin/sh
CMD="/etc/init.d/rule_mgr"
LIP=`uci get network.lan.ipaddr 2>/dev/null`
LMASK=`uci get network.lan.netmask 2>/dev/null`
L_WARNING_PORT=8192
L_CACHED_PORT=8193
L_AD_FILTER_PORT=8196
L_CONTENT_FILTER_PORT=8197
fastpath=""
FLAG=$1
CFG_PATH="/proc/sys/net/ipv4/tcp_proxy_action"
SWITCH_PATH="/proc/sys/net/ipv4/tcp_proxy_switch"

fastpath=`uci get misc.http_proxy.fastpath -q`
[ -z $fastpath ] && return 0

if [ $FLAG == "start" ]; then

    $CMD status

    if [ $? -eq 0 ]; then
        echo "open and set actions to kernel"
        echo "ADD 1 $LIP $L_WARNING_PORT" > $CFG_PATH
        echo "ADD 2 $LIP $L_CACHED_PORT" > $CFG_PATH
        echo "ADD 3 $LIP $L_AD_FILTER_PORT" > $CFG_PATH
        echo "ADD 4 $LIP $L_CONTENT_FILTER_PORT" > $CFG_PATH

        # ensure start switch
        echo "1" > $SWITCH_PATH

        if [ $fastpath == "ctf" ]; then
            ctf_manger.sh rule_mgr http on
        elif [ $fastpath == "hwnat" ]; then
            #config_load "hwnat"
            uci set hwnat.switch.rule_mgr=1
            uci commit hwnat
            /etc/init.d/hwnat stop &>/dev/null
        else
            echo "rule_mgr: unknown fastpath type! Treat as Std!"
        fi

        if [ $? -ne "0" ]; then
            echo "iptables insert SKIPCTF or remove hw_nat error."
            return $?
        fi
    else
        echo "rule_mgr service is not running"
    fi
elif [ $FLAG == "stop" ]; then
    echo "close and reset actions to kernel"
    # no need close switch, in case someone use it.
    # echo "0" > $SWITCH_PATH

    if [ $fastpath == "ctf" ]; then
        ctf_manger.sh rule_mgr http off
    elif [ $fastpath == "hwnat" ]; then
        #config_load "hwnat"
        uci set hwnat.switch.rule_mgr=0
        uci commit hwnat
        /etc/init.d/hwnat start &>/dev/null
    else
        echo "rule_mgr: unknown fastpath type! Treat as Std!"
    fi

    if [ $? -ne "0" ]; then
        echo "iptables remove SKIPCTF or insert hw_nat error."
        return $?
    fi
elif [ $FLAG == "refresh_lan" ]; then
    $CMD status
    if [ $? -eq 0 ]; then
        # just reset cfg when rule_mgr running
        logger -t "rule_mgr" "refresh lan config!"
        echo "ADD 1 $LIP $L_WARNING_PORT" > $CFG_PATH
        echo "ADD 2 $LIP $L_CACHED_PORT" > $CFG_PATH
        echo "ADD 3 $LIP $L_AD_FILTER_PORT" > $CFG_PATH
        echo "ADD 4 $LIP $L_CONTENT_FILTER_PORT" > $CFG_PATH
    fi
fi


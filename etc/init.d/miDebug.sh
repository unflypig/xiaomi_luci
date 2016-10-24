#!/bin/sh

VERIFY_URL="http://api.miwifi.com/superNode/client?verifyCode="

start() {
	if [ ! -n "$1" ]; then
        echo "Please input verify code!"
        exit -1
    fi
    verifyCode=`echo $1 | sed 's/"//g'`
    depasswd=`echo $2 | sed 's/"//g'`
    data=`curl -s ${VERIFY_URL}${verifyCode}`
    RetCode=`echo ${data} | jason.sh -b | grep "\"code\"" | awk '{print $2}'`
    if [ "0" != "$RetCode" ]; then
        echo "Get param failed RetCode=$RetCode"
        exit 1;
    fi
    enParam=`echo ${data} | jason.sh -b | grep "\"data\",\"config\"" | awk '{print $2}' | sed 's/"//g'`
    rm -rf /tmp/DebugParam.txt
    getedgeparam $enParam $depasswd

    if [ -f "/tmp/DebugParam.txt" ]; then
        dePram=`cat /tmp/DebugParam.txt` 
        groupName=`echo ${dePram} | jason.sh -b | grep "\"groupName\"" | awk '{print $2}'| sed 's/"//g'`
        macaddr=`echo ${dePram} | jason.sh -b | grep "\"mac\"" | awk '{print $2}'| sed 's/"//g'`
        password=`echo ${dePram} | jason.sh -b | grep "\"password\"" | awk '{print $2}'| sed 's/"//g'`
        ip=`echo ${dePram} | jason.sh -b | grep "\"ip\"" | awk '{print $2}'| sed 's/"//g'`
        node=`echo ${dePram} | jason.sh -b | grep "\"node\"" | awk '{print $2}'| sed 's/"//g'`
        #set n2n config file
        uci set edge2.@edge[0].ipaddr=$ip
        uci set edge2.@edge[0].supernode=$node
        uci set edge2.@edge[0].community=$groupName
        uci set edge2.@edge[0].key=$password
        uci set edge2.@edge[0].macaddr=$macaddr
        uci set edge2.@edge[0].enabled=1
        uci commit edge2
    fi
}

stop() {
        exit $?
}

if [ $# -lt 1 ] ; then
    echo "USAGE: $0 start verifyCode | stop"
    exit 1;
fi

case "$1" in
    "start")
        if [ ! -n "$2"  -o ! -n "$3" ]; then
            echo "USAGE: $0 start verifyCode password | stop"
        else
            start $2 $3
            /etc/init.d/edged2 restart
        fi
        ;;
    "stop")
        /etc/init.d/edged2 stop
        uci set edge2.@edge[0].enabled=0
        uci commit edge2
        ;;
    *)
        echo "USAGE: $0 start verifyCode password | stop"
        exit 1;
        ;;
esac

exit 0;

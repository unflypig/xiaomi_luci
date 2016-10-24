#!/bin/sh

cmd_get="uci -q get rule_mgr.switch"
cmd_set="uci set rule_mgr.switch"
cmd_del="uci delete rule_mgr.switch"
cmd_commit="uci commit rule_mgr"

usage()
{
    echo "usage:"
    echo "rule_mgr_cmd app_name init|fini|start|stop"
    echo "    init  -- init config when app install"
    echo "    fini  -- cleanup config when app uninstall"
    echo "    start -- start rule_mgr service for app"
    echo "    stop  -- stop rule_mgr service for app"
    echo ""
    return 0
}

exec_name="$0"
app_name="$1"
oper="$2"

if [ -z "$app_name" -o -z "$oper" ]; then
    echo "$exec_name: parameter not right!"
    usage
    return 0
fi

if [ "$oper" == "init" ]; then
    $cmd_set.$app_name=0 > /dev/null 2>&1
    $cmd_commit >/dev/null 2>&1
elif [ "$oper" == "fini" ]; then
    local switch=`$cmd_get.$app_name`
    if [ -z $switch ]; then
        echo "$exec_name, switch[$app_name] not exist, wrong usage!"
        return 0
    elif [ $switch -eq "1" ]; then
        echo "$exec_name, switch[$app_name] on, please stop it first!"
        return 0
    fi
    $cmd_del.$app_name > /dev/null 2>&1
    $cmd_commit >/dev/null 2>&1
elif [ "$oper" == "start" ]; then
    $cmd_set.$app_name=1 > /dev/null 2>&1
    $cmd_commit >/dev/null 2>&1
    /etc/init.d/rule_mgr start
elif [ "$oper" == "stop" ]; then
    $cmd_set.$app_name=0 > /dev/null 2>&1
    $cmd_commit >/dev/null 2>&1
    /etc/init.d/rule_mgr stop
else
    echo "$exec_name, wrong operate parameter!"
    usage
fi
return 0

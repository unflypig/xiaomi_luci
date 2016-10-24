#!/bin/sh

. /lib/functions.sh

dnsmasq_conf_path="/etc/dnsmasq.d/"
parentalctl_conf_path="/etc/parentalctl/"
parentalctl_conf_name="parentalctl.conf"
parentalctl_conf_ip_name="parentalctl_ip.conf"
rule_prefix="parentalctl_"
ipset_name="parentalctl_"

time_seg=""
weekdays=""
hosts=""
src_mac=""
start_date=""
stop_date=""

device_set=""

local _pctl_file="$parentalctl_conf_path"/"$parentalctl_conf_name"
local _pctl_ip_file="$parentalctl_conf_path"/"$parentalctl_conf_ip_name"
local _has_pctl_file=0
local _dnsmasq_file="$dnsmasq_conf_path"/"$parentalctl_conf_name"

local time_cntr=0

pctl_logger()
{
    echo "parentalctl: $1"
    logger -t parentalctl "$1"
}

dnsmasq_restart()
{
    process_pid=$(ps | grep "/usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" |grep -v "grep /usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" | awk '{print $1}' 2>/dev/null)
    process_num=$( echo $process_pid |awk '{print NF}' 2>/dev/null)
    process_pid1=$( echo $process_pid |awk '{ print $1; exit;}' 2>/dev/null)
    process_pid2=$( echo $process_pid |awk '{ print $2; exit;}' 2>/dev/null)


    [ "$process_num" != "2" ] && /etc/init.d/dnsmasq restart

    retry_times=0
    while [ $retry_times -le 3 ]
    do
        let retry_times+=1
        /etc/init.d/dnsmasq restart
        sleep 1

        process_newpid=$(ps | grep "/usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" |grep -v "grep /usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" | awk '{print $1}' 2>/dev/null)
        process_newnum=$( echo $process_newpid |awk '{print NF}' 2>/dev/null)
        process_newpid1=$( echo $process_newpid |awk '{ print $1; exit;}' 2>/dev/null)
        process_newpid2=$( echo $process_newpid |awk '{ print $2; exit;}' 2>/dev/null)

        pctl_logger "old: $process_pid1 $process_pid2 new: $process_newpid1 $process_newpid2"

        [ "$process_pid1" == "$process_newpid1" ] && continue;
        [ "$process_pid1" == "$process_newpid2" ] && continue;
        [ "$process_pid2" == "$process_newpid1" ] && continue;
        [ "$process_pid2" == "$process_newpid2" ] && continue;

        break
    done
}

#format 2015-05-19
date_check()
{
    local _date=$1

    [ "$_date" == "" ] && return 0

    if echo $_date | grep -iqE "^2[0-9]{3}-[0-1][0-9]-[0-3][0-9]$"
    then
         #echo mac address $mac format correct;
         return 0
    else
         echo "date \"$_date\" format(2xxx-xx-xx) error";
         return 1
    fi

    return 0
}

#format "09:20-23:59"
time_check()
{
    local _time_set=$1
    local _time=""

    [ "$_time_set" == "" ] && return 0

    for _time in $_time_set
    do
        if echo $_time | grep -iqE "^[0-2][0-9]:[0-6][0-9]-[0-2][0-9]:[0-6][0-9]$"
        then
            #echo mac address $mac format correct;
            return 0
        else
            echo "time \"$_time\" format(09:20-23:59) error";
            return 1
        fi
    done

    return 0
}

#format 01:02:03:04:05:06
#  mini 00:00:00:00:00:00
#  max  ff:ff:ff:ff:ff:ff
mac_check()
{
    local _mac=$1

    [ "$_mac" == "" ] && return 0

    if echo $_mac | grep -iqE "^([0-9A-F]{2}:){5}[0-9A-F]{2}$"
    then
         #echo mac address $mac format correct;
         return 0
    else
         echo "mac address \"$mac\" format(01:02:03:04:05:06) error";
         return 1
    fi

    return 0
}

#Mon Tue Wed Thu Fri Sat Sun
weekdays_check()
{
    local _weekdays=$1

    [ "$_weekdays" == "" ] && return 0

    if echo $_weekdays |grep -iqE "^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)( (Mon|Tue|Wed|Thu|Fri|Sat|Sun)){0,6}$"
    then
         #echo mac address $mac format correct;
         return 0
    else
         echo "weekdays \"$_weekdays\" format error";
         echo "  format \"Mon Tue Wed Thu Fri Sat Sun\",1-7 items"
         return 1
    fi

    return 0
}

pctl_config_entry_check()
{
    time_check "$time_seg" || return 1
    date_check "$start_date" || return 1
    date_check "$stop_date" || return 1
    mac_check "$src_mac"    || return 1
    weekdays_check "$weekdays" || return 1

    return 0;
}

pctl_config_entry_init()
{
    time_seg=""
    weekdays=""
    hostfile=""
    src_mac=""
    start_date=""
    stop_date=""
    disabled=""

    return
}

parentalctl_ipset_add() 
{
    local _ipsetname="$1"
    ipset list | grep $_ipsetname  > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        ipset create $_ipsetname  hash:ip > /dev/null 2>&1
    fi
}

#    [ -f $_pctl_ip_file ] && {
#        echo "add ips to ipset."
#        pctl_ipset_add_ip_file $_pctl_ip_file
#        hostlist_not_null=1
#        rm $_pctl_ip_file
#    }
pctl_ipset_add_ip_file()
{
    local _ipfile=$1
    local ipset_ip_name=$2

    [ -f $_ipfile ] || return

    ipset create $ipset_ip_name hash:net > /dev/null 2>&1

    echo "add ip to ipset $ipset_ip_name."
    cat $_ipfile | while read line
    do
        ipset add $ipset_ip_name $line
    done

}

local _ipset_cache_file="/tmp/parentalctl.ipset"
rm $_ipset_cache_file 2>/dev/null

parse_hostfile_one()
{
    local _hostfile=$1
    local _ipsetname=$2
    local _hostfile_tmp="/tmp/parentctl.tmp"
    local _tempfile_host="/tmp/parentctl_host.tmp"
    local _tempfile_ip="/tmp/parentctl_ip.tmp"

    rm $_hostfile_tmp 2>/dev/null
    rm $_tempfile_host 2>/dev/null
    rm $_tempfile_ip 2>/dev/null
    echo hostfileone"$1 $2"

    cat $_hostfile | awk '{print $2}' |uniq > $_hostfile_tmp

    ipset create ${_ipsetname}"_host" hash:net > /dev/null 2>&1    

    format2domain -f $_hostfile_tmp -o $_tempfile_host -i $_tempfile_ip
    if [ $? -ne 0 ]; then
        echo "format2domain error!"
        return 1
    fi
 
    cat $_tempfile_host | while read line
    do
        _has_pctl_file=1
        echo "$line ${_ipsetname}_host"
    done >> $_ipset_cache_file

    cat $_ipset_cache_file

    pctl_ipset_add_ip_file $_tempfile_ip $_ipsetname"_ip"

    rm $_tempfile_host 2>/dev/null
    rm $_tempfile_ip 2>/dev/null

    


    return 0;
}



parse_hostfile_finish()
{

    sort $_ipset_cache_file | uniq > $_ipset_cache_file".2"
    
    awk '{
        if($1==x) 
        {
            i=i","$2
        } 
        else 
        { 
            if(NR>1) { print i} ; 
            i="ipset=/"$1"/"$2 
        }; 
        x=$1;
        y=$2
    }
    END{print i}' $_ipset_cache_file".2" > $_pctl_file
    
    rm $_ipset_cache_file
    rm $_ipset_cache_file".2"
  


    return 0
}

#config summary 'D04F7EC0D55D'
#       option mac 'D0:4F:7E:C0:D5:5D'
#       option disabled '0'
#       option mode 'black'
parse_summary()
{
    local section="$1"
    local disabled=""
    local mode=""
    local device_id=""

    config_get src_mac    $section mac &>/dev/null;
    [ "$src_mac" == "" ] && return

    config_get disabled   $section disabled &>/dev/null;
    config_get mode   $section mode &>/dev/null;

    device_id=${src_mac//:/};
    eval x${device_id}_disabled=$disabled
    eval x${device_id}_mode=$mode

    return
}

#config rule parentalctl_1
#        option src              lan
#        option dest             wan
#        option src_mac          00:01:02:03:04:05
#        option start_date       2015-06-18
#        option stop_date        2015-06-20
#        option start_time       21:00
#        option stop_time        09:00
#        option weekdays         'mon tue wed thu fri'
#        option target           REJECT
parse_device()
{
    local section="$1"
    local _buffer=""

    local device_id=""
    
    pctl_config_entry_init

    config_get disabled   $section disabled &>/dev/null;
    [ "$disabled" == "1" ] && return

    config_get src_mac    $section mac &>/dev/null;
    [ "$src_mac" == "" ] && return ;

    config_get time_seg   $section time_seg &>/dev/null;
    config_get weekdays   $section weekdays &>/dev/null;
    config_get start_date $section start_date &>/dev/null;
    config_get stop_date  $section stop_date &>/dev/null;

    pctl_config_entry_check || return 0;

    #mac 01:02:03:04:05:06 ->> id 010203040506
    device_id=${src_mac//:/};

    summary_mode=$(eval echo \$x${device_id}_mode)
    summary_disabled=$(eval echo \$x${device_id}_disabled)


    echo  "disabled: $summary_disabled"
    [ "$summary_disabled" != "" -a "$summary_disabled" != 0 ] && return 0;

    echo  "mode: $summary_mode"
    [ "$summary_mode" != "" -a "$summary_mode" != "time" ] && return 0;

    for one_time_seg in $time_seg
    do
        start_time=$(echo $one_time_seg |cut -d - -f 1 2>/dev/null)
        stop_time=$(echo $one_time_seg |cut -d - -f 2 2>/dev/null)

        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}=rule"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.name='$rule_prefix'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.src='lan'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.dest='wan'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.extra='--kerneltz'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.target='REJECT'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.proto='TCP UDP'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.src_mac='$src_mac'"$'\n'

        #all day
        [ "$start_time" == "" -a "$stop_time" == "" ] && {
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.start_time='00:00'"$'\n'
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.stop_time='23:59'"$'\n'
        }

        #special time
        [ "$start_time" != "" -a "$stop_time" != "" ] && {
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.start_time='$start_time'"$'\n'
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.stop_time='$stop_time'"$'\n'
        }

        #everyday equals all 7 days in one week
        #mon tue wed thu fri sat sun
        [ "$weekdays" != "" ] && {
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.weekdays='$weekdays'"$'\n'
        }

        #once
        [ "$start_date" != "" -a "$stop_date" != "" ] && {
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.start_date='$start_date'"$'\n'
            append _buffer "set firewall.parentalctl_${device_id}_${time_cntr}.stop_date='$stop_date'"$'\n'
        }

        let time_cntr+=1
    done

    #echo "###########################################################sa"
    echo " $_buffer"
    echo "###########################################################"

#do not commit firewall
uci -q batch <<-EOF >/dev/null
    $_buffer
    commit firewall
EOF

    return 0;
}

parse_rule()
{
    local section="$1"
    local _buffer=""
    local device_id=""
    local _mode=""
    local _mode_extra=""

    pctl_config_entry_init

    config_get disabled   $section disabled &>/dev/null;
    [ "$disabled" == "1" ] && return

    config_get src_mac    $section mac &>/dev/null;
    [ "$src_mac" == "" ] && return ;

    config_get hostfiles  $section hostfile &>/dev/null;

    #mode = [white|black], if mode not set, means black
    config_get _mode $section mode &>/dev/null;

    [ "$_mode" == "white" ] && _mode_extra="!"

    pctl_config_entry_check || return 0;

    #mac 01:02:03:04:05:06 ->> id 010203040506
    device_id=${src_mac//:/};

    #summary_mode=$(eval echo \$x${device_id}_mode)
    summary_disabled=$(eval echo \$x${device_id}_disabled)

    [ "$summary_disabled" != "" ] && {
        [ "$summary_disabled" != 0 ] && return 0;
    }

    #[ "$summary_mode" != "" ] && {
    #    "$_mode" == "white"  && "$summary_mode" != "white" && return 0;
    #    "$_mode" == ""  && "$summary_mode" != "black" && return 0;
    #    "$_mode" == "black"  && "$summary_mode" != "black" && return 0;
    #}

    local _device_has_hostfile=0
    for hostfile in $hostfiles
    do
        [ ! -f "$hostfile" ] && continue

        parse_hostfile_one "$hostfile" "${ipset_name}${device_id}"

        _device_has_hostfile=1
        _has_pctl_file=1
    done

    [ $_device_has_hostfile == 1 ] && {
        append _buffer "set firewall.parentalctl_${device_id}_dns=redirect;"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.name='${rule_prefix}dns'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.src='lan';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.dest='wan';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.src_dport='53';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.dst_port='53';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.target='dnat';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.proto='TCP UDP';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_dns.src_mac='$src_mac';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host=rule;"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.name='${rule_prefix}host'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.src='lan';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.dest='wan';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.target='REJECT';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.proto='TCP UDP';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.src_mac='$src_mac';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_host.extra=' -m set $_mode_extra --match-set ${ipset_name}${device_id}_host dst ';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip=rule;"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.name='${rule_prefix}ip'"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.src='lan';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.dest='wan';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.target='REJECT';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.proto='TCP UDP';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.src_mac='$src_mac';"$'\n'
        append _buffer "set firewall.parentalctl_${device_id}_ip.extra=' -m set $_mode_extra --match-set ${ipset_name}${device_id}_ip dst ';"$'\n'
    }

    #echo "###########################################################sa"
    echo "host $_buffer"
    echo "###########################################################"

#do not commit firewall
uci -q batch <<-EOF >/dev/null
    $_buffer
    commit firewall
EOF

}	

pctl_fw_add_all()
{
    pctl_config_entry_init

    config_load "parentalctl"

    echo summary
    config_foreach parse_summary summary
    echo summaryxxx

    config_foreach parse_device device

    config_foreach parse_rule rule

    parse_hostfile_finish

#finally commit firewall here
uci -q batch <<-EOF >/dev/null
    commit firewall
EOF

    [ "$_has_pctl_file" == "0" -a -f "$_dnsmasq_file" ] && {
        rm $_dnsmasq_file 2>/dev/null
        dnsmasq_restart
    }

    [ "$_has_pctl_file" != "0" ] && {
        rm $_dnsmasq_file 2>/dev/null
        cp $_pctl_file $_dnsmasq_file
        dnsmasq_restart
    }

    return 0
}

pctl_ipset_delete_all()
{
    local pctl_ipset_list=$(ipset list -n| grep -E "^parentalctl_")
    local pctl_ipset=""
    for pctl_ipset in $pctl_ipset_list 
    do
        ipset flush $pctl_ipset
        ipset destroy $pctl_ipset # maybe failed, but doesn't matter
    done
}

pctl_fw_delete_all()
{
    local delete_cmd=$(uci show firewall | awk -F= '{if($1~/^firewall.'$rule_prefix'/)  print "del "$1 }')

uci -q batch <<-EOF >/dev/null
    $delete_cmd

    commit firewall
EOF

    return 0
}

pctl_iptables_delete_all()
{
    rule_num_set=$(iptables -L -t filter --line-number 2>/dev/null |grep $rule_prefix | awk '{print $1}' |sort -n -r )
    echo "$rule_num_set"	
    for rule_num in $rule_num_set
    do
        iptables -D zone_lan_forward $rule_num
    done
}

pctl_iptables_add_all()
{
    _tempfile="/tmp/"$rule_prefix"add_all.txt"

    pctl_iptables_delete_all

    fw3 print 2>/dev/null| grep $rule_prefix | awk '{gsub(/-A/,"-I",$4); print $0}'  > $_tempfile
    cat $_tempfile | while read line
    do
        echo $line
        $line
    done
   
}

pctl_flush()
{
    pctl_iptables_delete_all

    pctl_fw_delete_all

　　　　pctl_ipset_delete_all

    pctl_fw_add_all

    #iptables add all must run after fw add, because we need "fw3 print"
    pctl_iptables_add_all
    return 0
}

fw3lock="/var/run/fw3.lock"
trap "lock -u $fw3lock; exit 1" SIGHUP SIGINT SIGTERM
lock $fw3lock

pctl_flush

lock -u $fw3lock







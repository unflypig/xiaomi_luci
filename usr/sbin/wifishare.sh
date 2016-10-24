#!/bin/sh
# Copyright (C) 2015 Xiaomi
. /lib/functions.sh

network_name="guest"
section_name="wifishare"
redirect_port="8999"
whiteport_list="67 68 53"
#        option disbaled '0'
#        option auth_timeout '60'
#        option timeout '3600'
hasctf=$(uci get misc.quickpass.ctf 2>/dev/null)
hashwnat=$([ -f /etc/init.d/hwnat ] && echo 1)

macs_blocked=""

hwnat_start()
{
    echo start1
    [ "$hashwnat" != "1" ] && return;
    echo start2
uci -q batch <<-EOF >/dev/null
    set hwnat.switch.${section_name}=0
    commit hwnat
EOF
    /etc/init.d/hwnat start &>/dev/null
}

hwnat_stop()
{
    echo stop1
    [ "$hashwnat" != "1" ] && return;
    echo stop2

uci -q batch <<-EOF >/dev/null
    set hwnat.switch.${section_name}=1
    commit hwnat  
EOF
    /etc/init.d/hwnat stop &>/dev/null
}

fw3lock="/var/run/fw3.lock"

fw3_trylock()
{
    trap "lock -u $fw3lock; exit 1" SIGHUP SIGINT SIGTERM
    lock $fw3lock
    return;
}

fw3_unlock()
{
    lock -u $fw3lock
}


share_parse_global()
{
    local section="$1"
    auth_timeout=""
    timeout=""

    config_get disabled  $section disabled &>/dev/null;

    config_get auth_timeout  $section auth_timeout &>/dev/null;
    [ "$auth_timeout" == "" ] && auth_timeout=60

    config_get timeout  $section timeout &>/dev/null;
    [ "$timeout" == "" ] && timeout=86400
}


share_parse_block()
{
    config_get macs_blocked $section mac &>/dev/null;
}

share_fw_add_default()
{
    [ "$hasctf" == "1" ] && iptables -t mangle -I PREROUTING -i br-guest  -j SKIPCTF

    iptables -t nat -A zone_guest_prerouting -p tcp -m comment --comment ${section_name}_default -j REDIRECT --to-ports ${redirect_port}
    iptables -t nat -A zone_guest_prerouting -p udp -m comment --comment ${section_name}_default -j REDIRECT --to-ports ${redirect_port}

    for _port in ${whiteport_list}
    do
        iptables -t nat -I prerouting_guest_rule -p udp -m udp --dport ${_port} -m comment --comment ${section_name}_default -j ACCEPT
    done

    return
}

share_fw_add_device()
{
    local section="$1"
    local _src_mac=""
    local _start=""
    local _stop=""
    
    config_get disabled $section disabled &>/dev/null;
    [ "$disabled" == "1" ] && return

    config_get _start $section datestart &>/dev/null;
    [ "$_start" == "" ] && return

    config_get _stop $section datestop &>/dev/null;
    [ "$_stop" == "" ] && return

    config_get _src_mac $section mac &>/dev/null;
    [ "$_src_mac" == "" ] && return

    share_block_has_mac $_src_mac 
    [ $? -eq 1 ] && return

    #_is_timeout=$(echo $_stop | awk '{
    #    now=systime();
    #    gsub(/-|:|T/," ", $0);
    #    stop=mktime($0);
    #    if(now>stop)
    #    {
    #        print "yes"
    #    }
    #}')

    #[ "$_is_timeout" == "yes" ] && return

    name_dev="${section_name}_${_src_mac//:/}"

    share_access_remove $_src_mac

    iptables -I forwarding_rule  -i br-guest  -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP   >/dev/null 2>&1
    iptables -t nat -I prerouting_guest_rule -m mac --mac-source $_src_mac -m time --datestart $_start --datestop $_stop --kerneltz -m comment --comment ${name_dev} -j ACCEPT >/dev/null 2>&1

    return;
}

share_fw_add_device_all()
{
    config_load ${section_name}

    config_foreach share_fw_add_device device

    return;
}

share_fw_remove_all()
{

[ "$hasctf" == "1" ] && iptables -t mangle -D PREROUTING -i br-guest  -j SKIPCTF	

#    iptables -A forwarding_rule -i br-guest -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP
iptables-save  | awk  '/^-A forwarding_rule / && /-i br-guest/ && /-m mac --mac-source/ && /-m time --datestart/ && /-m comment --comment wifishare_/ {
                gsub("^-A", "-D")
                print "iptables -t filter "$0";"
}' |sh

iptables-save  | awk '/^-A zone_guest_prerouting|^-A prerouting_guest_rule/ && /--comment wifishare_/ {
                gsub("^-A", "-D")
                print "iptables -t nat "$0";"
}' |sh

    return
}

share_contrack_remove_perdevice()
{
    local section="$1"
    local _src_mac=""
    local _start=""
    local _stop=""

    config_get _src_mac $section mac &>/dev/null;
    [ "$_src_mac" == "" ] && return

    share_contrack_remove $_src_mac

    return
}

share_contrack_remove_all()
{
    config_load ${section_name}

    config_foreach share_contrack_remove_perdevice device

    return
}

share_contrack_remove()
{
    local _ip=$(arp | awk -v mac=$1 ' BEGIN{IGNORECASE=1}{if($3==mac) print $1;}' 2>/dev/null)

    [ "$_ip" == "" ] && return

#    /usr/sbin/conntrack -D -s $_ip  1>/dev/null 2>/dev/null

    echo $_ip > /proc/net/nf_conntrack
    return
}

share_block_table="wifishare_block"
share_block_table_input="wifishare_block_input"
share_block_has_mac()
{
    local _src_mac=$1
    local has_mac=""

    [ "$macs_blocked"  == "" ] && return 0

    has_mac=$(echo $macs_blocked | awk -v mac=$_src_mac '{for(i=1;i<=NF;i++) { if($i==mac) print "1"; break;} }')

    [ "$has_mac" != "" ] && return 1

    return 0;
}

share_block_add_default()
{
    share_block_remove_default

    iptables -t filter -N $share_block_table >/dev/null 2>&1
    iptables -t filter -I forwarding_rule -j $share_block_table >/dev/null 2>&1

    iptables -t filter -N $share_block_table_input >/dev/null 2>&1
    iptables -t filter -I INPUT -j $share_block_table_input >/dev/null 2>&1
    iptables -t filter -I $share_block_table_input  -i br-guest -p tcp -m tcp --dport 8999 -j ACCEPT >/dev/null 2>&1
}

share_block_remove_default()
{
    iptables -t filter -D forwarding_rule -j $share_block_table >/dev/null 2>&1
    iptables -t filter -F $share_block_table >/dev/null 2>&1
    iptables -t filter -X $share_block_table >/dev/null 2>&1

    iptables -t filter -D INPUT -j $share_block_table_input >/dev/null 2>&1
    iptables -t filter -F $share_block_table_input >/dev/null 2>&1
    iptables -t filter -X $share_block_table_input >/dev/null 2>&1
}

share_block_add_perdevice()
{
    local section="$1"
    local _src_mac=""

    config_get _mac_list $section mac &>/dev/null;

    for _src_mac in $_mac_list
    do
        name_dev="${section_name}_block_${_src_mac//:/}"

        echo "block device mac: $_src_mac, dev comment: $name_dev."

        share_access_remove $_src_mac

        iptables -t filter -A $share_block_table_input -i br-guest  -m mac --mac-source $_src_mac -m comment --comment ${name_dev} -j DROP >/dev/null
        iptables -t filter -A $share_block_table -i br-guest  -m mac --mac-source $_src_mac -m comment --comment ${name_dev} -j DROP >/dev/null
    done

    return;
}

share_block_apply()
{
    iptables -t filter -F $share_block_table >/dev/null 2>&1
    iptables -t filter -F $share_block_table_input >/dev/null 2>&1
    iptables -t filter -I $share_block_table_input  -i br-guest -p tcp -m tcp --dport 8999 -j ACCEPT >/dev/null 2>&1

    config_load ${section_name}

    config_foreach share_block_add_perdevice block    
}

share_block_remove_all()
{
    iptables -t nat -F $share_block_table >/dev/null 2>&1
}
#sns : string, 社交网络代码
#guest_user_id : string, 好友id
#extra_payload : string
#mac : 放行设备mac地址
share_access_prepare()
{
    local _src_mac=$1

    local _device_id=""
    local _current=""
    local _start=""
    local _stop=""

    [ "$_src_mac" == "" ] && return 1;

    share_block_has_mac $_src_mac 
    [ $? -eq 1 ] && return

    _device_id=${_src_mac//:/};
    _current=$(date  "+%Y-%m-%dT%H:%M:%S")
    _start=$(echo $_current | awk -v timeout=30 '{gsub(/-|:|T/," ",$0);now=mktime($0);now=now-timeout;print strftime("%Y-%m-%dT%H:%M:%S",now);return;}')
    _stop=$(echo $_current | awk -v timeout=$auth_timeout '{gsub(/-|:|T/," ",$0);now=mktime($0);now=now+timeout;print strftime("%Y-%m-%dT%H:%M:%S",now);return;}')

    local allowed_datestop=$(uci get ${section_name}.${_device_id}.datestop)
    [ "$allowed_datestop" != "" ] && {
        local time_now=$(echo $_current | tr -cd '[0-9]')
        local time_stop=$(echo $allowed_datestop | tr -cd '[0-9]')
        [ $time_stop -ge $time_now ]&& {
            return;
        }
    }

    local name_dev="${section_name}_${_device_id}"

    share_aceess_remove_iptables $_src_mac

    #iptables -I forwarding_rule -i br-guest -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP
    iptables -I forwarding_rule  -i br-guest  -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP
    iptables -t nat -I prerouting_guest_rule -m mac --mac-source $_src_mac -m time --datestart $_start --datestop $_stop --kerneltz -m comment --comment ${name_dev} -j ACCEPT

    return
}

#wifishare.D04F7EC0D55D=device
#wifishare.D04F7EC0D55D.disbaled=0
#wifishare.D04F7EC0D55D.mac=D0:4F:7E:C0:D5:5D
#wifishare.D04F7EC0D55D.state=auth
#wifishare.D04F7EC0D55D.start_date=2015-06-18
#wifishare.D04F7EC0D55D.timeout=3600
#wifishare.D04F7EC0D55D.sns=wechat
#wifishare.D04F7EC0D55D.guest_user_id=24214185
#wifishare.D04F7EC0D55D.extra_payload=payload test
share_access_allow()
{
    local _src_mac=$1
    local _device_id=""
    local _start=""
    local _stop=""

    [ "$_src_mac" == "" ] && return 1;

    share_block_has_mac $_src_mac 
    [ $? -eq 1 ] && return

    _device_id=${_src_mac//:/};
    _current=$(date  "+%Y-%m-%dT%H:%M:%S")
    _start=$(date  "+%Y-%m-%dT%H:%M:%S")
    _stop=$(echo $_start | awk -v timeout=$timeout '{gsub(/-|:|T/," ",$0);now=mktime($0);now=now+timeout;print strftime("%Y-%m-%dT%H:%M:%S",now);return;}')

    local allowed_datestop=$(uci get ${section_name}.${_device_id}.datestop)
    [ "$allowed_datestop" != "" ] && {
        local time_now=$(echo $_current | tr -cd '[0-9]')
        local time_stop=$(echo $allowed_datestop | tr -cd '[0-9]')
        [ $time_stop -ge $time_now ]&& {
            return;
        }
    }
    
    local name_dev="${section_name}_${_device_id}"

    share_aceess_remove_iptables $_src_mac

    iptables -I forwarding_rule -i br-guest -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP
    iptables -t nat -I prerouting_guest_rule -m mac --mac-source $_src_mac -m time --datestart $_start --datestop $_stop --kerneltz -m comment --comment ${name_dev} -j ACCEPT

uci -q batch <<-EOF >/dev/null
    set ${section_name}.${_device_id}=device
    set ${section_name}.${_device_id}.datestart="$_start"
    set ${section_name}.${_device_id}.datestop="$_stop"
    set ${section_name}.${_device_id}.mac="$_src_mac"
EOF
    uci commit ${section_name}

}

share_aceess_remove_iptables()
{
    local _src_mac=$1
    local _device_id=""

    [ "$_src_mac" == "" ] && return 1;

    _device_id=${_src_mac//:/};

#    iptables -A forwarding_rule -i br-guest -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP
iptables-save  | awk -v mac=$_src_mac '/^-A forwarding_rule / && /-i br-guest/ && /-m mac --mac-source/ && /-m time --datestart/ && /-m comment --comment wifishare_([0-9A-F]+)/ {
    i = 1;
    while ( i <= NF )
    {
        if($i~/--mac-source/)
        {
            if($(i+1)==mac)
            {
                gsub("^-A", "-D")
                print "iptables -t filter "$0";"
            }
        }
        i++
    }
}' |sh

iptables-save  | awk -v mac=$_src_mac '/^-A prerouting_guest_rule/ && /-m mac --mac-source/ && /-m time --datestart/ && /--datestop/ && /-m comment --comment wifishare_([0-9A-F]+)/ {
    i = 1;
    while ( i <= NF )
    {
        if($i~/--mac-source/)
        {
            if($(i+1)==mac)
            {
                gsub("^-A", "-D")
                print "iptables -t nat "$0";"
            }
        }
        i++
    }
}' |sh

   return;
}

share_access_remove()
{
    local _src_mac=$1

    share_aceess_remove_iptables $_src_mac

    share_contrack_remove $_src_mac
    
    return
}

timeout_devname_list=""
timeout_time=""
share_timeout_gettime()
{
   timeout_time=$(echo 1|   awk '{now=systime(); print now }')
}

share_access_timeout_iptables()
{

   local _timeout_range=$1
   
   [ -z $_timeout_range ] && _timeout_range=$timeout
   [ "$_timeout_range" -le 3600 ] && _timeout_range=3600

   let _timeout_range+=30
#   iptables -I forwarding_rule -i br-guest -m mac --mac-source $_src_mac -m time --datestart $_stop --kerneltz -m comment --comment ${name_dev} -j DROP
#   iptables -t nat -I prerouting_guest_rule -m mac --mac-source $_src_mac -m time --datestart $_start --datestop $_stop --kerneltz -m comment --comment ${name_dev} -j ACCEPT

#timeout_time=$(echo 1|   awk '{now=systime(); print now }') ;auth_timeout=60
#    echo timeout_range"$_timeout_range"

iptables-save  | awk -v  now=$timeout_time -v auth_timeout=$auth_timeout -v range=$_timeout_range '/^-A prerouting_guest_rule/ && /-m mac --mac-source/ && /-m time --datestart/ && /--datestop/ && /-m comment --comment wifishare_([0-9A-D]+)/ {
    i = 1;
    while ( i <= NF )
    {
        if($i~/--mac-source/)
        {
            need_remove=0;
            mac=$(i+1);
            device_id=mac;
            gsub(":", "", device_id);
        }

        if($i~/--datestart/)
        {
            datestart=$(i+1)
            gsub(/-|:|T/," ", datestart);
            start=mktime(datestart);
        }

        if($i~/--datestop/)
        {
            datestop=$(i+1);
            filter_datestart=datestop;
            gsub(/-|:|T/," ", datestop);
            stop=mktime(datestop);
            if(now>stop)
            {
                need_remove=1;
            } 
            else if (now-start>range)
            {
                need_remove=1;
            }

        }

        if($i~/--comment/)
        {
            comment=$(i+1);
            if(need_remove == 1)
            {  
                gsub("^-A", "-D");
                print "iptables -D forwarding_rule -i br-guest -m mac --mac-source "mac" -m time --datestart "filter_datestart" --kerneltz -m comment --comment "comment" -j DROP";
                print "iptables -t nat "$0;
            }
        }

        i++
    }
} '  |sh

   return
}

share_access_timeout_config_perdevice()
{
    local _mac=""
    local _datestop=""
    local _stop=""
    local _start=""

    local need_remove=0

    config_get _mac $section mac &>/dev/null;
    config_get _datestop $section datestop &>/dev/null;
    config_get _datestart $section datestart &>/dev/null;

    _stop=$(echo $_datestop |awk '{gsub(/-|:|T/," ", $O); seconds=mktime($0); print seconds;}')
    _start=$(echo $_datestart |awk '{gsub(/-|:|T/," ", $O); seconds=mktime($0); print seconds;}')

    [ "$_timeout_range" != "" ] && {
        local _start_timeout
        let _start_timeout=$timeout_time-$_start

        echo $_start_timeout
        [  $_start_timeout -gt $timeout_range ] && {
            need_remove=1
        }
    }

    [ $_stop -lt $timeout_time ] && {
        need_remove=1;
    }
    
    [ "$need_remove" == "1" ] && {
        macsets_timeout="$macsets_timeout $_mac"
    }
}

share_access_timeout_uci()
{
    local macsets_timeout=""
    timeout_range=$1

    local onemac=""
    config_load "${section_name}"

    config_foreach share_access_timeout_config_perdevice device

    [ "$macsets_timeout"!=="" ] && {
        for onemac in $macsets_timeout
        do
           local _device_id=""
            _device_id=${onemac//:/}
            share_contrack_remove ${onemac}
            uci delete ${section_name}.${_device_id}
        done
        uci commit ${section_name}
    }
}

share_access_timeout()
{
    #get current time
    share_timeout_gettime

    #remove iptables
    share_access_timeout_iptables $1

    share_access_timeout_uci $1
    return
}

share_reload()
{
    share_fw_remove_all

    share_fw_add_default
    
    share_fw_add_device_all

    share_block_remove_default

    share_block_add_default

    share_block_apply
    return
}

share_start()
{

    local name_default="${section_name}_default"

    has_wifishare=$(uci get firewall.wifishare.path)
  
    [ "$has_wifishare" == "/usr/sbin/wifishare.sh reload" ]  && return

    #share_stop
    #share_fw_add_default
    #share_block_add_default
    #share_block_apply
    share_reload

uci -q batch <<-EOF >/dev/null
    set firewall.${section_name}=include
    set firewall.${section_name}.path="/usr/sbin/wifishare.sh reload"
    set firewall.${section_name}.reload=1
EOF

    uci commit firewall

    return
}

share_stop()
{
    local delete_cmd=$(uci show firewall | awk -F= '{if($1~/^firewall.'$section_name'/)  print "del "$1 }')

    share_contrack_remove_all

uci -q batch <<-EOF >/dev/null
    $delete_cmd
EOF
    uci commit firewall

    share_fw_remove_all

    share_block_remove_all

    share_block_remove_default
    return
}

guest_network_judge()
{
    local _encryption=$(uci get wireless.guest_2G.encryption 2>/dev/null)
    local _ssid=$(uci get wireless.guest_2G.ssid 2>/dev/null)
    local _disabled=$(uci get wireless.guest_2G.disabled 2>/dev/null)

    [ "$_disabled" == 1 ] && exit 1
    [ "$_ssid" == "" ] && exit 1
    [ "$_encryption" != "none" ] && exit 1

    return
}

share_usage()
{
    echo "$0:"
    echo "    on     : start guest share, guest must open and encryption is none."
    echo "        format: $0 on"
    echo "    off    : stop guest share."
    echo "        format: $0 off"
    echo "    block_apply: apply block list."
    echo "        format: $0 block_apply"
    echo "    prepare: prepare for guest client, allow data transfer for 60 seconds."
    echo "        format: $0 prepare mac_address"
    echo "        eg    : $0 prepare 01:12:34:ab:cd:ef"
    echo "    allow  : access allow, default 1 day."
    echo "        format: $0 allow mac_address"
    echo "        eg    : $0 allow 01:12:34:ab:cd:ef"
    echo "    deny   : access deny, default 1 day."
    echo "        format: $0 deny mac_address"
    echo "        eg    : $0 deny 01:12:34:ab:cd:ef"
    echo "    timeout: remove timeout item in firewall iptables wifishare."
    echo "        format: $0 timeout"
    echo "    other: usage."

    return;
}

OPT=$1

config_load "${section_name}"

config_foreach share_parse_global global

config_foreach share_parse_block block
#main
case $OPT in
    on)
        guest_network_judge

        hwnat_stop

        fw3_trylock
        share_start
        fw3_unlock
        return $?
    ;;

    off)

        fw3_trylock
        share_stop
        fw3_unlock

        hwnat_start
        return $?
    ;;

    prepare)
        local _dev_mac=$(echo "$2"| tr '[a-z]' '[A-Z]')
        fw3_trylock
        share_access_prepare $_dev_mac
        share_access_timeout
        fw3_unlock
        return $?
    ;;

    allow)
        local _dev_mac=$(echo "$2"| tr '[a-z]' '[A-Z]')
        fw3_trylock
        share_access_allow $_dev_mac
        share_access_timeout
        fw3_unlock
        return $?
    ;;

    deny)
        local _dev_mac=$(echo "$2"| tr '[a-z]' '[A-Z]')
        fw3_trylock
        share_access_remove $_dev_mac
        share_access_timeout
        fw3_unlock
        return $?
    ;;

    block_apply)
        fw3_trylock
        share_block_apply
        fw3_unlock
        return $?
    ;;

    timeout)
        local _timeout=$(echo $2 | sed 's/[^0-9]//g')
        fw3_trylock
        share_access_timeout $_timeout
        fw3_unlock
        return $?
    ;;

    reload)
        share_reload
        return $?
    ;;

    *)
        share_usage
        return 0
    ;;
esac



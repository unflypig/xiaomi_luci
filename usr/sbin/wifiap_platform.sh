#!/bin/sh
# Copyright (C) 2014 Xiaomi


. /usr/sbin/wifiap_common.sh

###################################################################################################
#
#     r1c process
#
###################################################################################################

wifiap_apcli0_status()
{
    local ssid_connected=""
    local reason_disconnect=""

    for i in `seq 10` 
    do 
        ssid_connected=`iwpriv apcli0 Connstatus |awk '/SSID:/ {for(i=1;i<=NF;i++) if($i ~ /^SSID:/) print substr($i,6);}'`
        if [ ! -z "$ssid_connected" ] 
        then 
            wifiap_logger "root AP $ssid_connected connected."
            return 0
        fi
        sleep $i
    done

    reason_disconnect=`iwpriv apcli0 Connstatus |awk -F ':' '/ Disconnect reason =/ {for(i=1;i<=NF;i++) if($i ~ /^ Disconnect reason =/) print substr($i,22);}'`

    wifiap_logger "Can't connect Root AP, reason: $reason_disconnect."

    return 1
}

wifiap_apcli0_stop()
{
    iwpriv apcli0 set ApCliAutoConnect=0
    iwpriv apcli0 set ApCliEnable=0
    ifconfig apcli0 down
    
    return 0
}

#ApCliEnable 1为开启apcli，0为关闭
#ApCliSsid 需要上联的ap ssid
#ApCliAuthMode 上级ap的认证方式，可选项为：
#WEPAUTO SHARED WPAPSK WPA2PSK OPEN
#请根据实际上级ap认证方式填入此参数
#ApCliEncrypType 上级ap的加密方式，可选项为：
#WEP TKIP AES
#example:        
#12 <00zdw> 00:90:4c:23:45:78 WPA1PSKWPA2PSK/TKIPAES 94 11b/g/n NONE In R1D YES
#iwpriv wl1 set Channel=12
#ifconfig apcli0 up
#iwpriv apcli0 set ApCliEnable=0
#iwpriv apcli0 set ApCliAuthMode=WPA2PSK
#iwpriv apcli0 set ApCliEncrypType=AES
#iwpriv apcli0 set ApCliSsid="00zdw"
#iwpriv apcli0 set ApCliWPAPSK="12345678"
#iwpriv apcli0 set ApCliAutoConnect=1
wifiap_apcli0_start()
{
    wifiap_logger "apcli0 start."

    iwpriv wl1 set Channel=$global_channel
    ifconfig apcli0 up
    iwpriv apcli0 set ApCliEnable=0
    iwpriv apcli0 set ApCliSsid="$global_ssid"

    echo "encode type: $global_enctype"

    if [ "$global_enctype" == "AES" -o "$global_enctype" == "TKIPAES" ]
    then
        #-- WPA2PSK/WPA1PSK
        #iwpriv apcli0 set ApCliAuthMode=$global_encryption
	iwpriv apcli0 set ApCliAuthMode=WPA2PSK
        iwpriv apcli0 set ApCliEncrypType=AES
        iwpriv apcli0 set ApCliWPAPSK="$global_password"
    elif [ "$global_enctype" == "TKIP" ]
    then
        #-- WPA2PSK/WPA1PSK
        #iwpriv apcli0 set ApCliAuthMode=$global_encryption
        iwpriv apcli0 set ApCliAuthMode=WPA2PSK
        iwpriv apcli0 set ApCliEncrypType=TKIP
        iwpriv apcli0 set ApCliWPAPSK="$global_password"
    elif [ "$global_enctype" == "WEP" ]
    then
        #-- WEP
        iwpriv apcli0 set ApCliAuthMode=OPEN
        iwpriv apcli0 set ApCliEncrypType=WEP
        iwpriv apcli0 set ApCliDefaultKeyID=1
        iwpriv apcli0 set ApCliKey1="$global_password"
    elif [ "$global_enctype" == "NONE" ]
    then
        #-- NONE
        iwpriv apcli0 set ApCliAuthMode=OPEN
        iwpriv apcli0 set ApCliEncrypType=NONE
    fi

    iwpriv apcli0 set ApCliAutoConnect=1

    wifiap_logger "apcli0 finish."
    return 0
}


#wifiIndex, ssid, password, encryption, channel, txpwr, hidden, on, bandwidth)
#
#2G
#(1, $wifissid,        $wifipawd, $wifienc, $global_channel, nil, "0", 1, global_bandwidth) 
#
#5g
#(2, $wifissid.."_5G", $wifipawd, $wifienc, nil, nil, "0", 1, nil)
wifiap_device_find()
{
    return 0;
}

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

wifiap_interface_add()
{
     uci add wireless wifi-iface 1>/dev/null 2>/dev/null
     uci show wireless |awk -F'\[|\]' 'BEGIN{ max=0; }{if($1~/wireless.@wifi-iface/ && $2>max) { max=$2;}} END{ printf("%d\n",max); }'
     
     return 0
}

wifiap_interface_set()
{
    wifiap_logger "interface set."
    
    local config_enctype=`wifiap_enctype_translate $global_enctype`

    local autoch=0
    [ $global_channel == "0" ] && autoch=2;

    #default interface num 1
    #2.4G interface setup
    device_name=`uci get misc.wireless.if_2G`
    iface_no=`wifiap_interface_find_by_device $device_name`
    [ "$iface_no" == "" ] && return 1
    
uci -q batch <<-EOF >/dev/null
    set wireless.$device_name.channel=$global_channel
    set wireless.$device_name.autoch=$autoch
    set wireless.$device_name.bw=$global_bandwidth
    set wireless.$device_name.disabled="0"

    delete wireless.@wifi-iface[$iface_no].disabled
    set wireless.@wifi-iface[$iface_no].ssid=$global_ssid
    set wireless.@wifi-iface[$iface_no].encryption=$config_enctype
    set wireless.@wifi-iface[$iface_no].key=$global_password
    set wireless.@wifi-iface[$iface_no].hidden=0
    set wireless.@wifi-iface[$iface_no].macfilter=disabled
EOF

    [ $global_encryption == "none" ] && uci set wireless.@wifi-iface[$iface_no].key=""
    [ $global_encryption == "wep-open" ] && { uci set wireless.@wifi-iface[$iface_no].key1="s:"$global_password; uci set wireless.@wifi-iface[$iface_no].key=1; }

    #default interface num 0
    #5G interface setup
    device_name=`uci get misc.wireless.if_5G`
    iface_no=`wifiap_interface_find_by_device $device_name`
    [ "$iface_no" == "" ] && return 1

uci -q batch <<-EOF >/dev/null
    set wireless.$device_name.disabled="0"

    delete wireless.@wifi-iface[$iface_no].disabled
    set wireless.@wifi-iface[$iface_no].ssid=$global_ssid"_5G"
    set wireless.@wifi-iface[$iface_no].encryption=$config_enctype
    set wireless.@wifi-iface[$iface_no].key=$global_password
    set wireless.@wifi-iface[$iface_no].hidden=0
    set wireless.@wifi-iface[$iface_no].macfilter=disabled
EOF
    [ $global_encryption == "none" ] && uci set wireless.@wifi-iface[$iface_no].key=""
    [ $global_encryption == "wep-open" ] && { uci set wireless.@wifi-iface[$iface_no].key1="s:"$global_password; uci set wireless.@wifi-iface[$iface_no].key=1; }

    uci commit wireless

    return 0
}

wifiap_bridge_client_set_r1cm()
{
    local device_name=`uci get misc.wireless.if_2G`
    local config_enctype=`wifiap_enctype_translate $global_enctype`
    local iface_client=0    

    wifiap_logger "bridge client set."
      
    iface_client=`wifiap_interface_add`
    [ "$iface_client" == "" ] && return 1;
    echo "###################$iface_client"

uci -q batch <<-EOF >/dev/null
    set wireless.@wifi-iface[$iface_client].device="$device_name"
    set wireless.@wifi-iface[$iface_client].disabled="0"
    set wireless.@wifi-iface[$iface_client].encryption="$global_encryption"
    
    set wireless.@wifi-iface[$iface_client].enctype="$global_enctype"
    set wireless.@wifi-iface[$iface_client].ifname="apcli0"
    set wireless.@wifi-iface[$iface_client].key="$global_password"
    set wireless.@wifi-iface[$iface_client].mode="sta"
    set wireless.@wifi-iface[$iface_client].network="lan"
    set wireless.@wifi-iface[$iface_client].ssid="$global_ssid"
    commit wireless
EOF
    
    return 0;
}

#--- model: 0/1  black/white list
wifiap_macfilter_disable_r1cm()
{
    wifiap_logger "macfilter disable."

uci -q batch <<-EOF >/dev/null
    delete wireless.@wifi-iface[0].maclist
    delete wireless.@wifi-iface[1].maclist
    commit wireless
EOF

    iwpriv wl0 set ACLClearAll=1
    iwpriv wl1 set ACLClearAll=1
    iwpriv wl0 set AccessPolicy=0
    iwpriv wl1 set AccessPolicy=0
    return 0;
}

# r1cm ap scan
# $1 ssid 
# $2 ssid password
wifiap_scan_process()
{
    #local ssid=$1
    #local password=$2
    global_ssid="$1"
    global_password="$2"
    #wifiap_wifi_open

    wifiap_logger "root ap <$global_ssid> scan begin."

    rm -f $WIFIAP_SCANLIST_FILE

    #sitesurvey can be NULL
    iwpriv wl1 set SiteSurvey="$global_ssid"
 
    sleep 1

    #scan 3 times
    for i in `seq 3`
    do 
        iwpriv wl1 get_site_survey |awk '{if(NR>2&&$0 !~/^$/) print $0}' >>$WIFIAP_SCANLIST_FILE
        sleep 1
    done
    
    cat ${WIFIAP_SCANLIST_FILE} |sort -u >${WIFIAP_SCANLIST_FILE}".bak"
    mv ${WIFIAP_SCANLIST_FILE}".bak" ${WIFIAP_SCANLIST_FILE}
    
    #item format:
    #["mac"]         = XQFunction.macFormat(mac),
    # this format come from cmd "iwpriv wl1 get_site_survey" out put, 
    #it maybe different in another plantform
    #   1       2          3                 4        5       6       7     8  9  10
    #   channel ssid       mac               security signal  wmode   extch nt xm wps   
    #eg:channel ssid       mac               security signal  wmode   extch nt xm wps
    #   1       <MIOffice> 94:b4:0f:8d:a3:40 WPA2/AES 7       11b/g/n NONE  In NO

    #local item=`awk '{if($2 ~/'"<"$global_ssid">"'/) {print $0; exit;}}'  ${WIFIAP_SCANLIST_FILE} `
    local item=`awk '{
        ssid=substr($0, 5, 32); 
        gsub(/^ *<|> *$/,"", ssid); 
        if(ssid~/'"$global_ssid"'/)
        {
           print $0; 
           exit;
        }
        }'  ${WIFIAP_SCANLIST_FILE} `
    [ "$item" == "" ] && return 1   

    #Get root AP wireless parameters.
    wifiap_logger "root ap <$global_ssid> found."

    global_channel=`echo $item | awk '{print $1}'`

    local security=`echo $item | awk '{print substr($0, 58, 23)}'`
    global_encryption=`echo $security | awk -F '/' '{print $1}'`
    global_enctype=`echo $security | awk -F '/' '{print $2}'`

    local extch=`echo $item | awk '{print substr($0, 95, )}'` 
    [ $extch != "NONE" ] && global_bandwidth="40"
    [ $extch == "NONE" ] && global_bandwidth="20"

    [ $global_encryption == "WPA1WPA2PSK" ]  && global_encryption="WPA2PSK"
  
    wifiap_parameter_print
    wifiap_parameter_check || { wifiap_logger "root ap $global_ssid scan parameter check fail."; return 1; }

    wifiap_logger "root ap $global_ssid scan finish."
    return 0;    
}


wifiap_connect_fail_process()
{
    apmode=$1

    /sbin/wifi >/dev/null 2>/dev/null;

    [ $apmode != "" ] && return;

    iwpriv apcli0 set ApCliAutoConnect=0
    iwpriv apcli0 set ApCliEnable=0
    ifconfig apcli0 down

    wifiap_fail_process

    return;
}

# r1cm ap connect
# $1 ssid 
# $2 ssid password
wifiap_connect_process()
{
    local encaped_ssid=""
    local encaped_password=""

    [ -z $1 ] || encaped_ssid=`escape_string $1`
    [ -z $2 ] || encaped_password=`escape_string $2`

    [ $encaped_ssid == "" ] && return 1;

    wifiap_logger "connect root ap ssid:\"$encaped_ssid\" password:\"$encaped_password\"."

    local apmode=`uci get xiaoqiang.common.NETMODE 2>/dev/null`
    
    wifiap_scan "$encaped_ssid" "$encaped_password" 
    [ $? != "0" ] && return 1;
 
    [ -z $apmode ] || wifiap_apcli0_stop

    wifiap_apcli0_start
   
    sleep 2
    wifiap_apcli0_status
    [ $? == '0' ] || { wifiap_connect_fail_process $apmode; return 1; }
        
    sleep 2;
    #UI manage IP
    dhcp_apclient.sh start || dhcp_apclient.sh start br-lan
    [ $? == '0' ] || { wifiap_connect_fail_process $apmode; return 1; }

    wifiap_parameter_save
   
    return 0;
}

# r1cm ap open
# 
wifiap_open_process()
{

uci -q batch <<-EOF >/dev/null
    set xiaoqiang.common.NETMODE=wifiapmode
    set network.wan.auto=0
    commit network
    delete dhcp.lan
    delete dhcp.wan
    commit dhcp
EOF

    wifiap_interface_set ||  { wifiap_fail_process; return 1; }

    wifiap_bridge_client_set_r1cm ||  { wifiap_fail_process; return 1; }

    wifiap_macfilter_disable_r1cm ||  { wifiap_fail_process; return 1; }


    sleep 10;

    /etc/init.d/network restart 

    wifiap_service_restart

    /etc/init.d/miqos stop

    wifiap_lan_restart

    return 0;
}

# r1cm ap close
# config backupfile /etc/config/.network.mode.router is create by dhcp_apclient.sh:router_config_backup()
#
wifiap_close_process()
{
    wifiap_apcli0_stop

    wifiap_service_restart
 
    wifiap_lan_restart

    return 0;
}


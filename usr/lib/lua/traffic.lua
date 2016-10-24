-- called by trafficd from c
-- yubo@xiaomi.com
-- 2014-09-05

local dev
local equ
local dbDict
local dhcpDict


function get_hostname_init()
	dev = require("xiaoqiang.util.XQDeviceUtil")
	equ = require("xiaoqiang.XQEquipment")
	dbDict = dev.getDeviceInfoFromDB()
	dhcpDict = dev.getDHCPDict()
end

function get_hostname(mac)
	local hostname
	if dbDict[mac] and dbDict[mac]['nickname'] ~= '' then
		hostname = dbDict[mac]['nickname']
	else
		local dhcpname = dhcpDict[mac] and dhcpDict[mac]['name'] or ''
		if dhcpname == '' then
			local t = equ.identifyDevice(mac, '')
			hostname = t.name
		else
			local t = equ.identifyDevice(mac, dhcpname)
			if t.type.p + t.type.c > 0 then
				hostname = t.name
			else
				hostname = dhcpname
			end
		end
	end
	return hostname == '' and mac or hostname
end

function get_wan_dev_name()
	local ubus = require ("ubus")
	local conn = ubus.connect()
	if not conn then
		elog("Failed to connect to ubusd")
	end
	local status = conn:call("network.interface.wan", "status",{})
	conn:close()
	return (status.l3_device and status.l3_device) or status.device
end

function get_lan_dev_name()
	local ubus = require ("ubus")
	local conn = ubus.connect()
	if not conn then
		elog("Failed to connect to ubusd")
	end
	local status = conn:call("network.interface.lan", "status",{})
	conn:close()
	return (status.l3_device and status.l3_device) or status.device
end

function get_ap_hw()
	local pp = io.popen("uci get xiaoqiang.common.NETMODE")
	local model = pp:read("*line")
	pp:close()

	if model == "wifiapmode" then
		pp = io.popen("ifconfig  apcli0 | grep HWaddr")
		local data = pp:read("*line")
		local _, _, hw = string.find(data,'HWaddr%s+([0-9A-F:]+)%s*$')
		pp:close()
		return hw
	end
	if model ==  "lanapmode" then
		pp = io.popen("ifconfig  br-lan | grep HWaddr")
		local data = pp:read("*line")
		local _, _, hw = string.find(data,'HWaddr%s+([0-9A-F:]+)%s*$')
		pp:close()
		return hw
	end
	return nil
end

function trafficd_lua_done()
	os.execute("killall -q -s 10 noflushd");
end

function get_description()
	local sys = require("xiaoqiang.util.XQSysUtil")
	return sys.getRouterInfo()
end

function get_version()
	local sys = require("xiaoqiang.util.XQSysUtil")
	return sys.getRomVersion()
end

function trafficd_lua_ecos_pair_verify(repeater_token)
    local code
    local token
    local ssid
    local ssid_pwd
    local ssid_type
    local ssid_hidden
    local bssid
    local device_id
    local cjson=require("json")
    local pp
    local ifname
    local ifname_tmp
    local wl_index = 1
    local wl_cnt
    local i

    pp = io.popen("uci get misc.wireless.ifname_2G")
    ifname = pp:read("*line")
    pp:close()

    pp = io.popen("uci get misc.wireless.wl_if_count")
    wl_cnt = pp:read("*line")
    pp:close()

    if ifname ~= nil and wl_cnt ~= nil then
        wl_cnt = tonumber(wl_cnt)
        if wl_cnt ~= nil then
            for i=0,wl_cnt,1 do
                pp = io.popen(string.format("uci get wireless.@wifi-iface[%d].ifname",i))
                ifname_tmp = pp:read("*line")
                pp:close()
                if ifname_tmp == ifname then
                    wl_index = i
                    break
                end
            end
        end
    end

    os.execute(string.format("/usr/sbin/ecos_pair_verify -i %d -e %s ",wl_index,repeater_token))
    file = io.open("/tmp/ecos.log","r")
    if file ~= nil then
        for line in file:lines() do
            local tt = cjson.decode(line)
            code = tt['code']
            token = tt['token']
            ssid = tt['ssid']
            ssid_pwd = tt['ssid_pwd']
            ssid_type = tt['ssid_type']
            ssid_hidden = tt['ssid_hidden']
            bssid = tt['bssid']
            device_id = tt['device_id']
            os.execute("logger " .. code)
            os.execute("logger " .. token)
            os.execute("logger " .. ssid)
            os.execute("logger " .. ssid_pwd)
            os.execute("logger " .. ssid_type)
            os.execute("logger " .. ssid_hidden)
            os.execute("logger " .. bssid)
            os.execute("logger " .. device_id)
        end
        file:close()
    end
    return code,token,ssid,ssid_pwd,ssid_type,ssid_hidden,bssid,device_id
end

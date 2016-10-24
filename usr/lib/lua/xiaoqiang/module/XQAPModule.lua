module ("xiaoqiang.module.XQAPModule", package.seeall)

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")
local LuciUtil = require("luci.util")

function setLanAPMode()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local messagebox = require("xiaoqiang.module.XQMessageBox")
    local apmode = XQFunction.getNetMode() ~= nil
    local olanip = XQLanWanUtil.getLanIp()
    if not apmode then
        local uci = require("luci.model.uci").cursor()
        local lan = uci:get_all("network", "lan")
        uci:section("backup", "backup", "lan", lan)
        uci:commit("backup")
    end
    os.execute("/usr/sbin/ap_mode.sh connect >/dev/null 2>/dev/null")
    local nlanip = XQLanWanUtil.getLanIp()
    if olanip ~= nlanip then
        local XQSync = require("xiaoqiang.util.XQSynchrodata")
        messagebox.removeMessage(4)
        XQWifiUtil.setWiFiMacfilterModel(false)
        XQWifiUtil.setGuestWifi(1, nil, nil, nil, 0, nil)
        XQFunction.setNetMode("lanapmode")
        XQSync.syncApLanIp(nlanip)
        return nlanip
    end
    return nil
end

function disableLanAP()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local uci = require("luci.model.uci").cursor()
    local lanip = uci:get("backup", "lan", "ipaddr")
    XQFunction.setNetMode(nil)
    return lanip
end

function lanApServiceRestart(open, fork)
    local cmd1 = [[
        sleep 7;
        /usr/sbin/ap_mode.sh open;
        /etc/init.d/trafficd restart;
        /usr/sbin/shareUpdate -b >/dev/null 2>/dev/null;
        /etc/init.d/xqbc restart
    ]]
    local cmd2 = [[
        sleep 5;
        /usr/sbin/ap_mode.sh close;
        /etc/init.d/trafficd restart;
        /usr/sbin/shareUpdate -b >/dev/null 2>/dev/null;
        /etc/init.d/xqbc restart
    ]]
    if fork then
        if open then
            XQFunction.forkExec(cmd1)
        else
            XQFunction.forkExec(cmd2)
        end
    else
        if open then
            os.execute(cmd1)
        else
            os.execute(cmd2)
        end
    end
end

----------------------------------------------------------------
----------------------------------------------------------------

function connectionStatus()
    local connection = LuciUtil.exec("iwpriv apcli0 Connstatus")
    if connection:match("SSID:") then
        return true, connection
    else
        return false, connection
    end
end

function backupConfigs()
    local uci = require("luci.model.uci").cursor()
    local wifi = require("xiaoqiang.util.XQWifiUtil")
    local xqsys = require("xiaoqiang.util.XQSysUtil")

    local lan = uci:get_all("network", "lan")
    local dhcplan = uci:get_all("dhcp", "lan")
    local dhcpwan = uci:get_all("dhcp", "wan")

    uci:delete("backup", "lan")
    uci:delete("backup", "wifi1")
    uci:delete("backup", "wifi2")
    uci:delete("backup", "dhcplan")
    uci:delete("backup", "dhcpwan")

    uci:section("backup", "backup", "lan", lan)
    uci:section("backup", "backup", "dhcplan", dhcplan)
    uci:section("backup", "backup", "dhcpwan", dhcpwan)
    uci:commit("backup")

    if xqsys.getInitInfo() then
        wifi.backupWifiInfo(1)
        wifi.backupWifiInfo(2)
    end
end

function setWanAuto(auto)
    local LuciNetwork = require("luci.model.network").init()
    local wan = LuciNetwork:get_network("wan")
    wan:set("auto", auto)
    LuciNetwork:commit("network")
end

function disableWifiAPMode()
    local wifi = require("xiaoqiang.util.XQWifiUtil")
    local uci = require("luci.model.uci").cursor()

    local lan = uci:get_all("backup", "lan")
    local inf = uci:get_all("backup", "wifi1")
    local inf2 = uci:get_all("backup", "wifi2")
    local dhcplan = uci:get_all("backup", "dhcplan")
    local dhcpwan = uci:get_all("backup", "dhcpwan")

    if inf and inf2 and inf.bsd and inf.bsd == "1" then
        inf2.ssid = inf.ssid
        inf2.password = inf.password
        inf2.encryption = inf.encryption
        inf2.on = inf.on
    end
    if inf and inf2 and not inf.bsd then
        inf["bsd"] = "0"
        inf2["bsd"] = "0"
    end

    local lanip, ssid
    uci:delete("network", "lan")
    if lan then
        uci:section("network", "interface", "lan", lan)
        lanip = lan.ipaddr
    else
        uci:section("network", "interface", "lan", NETWORK_LAN)
        lanip = NETWORK_LAN.ipaddr
    end
    if dhcplan then
        uci:section("dhcp", "dhcp", "lan", dhcplan)
    end
    if dhcpwan then
        uci:section("dhcp", "dhcp", "wan", dhcpwan)
    end
    uci:commit("dhcp")
    uci:commit("network")

    setWanAuto(nil)

    wifi.deleteWifiBridgedClient(1)
    if inf then
        ssid = inf.ssid
        wifi.setWifiBasicInfo(1, inf.ssid, inf.password, inf.encryption, tostring(inf.channel), inf.txpwr, tostring(inf.hidden), tonumber(inf.on) == 1 and 0 or 1, inf.bandwidth, inf.bsd)
    end
    if inf2 then
        wifi.setWifiBasicInfo(2, inf2.ssid, inf2.password, inf2.encryption, tostring(inf2.channel), inf2.txpwr, tostring(inf2.hidden), tonumber(inf2.on) == 1 and 0 or 1, inf2.bandwidth, inf2.bsd)
    end
    XQFunction.setNetMode(nil)
    local restore_script = [[
        sleep 3;
        /etc/init.d/network restart;
        /etc/init.d/dnsmasq restart;
        /usr/sbin/dhcp_apclient.sh restart lan;
        /etc/init.d/trafficd restart;
        /usr/sbin/shareUpdate -b
    ]]
    if not ssid then
        ssid = wifi.getWifissid()
    end
    XQFunction.forkExec(restore_script)
    return lanip, ssid
end

function serviceRestart(fast)
    local restart_script
    if fast then
        restart_script = [[
            /etc/init.d/network restart;
            /etc/init.d/trafficd restart;
            /usr/sbin/shareUpdate -b;
            /etc/init.d/dnsmasq restart;
            /usr/sbin/dhcp_apclient.sh restart lan;
            /etc/init.d/xqbc restart;
            /etc/init.d/miqos stop
        ]]
    else
        restart_script = [[
            sleep 10;
            /etc/init.d/network restart;
            /etc/init.d/trafficd restart;
            /usr/sbin/shareUpdate -b;
            /etc/init.d/dnsmasq restart;
            /usr/sbin/dhcp_apclient.sh restart lan;
            /etc/init.d/xqbc restart;
            /etc/init.d/miqos stop
        ]]
    end
    XQFunction.forkExec(restart_script)
end

function parseCmdline(str)
    if XQFunction.isStrNil(str) then
        return ""
    else
        return str:gsub("\\", "\\\\"):gsub("`", "\\`"):gsub("\"", "\\\""):gsub("%$", "\\$")
    end
end

function setWifiAPMode(ssid, encryption, enctype, password, channel, bandwidth, nssid, nencryption, npassword, update)
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local result = {
        ["connected"]   = false,
        ["conerrmsg"]   = "",
        ["scan"]        = true,
        ["ip"]          = ""
    }
    local apmode = XQFunction.getNetMode() ~= nil
    local cssid = ssid
    local cenctype = enctype
    local cencryption = encryption
    local cpassword = password
    local cchannel = channel
    local cbandwidth = bandwidth
    local oldchannel
    local wifiinfo = XQWifiUtil.getAllWifiInfo()[1]
    if wifiinfo and wifiinfo.channelInfo then
        oldchannel = wifiinfo.channelInfo.channel
    else
        oldchannel = cchannel
    end
    if cssid and (cpassword or cencryption == "NONE") then
        local cmdssid = parseCmdline(cssid)
        local cmdpassword = parseCmdline(cpassword)
        if XQFunction.isStrNil(cenctype) then
            local scanlist = XQWifiUtil.getWifiScanlist(cmdssid)
            local wifi
            for _, item in ipairs(scanlist) do
                if item and item.ssid == ssid then
                    wifi = item
                    break
                end
            end
            if not wifi then
                result["scan"] = false
                return result
            end
            cchannel = wifi.channel
            cenctype = wifi.enctype
            cencryption = wifi.encryption
        end
        if apmode then
            os.execute("iwpriv apcli0 set ApCliAutoConnect=0")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("ifconfig apcli0 down")
            os.execute("sleep 1")
            os.execute("ifconfig apcli0 up")
        end
        if cenctype:match("AES") then
            -- WPA2PSK/WPA1PSK
            os.execute("iwpriv wl1 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode="..cencryption)
            os.execute("iwpriv apcli0 set ApCliEncrypType=AES")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliWPAPSK=\""..cmdpassword.."\"")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        elseif cenctype == "TKIP" then
            -- WPA2PSK/WPA1PSK
            os.execute("iwpriv wl1 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode="..cencryption)
            os.execute("iwpriv apcli0 set ApCliEncrypType=TKIP")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliWPAPSK=\""..cmdpassword.."\"")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        elseif cenctype == "WEP" then
            -- WEP
            os.execute("iwpriv wl1 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode=OPEN")
            os.execute("iwpriv apcli0 set ApCliEncrypType=WEP")
            os.execute("iwpriv apcli0 set ApCliDefaultKeyID=1")
            os.execute("iwpriv apcli0 set ApCliKey1=\""..cmdpassword.."\"")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        elseif cenctype == "NONE" then
            -- NONE
            os.execute("iwpriv wl1 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode=OPEN")
            os.execute("iwpriv apcli0 set ApCliEncrypType=NONE")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        end

        local connected = false
        for i=1, 10 do
            local succ, status = connectionStatus()
            if succ then
                connected = true
                break
            end
            os.execute("sleep 2")
            local reason = status:match("Disconnect reason = (.-)\n$")
            if reason then
                result["conerrmsg"] = reason:gsub("\n","")
            end
        end
        result["connected"] = connected
    end
    if result.connected then
        local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
        if not apmode then
            backupConfigs()
        end
        local uci = require("luci.model.uci").cursor()
        local oldlan = uci:get_all("network", "lan")
        setWanAuto(0)

        -- get ip
        local dhcpcode = tonumber(os.execute("sleep 2;dhcp_apclient.sh start"))
        if dhcpcode ~= 0 then
            dhcpcode = tonumber(os.execute("sleep 2;dhcp_apclient.sh start br-lan"))
        end
        local newip = XQLanWanUtil.getLanIp()
        if dhcpcode and dhcpcode == 0 then
            local XQSync = require("xiaoqiang.util.XQSynchrodata")
            XQFunction.setNetMode("wifiapmode")
            XQSync.syncApLanIp(newip)
            result["ip"] = newip
            local uci = require("luci.model.uci").cursor()
            uci:delete("dhcp", "lan")
            uci:delete("dhcp", "wan")
            uci:commit("dhcp")
            local confenc
            if cenctype == "TKIPAES" then
                confenc = "mixed-psk"
            elseif cenctype == "AES" then
                confenc = "wpa2-psk"
            elseif cenctype == "TKIP" then
                confenc = "wpa-psk"
            elseif cenctype == "WEP" then
                confenc = "wep"
            elseif cenctype == "NONE" then
                confenc = "none"
            end
            local wifissid, wifipawd, wifienc = cssid, cpassword, confenc
            if nssid and nencryption and (npassword or nencryption == "none") then
                wifissid = nssid
                wifipawd = npassword
                wifienc = nencryption
            end
            local wifi5gssid = wifissid.."_5G"
            if string.len(wifi5gssid) > 31 then
                wifi5gssid = wifissid
            end
            if wifiinfo.bsd and wifiinfo.bsd == "1" then
                wifi5gssid = wifissid
            end
            if update then
                wifissid = nil
                wifipawd = nil
                wifienc = nil
                wifi5gssid = nil
            end
            XQWifiUtil.setWifiBasicInfo(1, wifissid, wifipawd, wifienc, cchannel, nil, "0", 1, cbandwidth)
            XQWifiUtil.setWifiBasicInfo(2, wifi5gssid, wifipawd, wifienc, nil, nil, "0", 1, nil)
            XQWifiUtil.setWifiBridgedClient(1, cssid, cencryption, cenctype, cpassword, cchannel)
            XQWifiUtil.setWiFiMacfilterModel(false)
            XQWifiUtil.setGuestWifi(1, nil, nil, nil, 0, nil)
            result["ssid"] = wifissid
        else
            setWanAuto(nil)
            if apmode then
                XQFunction.forkRestartWifi(true)
            else
                local uci = require("luci.model.uci").cursor()
                uci:delete("network", "lan")
                uci:section("network", "interface", "lan", oldlan)
                uci:commit("network")
                os.execute("iwpriv apcli0 set ApCliAutoConnect=0")
                os.execute("iwpriv apcli0 set ApCliEnable=0")
                os.execute("ifconfig apcli0 down")
                os.execute("iwpriv wl1 set Channel="..tostring(oldchannel))
            end
        end
    else
        if apmode then
            XQFunction.forkRestartWifi()
        else
            os.execute("iwpriv apcli0 set ApCliAutoConnect=0")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("ifconfig apcli0 down")
            os.execute("iwpriv wl1 set Channel="..tostring(oldchannel))
        end
    end
    return result
end

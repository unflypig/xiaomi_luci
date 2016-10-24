module ("xiaoqiang.util.XQWifiUtil", package.seeall)

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

local LuciNetwork = require("luci.model.network")
local LuciUtil = require("luci.util")

local UCI = require("luci.model.uci").cursor()
local WIFI2G = UCI:get("misc", "wireless", "if_2G") or ""
local WIFI5G = UCI:get("misc", "wireless", "if_5G") or ""
local HARDWARE = UCI:get("misc", "hardware", "model") or ""
if HARDWARE then
    HARDWARE = string.lower(HARDWARE)
end

local WIFI_DEVS = {
    WIFI2G,
    WIFI5G
}

local WIFI_NETS = {
    WIFI2G..".network1",
    WIFI5G..".network1"
}

function getWifiNames()
    return WIFI_DEVS, WIFI_NETS
end

function _wifiNameForIndex(index)
    return WIFI_NETS[index]
end

function wifiNetworks()
    local result = {}
    local network = LuciNetwork.init()
    local dev
    for _, dev in ipairs(network:get_wifidevs()) do
        local rd = {
            up       = dev:is_up(),
            device   = dev:name(),
            name     = dev:get_i18n(),
            networks = {}
        }
        local wifiNet
        for _, wifiNet in ipairs(dev:get_wifinets()) do
            rd.networks[#rd.networks+1] = {
                name       = wifiNet:shortname(),
                up         = wifiNet:is_up(),
                mode       = wifiNet:active_mode(),
                ssid       = wifiNet:active_ssid(),
                bssid      = wifiNet:active_bssid(),
                cssid      = wifiNet:ssid(),
                encryption = wifiNet:active_encryption(),
                frequency  = wifiNet:frequency(),
                channel    = wifiNet:channel(),
                cchannel   = wifiNet:confchannel(),
                bw         = wifiNet:bw(),
                cbw        = wifiNet:confbw(),
                signal     = wifiNet:signal(),
                quality    = wifiNet:signal_percent(),
                noise      = wifiNet:noise(),
                bitrate    = wifiNet:bitrate(),
                ifname     = wifiNet:ifname(),
                assoclist  = wifiNet:assoclist(),
                country    = wifiNet:country(),
                txpower    = wifiNet:txpower(),
                txpoweroff = wifiNet:txpower_offset(),
                key	   	   = wifiNet:get("key"),
                key1	   = wifiNet:get("key1"),
                encryption_src = wifiNet:get("encryption"),
                hidden = wifiNet:get("hidden"),
                txpwr = wifiNet:txpwr(),
                bsd = wifiNet:get("bsd")
            }
        end
        result[#result+1] = rd
    end
    return result
end

function wifiNetwork(wifiDeviceName)
    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(wifiDeviceName)
    if wifiNet then
        local dev = wifiNet:get_device()
        if dev then
            return {
                id         = wifiDeviceName,
                name       = wifiNet:shortname(),
                up         = wifiNet:is_up(),
                mode       = wifiNet:active_mode(),
                ssid       = wifiNet:active_ssid(),
                bssid      = wifiNet:active_bssid(),
                cssid      = wifiNet:ssid(),
                encryption = wifiNet:active_encryption(),
                encryption_src = wifiNet:get("encryption"),
                frequency  = wifiNet:frequency(),
                channel    = wifiNet:channel(),
                cchannel   = wifiNet:confchannel(),
                bw         = wifiNet:bw(),
                cbw        = wifiNet:confbw(),
                signal     = wifiNet:signal(),
                quality    = wifiNet:signal_percent(),
                noise      = wifiNet:noise(),
                bitrate    = wifiNet:bitrate(),
                ifname     = wifiNet:ifname(),
                assoclist  = wifiNet:assoclist(),
                country    = wifiNet:country(),
                txpower    = wifiNet:txpower(),
                txpoweroff = wifiNet:txpower_offset(),
                key        = wifiNet:get("key"),
                key1	   = wifiNet:get("key1"),
                hidden     = wifiNet:get("hidden"),
                txpwr = wifiNet:txpwr(),
                bsd = wifiNet:get("bsd"),
                device     = {
                    up     = dev:is_up(),
                    device = dev:name(),
                    name   = dev:get_i18n()
                }
            }
        end
    end
    return {}
end

function getWifissid()
    local wifi2 = wifiNetwork(_wifiNameForIndex(1))
    local wifi5 = wifiNetwork(_wifiNameForIndex(2))
    return wifi2.cssid, wifi5.cssid
end

-- 2.4G, 5G
function getWifiBssid()
    local LuciUtil = require("luci.util")
    local macs = LuciUtil.exec("getmac")
    if macs then
        macs = LuciUtil.trim(macs)
        local macarr = LuciUtil.split(macs, ",")
        if #macarr == 3 then
          return macarr[2], macarr[3]
        elseif #macarr == 2 then
          return macarr[2], nil
        end
    end
    return nil, nil
end

--[[
Get devices conneted to wifi
@param wifiIndex: 1 (2.4G)/ 2 (5G)
@return avaliable channel list
]]--
function getChannels(wifiIndex)
    local stat, iwinfo = pcall(require, "iwinfo")
    local iface = _wifiNameForIndex(wifiIndex)
    local cns
    if stat then
        local t = iwinfo.type(iface or "")
        if iface and t and iwinfo[t] then
            cns = iwinfo[t].freqlist(iface)
        end
    end
    return cns
end

local wifi24 = {
    ["1"] = {["20"] = "1", ["40"] = "1l"},
    ["2"] = {["20"] = "2", ["40"] = "2l"},
    ["3"] = {["20"] = "3", ["40"] = "3l"},
    ["4"] = {["20"] = "4", ["40"] = "4l"},
    ["5"] = {["20"] = "5", ["40"] = "5l"},
    ["6"] = {["20"] = "6", ["40"] = "6l"},
    ["7"] = {["20"] = "7", ["40"] = "7l"},
    ["8"] = {["20"] = "8", ["40"] = "8u"},
    ["9"] = {["20"] = "9", ["40"] = "9u"},
    ["10"] = {["20"] = "10", ["40"] = "10u"},
    ["11"] = {["20"] = "11", ["40"] = "11u"},
    ["12"] = {["20"] = "12", ["40"] = "12u"},
    ["13"] = {["20"] = "13", ["40"] = "13u"}
}

local wifi50 = {
    ["36"] = {["20"] = "36", ["40"] = "36l", ["80"] = "36/80"},
    ["40"] = {["20"] = "40", ["40"] = "40u", ["80"] = "40/80"},
    ["44"] = {["20"] = "44", ["40"] = "44l", ["80"] = "44/80"},
    ["48"] = {["20"] = "48", ["40"] = "48u", ["80"] = "48/80"},
    ["52"] = {["20"] = "52", ["40"] = "52l", ["80"] = "52/80"},
    ["56"] = {["20"] = "56", ["40"] = "56u", ["80"] = "56/80"},
    ["60"] = {["20"] = "60", ["40"] = "60l", ["80"] = "60/80"},
    ["64"] = {["20"] = "64", ["40"] = "64u", ["80"] = "64/80"},
    ["149"] = {["20"] = "149", ["40"] = "149l", ["80"] = "149/80"},
    ["153"] = {["20"] = "153", ["40"] = "153u", ["80"] = "153/80"},
    ["157"] = {["20"] = "157", ["40"] = "157l", ["80"] = "157/80"},
    ["161"] = {["20"] = "161", ["40"] = "161u", ["80"] = "161/80"},
    ["165"] = {["20"] = "165"}
}

local CHANNELS = {
    ["CN"] = {
        "0 1 2 3 4 5 6 7 8 9 10 11 12 13",
        "0 36 40 44 48 52 56 60 64 149 153 157 161 165"
    },
    ["TW"] = {
        "0 1 2 3 4 5 6 7 8 9 10 11",
        "0 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165"
    },
    ["HK"] = {
        "0 1 2 3 4 5 6 7 8 9 10 11 12 13",
        "0 36 40 44 48 52 56 60 64 149 153 157 161 165"
    },
    ["US"] = {
        "0 1 2 3 4 5 6 7 8 9 10 11",
        "0 36 40 44 48 149 153 157 161 165"
    },
    ["EU"] = {
        "0 1 2 3 4 5 6 7 8 9 10 11 12 13",
        "0 36 40 44 48"
    }
}

local BANDWIDTH = {
    {"20"},
    {"20", "40"},
    {"20", "40", "80"}
}

function getDefaultWifiChannels(wifiIndex)
    local index = tonumber(wifiIndex) == 2 and 2 or 1
    local XQCountryCode = require("xiaoqiang.XQCountryCode")
    local ccode = XQCountryCode.getCurrentCountryCode()
    local channels = CHANNELS[ccode]
    local result = {}
    if channels then
        channels = channels[index]
        if channels then
            channels = LuciUtil.split(channels, " ")
            for _, channel in ipairs(channels) do
                local item = {["c"] = channel}
                if tonumber(channel) <= 14 then
                    item["b"] = BANDWIDTH[2]
                else
                    if tonumber(channel) == 165 then
                        item["b"] = BANDWIDTH[1]
                    else
                        item["b"] = BANDWIDTH[3]
                    end
                end
                table.insert(result, item)
            end
            return result
        end
    end
    return {}
end

--[[
Get devices conneted to wifi
@param wifiIndex: 1 (2.4G)/ 2 (5G)
@return divices list
]]--
function getWifiConnectDeviceList(wifiIndex)
    local wifiUp
    local assoclist = {}
    if tonumber(wifiIndex) == 1 then
        wifiUp = (getWifiStatus(1).up == 1)
        assoclist = wifiNetwork(_wifiNameForIndex(1)).assoclist or {}
    else
        wifiUp = (getWifiStatus(2).up == 1)
        assoclist = wifiNetwork(_wifiNameForIndex(2)).assoclist or {}
    end
    local dlist = {}
    if wifiUp then
        for mac, info in pairs(assoclist) do
            table.insert(dlist, XQFunction.macFormat(mac))
        end
    end
    return dlist
end

function isDeviceWifiConnect(mac,wifiIndex)
    local dict = getWifiConnectDeviceDict(wifiIndex)
    if type(dict) == "table" then
        return dict[XQFunction.macFormat(mac)] ~= nil
    else
        return false
    end
end

--[[
Get devices conneted to wifi
@param wifiIndex: 1 (2.4G)/ 2 (5G)
@return divices dict{mac:1}
]]--
function getWifiConnectDeviceDict(wifiIndex)
    local wifiUp
    local assoclist = {}
    if tonumber(wifiIndex) == 1 then
        wifiUp = (getWifiStatus(1).up == 1)
        assoclist = wifiNetwork(_wifiNameForIndex(1)).assoclist or {}
    else
        wifiUp = (getWifiStatus(2).up == 1)
        assoclist = wifiNetwork(_wifiNameForIndex(2)).assoclist or {}
    end
    local dict = {}
    if wifiUp then
        for mac, info in pairs(assoclist) do
            if mac then
                dict[XQFunction.macFormat(mac)] = 1
            end
        end
    end
    return dict
end

function _pauseChannel(channel)
    if XQFunction.isStrNil(channel) then
        return ""
    end
    if channel:match("l") then
        return channel:gsub("l","").."(40M)"
    end
    if channel:match("u") then
        return channel:gsub("u","").."(40M)"
    end
    if channel:match("\/80") then
        return channel:gsub("\/80","").."(80M)"
    end
    return channel.."(20M)"
end

function getWifiWorkChannel(wifiIndex)
    local channel = ""
    if tonumber(wifiIndex) == 1 then
        channel = LuciUtil.trim(LuciUtil.exec(XQConfigs.WIFI24_WORK_CHANNEL))
    else
        channel = LuciUtil.trim(LuciUtil.exec(XQConfigs.WIFI50_WORK_CHANNEL))
    end
    return _pauseChannel(channel)
end

--[[
Get device wifiIndex
@param mac: mac address
@return 0 (lan)/1 (2.4G)/ 2 (5G)
]]--
function getDeviceWifiIndex(mac)
    mac = XQFunction.macFormat(mac)
    local wifi1Devices = getWifiConnectDeviceDict(1)
    local wifi2Devices = getWifiConnectDeviceDict(2)
    if wifi1Devices then
        if wifi1Devices[mac] == 1 then
            return 1
        end
    end
    if wifi2Devices then
        if wifi2Devices[mac] == 1 then
            return 2
        end
    end
    return 0
end

function getWifiDeviceSignalDict(wifiIndex)
    local result = {}
    local assoclist = {}
    if not (getWifiStatus(wifiIndex).up == 1) then
        return result
    end
    if wifiIndex == 1 then
        assoclist = wifiNetwork(_wifiNameForIndex(1)).assoclist or {}
    else
        assoclist = wifiNetwork(_wifiNameForIndex(2)).assoclist or {}
    end
    for mac, info in pairs(assoclist) do
        if mac then
            result[XQFunction.macFormat(mac)] = 2*math.abs(tonumber(info.signal)-tonumber(info.noise))
        end
    end
    return result
end

function getWifiDeviceSignal(mac)
    if XQFunction.isStrNil(mac) then
        return nil
    end
    local assoclist1 = wifiNetwork(_wifiNameForIndex(1)).assoclist or {}
    for amac, item in pairs(assoclist1) do
        if mac == amac then
            return item.signal
        end
    end
    local assoclist2 = wifiNetwork(_wifiNameForIndex(2)).assoclist or {}
    for amac, item in pairs(assoclist2) do
        if mac == amac then
            return item.signal
        end
    end
    return nil
end

--[[
Get all devices conneted to wifi
@return devices list [{mac,signal,wifiIndex}..]
]]--
function getAllWifiConnetDeviceList()
    local result = {}
    for index = 1,2 do
        local wifiSignal = getWifiDeviceSignalDict(index)
        local wifilist = getWifiConnectDeviceList(index)
        for _, mac in pairs(wifilist) do
            table.insert(result, {
                    ['mac'] = XQFunction.macFormat(mac),
                    ['signal'] = wifiSignal[mac],
                    ['wifiIndex'] = index
                })
        end
    end
    return result
end

--[[
Get all devices conneted to wifi
@return devices dict{mac:{signal,wifiIndex}}
]]--
function getAllWifiConnetDeviceDict()
    local result = {}
    for index = 1,2 do
        local wifiSignal = getWifiDeviceSignalDict(index)
        local wifilist = getWifiConnectDeviceList(index)
        for _, mac in pairs(wifilist) do
            local item = {}
            item['signal'] = wifiSignal[mac]
            item['wifiIndex'] = index
            result[XQFunction.macFormat(mac)] = item
        end
    end
    return result
end

--[[
Get wifi status
@param wifiIndex: 1 (2.4G)/ 2 (5G)
@return dict{ssid,up}
]]--
function getWifiStatus(wifiIndex)
    local wifiNet = wifiNetwork(_wifiNameForIndex(wifiIndex))
    return {
        ['ssid'] = wifiNet["ssid"],
        ['up'] = wifiNet["up"] and 1 or 0
    }
end

function channelHelper(channel)
    local channelInfo = {channel = "", bandwidth = ""}
    if XQFunction.isStrNil(channel) then
        return channelInfo
    end
    if string.find(channel,"l") ~= nil then
        channelInfo["channel"] = channel:match("(%S+)l")
        channelInfo["bandwidth"] = "40"
    elseif string.find(channel,"u") ~= nil then
        channelInfo["channel"] = channel:match("(%S+)u")
        channelInfo["bandwidth"] = "40"
    elseif string.find(channel,"/80") ~= nil then
        channelInfo["channel"] = channel:match("(%S+)/80")
        channelInfo["bandwidth"] = "80"
    else
        channelInfo["channel"] = tostring(channel)
        channelInfo["bandwidth"] = "20"
    end
    local bandList = {}
    if channelInfo.channel then
        local channelList = wifi24[channelInfo.channel] or wifi50[channelInfo.channel]
        if channelList and type(channelList) == "table" then
            for key, v in pairs(channelList) do
                table.insert(bandList, key)
            end
        end
    end
    channelInfo["bandList"] = bandList
    return channelInfo
end

function getBandList(channel)
    local channelInfo = {channel = "", bandwidth = ""}
    if XQFunction.isStrNil(channel) then
        return channelInfo
    end
    local bandList = {}
    if tonumber(channel) ~= 0 then
        local wifi = getDefaultWifiChannels(1)
        local wifi2 = getDefaultWifiChannels(2)
        table.foreachi(wifi2,
            function (k, v)
                table.insert(wifi, v)
            end
        )
        if wifi and type(wifi) == "table" then
            for _, v in ipairs(wifi) do
                if v and tonumber(v.c) == tonumber(channel) then
                    bandList = v.b
                    break
                end
            end
        end
    end
    channelInfo["bandList"] = bandList
    return channelInfo
end

function _channelFix(channel)
    if XQFunction.isStrNil(channel) then
        return ""
    end
    channel = string.gsub(channel, "l", "")
    channel = string.gsub(channel, "u", "")
    channel = string.gsub(channel, "/80", "")
    return channel
end

function channelFormat(wifiIndex, channel, bandwidth)
    local channelList = {}
    if tonumber(wifiIndex) == 1 then
        channelList = wifi24[tostring(channel)]
    else
        channelList = wifi50[tostring(channel)]
    end
    if channelList and type(channelList) == "table" then
        local channel = channelList[tostring(bandwidth)]
        if not XQFunction.isStrNil(channel) then
            return channel
        end
    end
    return false
end

--[[
Get wifi information
@return dict{status,ifname,device,ssid,encryption,channel,mode,hidden,signal,password}
]]--
function getAllWifiInfo()
    local infoList = {}
    local wifis = wifiNetworks()
    for i,wifiNet in ipairs(wifis) do
        local item = {}
        local index = 1
        local channel = wifiNet.networks[index].cchannel
        item["channel"] = channel
        item["bandwidth"] = wifiNet.networks[index].cbw
        item["channelInfo"] = getBandList(channel)
        if wifiNet["up"] then
            item["status"] = "1"
            item["ssid"] = wifiNet.networks[index].ssid
            item["channelInfo"]["channel"] = wifiNet.networks[index].channel
            item["channelInfo"]["bandwidth"] = wifiNet.networks[index].bw
        else
            item["status"] = "0"
            item["ssid"] = wifiNet.networks[index].cssid
            item["channelInfo"]["channel"] = wifiNet.networks[index].cchannel
            item["channelInfo"]["bandwidth"] = wifiNet.networks[index].cbw
        end
        local encryption = wifiNet.networks[index].encryption_src
        local key = wifiNet.networks[index].key
        if encryption == "wep-open" then
            key = wifiNet.networks[index].key1
            if key:len()>4 and key:sub(0,2)=="s:" then
                key = key:sub(3)
            end
        end
        item["ifname"] = wifiNet.networks[index].ifname
        item["device"] = wifiNet.device..".network"..index
        item["mode"] = wifiNet.networks[index].mode
        item["hidden"] = wifiNet.networks[index].hidden or 0
        item["signal"] = wifiNet.networks[index].signal
        item["password"] = key
        item["encryption"] = encryption
        item["txpwr"] = wifiNet.networks[index].txpwr
        item["bsd"] = wifiNet.networks[index].bsd
        infoList[#wifis+1-i] = item
    end
    local guestwifi = getGuestWifi(1)
    if guestwifi and XQFunction.getNetModeType() == 0 then
        table.insert(infoList, guestwifi)
    end
    return infoList
end

function getWifiTxpwr(wifiIndex)
    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(_wifiNameForIndex(wifiIndex))
    if wifiNet then
        return tostring(wifiNet:txpwr())
    else
        return nil
    end
end

function getWifiChannel(wifiIndex)
    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(_wifiNameForIndex(wifiIndex))
    if wifiNet then
        return tostring(wifiNet:channel())
    else
        return nil
    end
end

function getWifiTxpwrList()
    local txpwrList = {}
    local network = LuciNetwork.init()
    local wifiNet1 = network:get_wifinet(_wifiNameForIndex(1))
    local wifiNet2 = network:get_wifinet(_wifiNameForIndex(2))
    if wifiNet1 then
        table.insert(txpwrList,tostring(wifiNet1:txpwr()))
    end
    if wifiNet2 then
        table.insert(txpwrList,tostring(wifiNet2:txpwr()))
    end
    return txpwrList
end

function getWifiChannelList()
    local channelList = {}
    local network = LuciNetwork.init()
    local wifiNet1 = network:get_wifinet(_wifiNameForIndex(1))
    local wifiNet2 = network:get_wifinet(_wifiNameForIndex(2))
    if wifiNet1 then
        table.insert(channelList,tostring(wifiNet1:channel()))
    end
    if wifiNet2 then
        table.insert(channelList,tostring(wifiNet2:channel()))
    end
    return channelList
end

function getWifiChannelTxpwrList()
    local result = {}
    local network = LuciNetwork.init()
    local wifiNet1 = network:get_wifinet(_wifiNameForIndex(1))
    local wifiNet2 = network:get_wifinet(_wifiNameForIndex(2))
    if wifiNet1 then
        table.insert(result,{
            channel = tostring(wifiNet1:channel()),
            txpwr = tostring(wifiNet1:txpwr())
        })
    else
        table.insert(result,{})
    end
    if wifiNet2 then
        table.insert(result,{
            channel = tostring(wifiNet2:channel()),
            txpwr = tostring(wifiNet2:txpwr())
        })
    else
        table.insert(result,{})
    end
    return result
end

function setWifiChannelTxpwr(channel1,txpwr1,channel2,txpwr2)
    local network = LuciNetwork.init()
    local wifiDev1 = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(1),".")[1])
    local wifiDev2 = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(2),".")[1])
    if wifiDev1 then
        if tonumber(channel1) then
            wifiDev1:set("channel",channel1)
        end
        if not XQFunction.isStrNil(txpwr1) then
            wifiDev1:set("txpwr",txpwr1);
        end
    end
    if wifiDev2 then
        if tonumber(channel2) then
            wifiDev2:set("channel",channel2)
        end
        if not XQFunction.isStrNil(txpwr2) then
            wifiDev2:set("txpwr",txpwr2);
        end
    end
    network:commit("wireless")
    network:save("wireless")
    return true
end

function setWifiTxpwr(txpwr)
    local network = LuciNetwork.init()
    local wifiDev1 = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(1),".")[1])
    local wifiDev2 = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(2),".")[1])
    if wifiDev1 then
        if not XQFunction.isStrNil(txpwr) then
            wifiDev1:set("txpwr",txpwr);
        end
    end
    if wifiDev2 then
        if not XQFunction.isStrNil(txpwr) then
            wifiDev2:set("txpwr",txpwr);
        end
    end
    network:commit("wireless")
    network:save("wireless")
    return true
end

function checkWifiPasswd(passwd,encryption)
    if XQFunction.isStrNil(encryption) or (encryption and encryption ~= "none" and XQFunction.isStrNil(passwd)) then
        return 1502
    end
    if encryption == "psk" or encryption == "psk2" then
        if  passwd:len() < 8 then
            return 1520
        end
    elseif encryption == "mixed-psk" then
        if  passwd:len()<8 or passwd:len()>63 then
            return 1521
        end
    elseif encryption == "wep-open" then
        if  passwd:len()~=5 and passwd:len()~=13 then
            return 1522
        end
    end
    return 0
end

function checkSSID(ssid,length)
    if XQFunction.isStrNil(ssid) then
        return 0
    end
    if string.len(ssid) > tonumber(length) then
        return 1572
    end
    if not XQFunction.checkSSID(ssid) then
        return 1573
    end
    return 0
end

function getWifiBasicInfo(wifiIndex)
    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(_wifiNameForIndex(wifiIndex))
    local wifiDev = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    if wifiNet and wifiDev then
        local options = {
            ["wifiIndex"]   = wifiIndex,
            ["channel"]     = wifiDev:get("channel") or 0,
            ["bandwidth"]   = wifiDev:get("bw") or 0,
            ["txpwr"]       = wifiDev:get("txpwr") or "mid",
            ["on"]          = wifiDev:get("disabled") or 0,
            ["ssid"]        = wifiNet:get("ssid"),
            ["encryption"]  = wifiNet:get("encryption"),
            ["password"]    = wifiNet:get("key"),
            ["hidden"]      = wifiNet:get("hidden") or 0,
            ["bsd"]         = wifiNet:get("bsd")
        }
        return options
    end
    return nil
end

function backupWifiInfo(wifiIndex)
    local uci = require("luci.model.uci").cursor()
    local options = getWifiBasicInfo(wifiIndex)
    if options then
        uci:section("backup", "backup", "wifi"..tostring(wifiIndex), options)
        uci:commit("backup")
    end
end

function setWifiBasicInfo(wifiIndex, ssid, password, encryption, channel, txpwr, hidden, on, bandwidth, bsd)
    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(_wifiNameForIndex(wifiIndex))
    local wifiDev = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    if wifiNet == nil then
        return false
    end
    if wifiDev then
        if not XQFunction.isStrNil(channel) then
            wifiDev:set("channel",channel)
            if channel == "0" then
                wifiDev:set("autoch","2")
            else
                wifiDev:set("autoch","0")
            end
        end
        if not XQFunction.isStrNil(bandwidth) then
            wifiDev:set("bw",bandwidth)
        end
        if not XQFunction.isStrNil(txpwr) then
            wifiDev:set("txpwr",txpwr);
        end
        if wifiIndex == 1 then
            local guestwifi = getGuestWifi(1)
            if guestwifi and tonumber(on) and tonumber(on) == 0 and XQFunction.getNetModeType() ~= 2 then
                setGuestWifi(1, nil, nil, nil, on, nil)
            end
        end
        if on == 1 then
            wifiDev:set("disabled", "0")
        elseif on == 0 then
            wifiDev:set("disabled", "1")
        end
    end
    wifiNet:set("disabled", nil)
    if bsd then
        wifiNet:set("bsd", tostring(bsd))
    end
    if not XQFunction.isStrNil(ssid) and XQFunction.checkSSID(ssid) then
        local XQSync = require("xiaoqiang.util.XQSynchrodata")
        if wifiIndex == 1 then
            XQSync.syncWiFiSSID(ssid, nil)
        elseif wifiIndex == 2 then
            XQSync.syncWiFiSSID(nil, ssid)
        end
        wifiNet:set("ssid",ssid)
    end
    if encryption then
        local code = checkWifiPasswd(password, encryption)
        if code == 0 then
            wifiNet:set("encryption", encryption)
            wifiNet:set("key", password)
            if encryption == "none" then
                wifiNet:set("key","")
            elseif encryption == "wep-open" then
                wifiNet:set("key1", "s:"..password)
                wifiNet:set("key", 1)
            end
            if wifiIndex == 1 then
                XQFunction.nvramSet("nv_wifi_ssid", ssid)
                XQFunction.nvramSet("nv_wifi_enc", encryption)
                XQFunction.nvramSet("nv_wifi_pwd", password)
                XQFunction.nvramCommit()
            else
                XQFunction.nvramSet("nv_wifi_ssid1", ssid)
                XQFunction.nvramSet("nv_wifi_enc1", encryption)
                XQFunction.nvramSet("nv_wifi_pwd1", password)
                XQFunction.nvramCommit()
            end
        elseif code > 1502 then
            return false
        end
    end
    if hidden == "1" then
        wifiNet:set("hidden","1")
    end
    if hidden == "0" then
        wifiNet:set("hidden","0")
    end
    network:save("wireless")
    network:commit("wireless")
    return true
end

function setWifiRegion(country, region, regionABand)
    if XQFunction.isStrNil(country) or not tonumber(region) or not tonumber(regionABand) then
        return false
    end
    local network = LuciNetwork.init()
    local wifiDev1 = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(1),".")[1])
    local wifiDev2 = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(2),".")[1])
    if wifiDev1 then
        wifiDev1:set("country",country)
        wifiDev1:set("region",region)
        wifiDev1:set("aregion",regionABand)
        wifiDev1:set("channel","0")
        wifiDev1:set("bw","0")
        wifiDev1:set("autoch","2")
    end
    if wifiDev2 then
        wifiDev2:set("country",country)
        wifiDev2:set("region",region)
        wifiDev2:set("aregion",regionABand)
        wifiDev2:set("channel","0")
        wifiDev2:set("bw","0")
        wifiDev2:set("autoch","2")
    end
    network:commit("wireless")
    network:save("wireless")
    return true
end

--[[
Turn on wifi
@param wifiIndex: 1 (2.4G)/ 2 (5G)
@return boolean
]]--
function turnWifiOn(wifiIndex)
    local wifiStatus = getWifiStatus(wifiIndex)
    if wifiStatus['up'] == 1 then
        return true
    end
    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(_wifiNameForIndex(wifiIndex))
    local dev
    if wifiNet ~= nil then
        dev = wifiNet:get_device()
    end
    if dev and wifiNet then
        -- if wifiIndex == 1 then
        --     local guestwifi = getGuestWifi(1)
        --     if guestwifi and XQFunction.getNetModeType() ~= 2 then
        --         setGuestWifi(1, nil, nil, nil, 1, nil)
        --     end
        -- end
        dev:set("disabled", "0")
        wifiNet:set("disabled", nil)
        network:commit("wireless")
        XQFunction.forkRestartWifi()
        return true
    end
    return false
end

--[[
Turn off wifi
@param wifiIndex: 1 (2.4G)/ 2 (5G)
@return boolean
]]--
function turnWifiOff(wifiIndex)
    local wifiStatus = getWifiStatus(wifiIndex)
    if wifiStatus['up'] == 0 then
        return true
    end

    local network = LuciNetwork.init()
    local wifiNet = network:get_wifinet(_wifiNameForIndex(wifiIndex))
    local dev
    if wifiNet ~= nil then
        dev = wifiNet:get_device()
    end
    if dev and wifiNet then
        -- if wifiIndex == 1 then
        --     local guestwifi = getGuestWifi(1)
        --     if guestwifi and XQFunction.getNetModeType() ~= 2 then
        --         setGuestWifi(1, nil, nil, nil, 0, nil)
        --     end
        -- end
        dev:set("disabled", "1")
        wifiNet:set("disabled", nil)
        network:commit("wireless")
        XQFunction.forkRestartWifi()
        return true
    end
    return false
end

function wifiScanList(wifiIndex)
    local LuciSys = require("luci.sys")
    local LuciUtil = require("luci.util")
    local scanList = {}
    local iw = LuciSys.wifi.getiwinfo(_wifiNameForIndex(wifiIndex))
    if iw then
        for i, wifi in ipairs(iw.scanlist or { }) do
            local wifiDev = {}
            local quality = wifi.quality or 0
            local qualityMax = wifi.quality_max or 0
            local wifiSigPercent = 0
            if wifi.bssid and quality > 0 and qualityMax > 0 then
                wifiSigPercent = math.floor((100 / qualityMax) * quality)
            end
            wifi.encryption = wifi.encryption or { }
            wifiDev["ssid"] = wifi.ssid and LuciUtil.pcdata(wifi.ssid) or "hidden"
            wifiDev["bssid"] = wifi.bssid
            wifiDev["mode"] = wifi.mode
            wifiDev["channel"] = wifi.channel
            wifiDev["encryption"] = wifi.encryption
            wifiDev["signal"] = wifi.signal or 0
            wifiDev["signalPercent"] = wifiSigPercent
            wifiDev["quality"] = quality
            wifiDev["qualityMax"] = qualityMax
            table.insert(scanList,wifiDev)
        end
    end
    return scanList
end

function wifiBridgedClientId()
    local LuciNetwork = require("luci.model.network").init()
    local wifiDevs = LuciNetwork:get_wifidevs();
    local clients = {}
    for i, wifiDev in ipairs(wifiDevs) do
        local clientId
        for _, wifiNet in ipairs(wifiDev:get_wifinets()) do
            if wifiNet:active_mode() == "Client" then
                clientId = wifiNet:id()
            end
        end
        if not XQFunction.isStrNil(clientId) then
            table.insert(clients,i,clientId)
        end
    end
    return clients
end

--[[
@param wifiIndex : 1(2.4G) 2(5G)
]]--
function getWifiBridgedClient(wifiIndex)
    local LuciNetwork = require("luci.model.network").init()
    local client = {}
    local clientId = wifiStaClientId(wifiIndex)
    if clientId then
        local wifiNet = LuciNetwork:get_wifinet(clientId)
        if wifiNet:get("disabled") == "1" then
            return client
        end
        client["ssid"] = wifiNet:get("ssid")
        client["key"] = wifiNet:get("key")
        client["encryption"] = wifiNet:get("encryption")
        client["channel"] = wifiNet:get("channel")
    end
    return client
end

function wifiStaClientId(wifiIndex)
    local LuciNetwork = require("luci.model.network").init()
    local clientId
    local wifiDev = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    for _, wifiNet in ipairs(wifiDev:get_wifinets()) do
        if wifiNet:get("mode") == "sta" then
            clientId = wifiNet:id()
        end
    end
    return clientId
end

function deleteWifiBridgedClient(wifiIndex)
    local LuciNetwork = require("luci.model.network").init()
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local clientId = wifiStaClientId(wifiIndex)
    local wifiDev = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    if not wifiDev and not XQFunction.isStrNil(clientId) then
        return false
    end
    wifiDev:del_wifinet(clientId)
    LuciNetwork:commit("wireless")
    return true
end

--[[
@param wifiIndex : 1(2.4G) 2(5G)
]]--
function setWifiBridgedClient(wifiIndex,ssid,encryption,enctype,key,channel)
    local LuciNetwork = require("luci.model.network").init()
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    -- Set wifi
    local clientId = wifiStaClientId(wifiIndex)
    local wifiDev = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    local wlanX = "apcli0"
    if not wifiDev then
        return false
    end
    if XQFunction.isStrNil(clientId) then
        local network = {
            ifname      = wlanX,
            ssid        = ssid,
            mode        = "sta",
            encryption  = encryption,
            enctype     = enctype,
            key         = key,
            network     = "lan",
            disabled    = "0"
        }
        wifiDev:add_wifinet(network)
    else
        local wifiNet = wifiDev:get_wifinet(clientId)
        wlanX = wifiNet:get("ifname")
        wifiNet:set("ssid",ssid)
        wifiNet:set("key",key)
        wifiNet:set("encryption",encryption)
        wifiNet:set("enctype",enctype)
        wifiNet:set("network","lan")
        wifiNet:set("disabled","0")
    end
    wifiDev:set("channel",channel)
    -- Save and commit
    LuciNetwork:save("wireless")
    LuciNetwork:commit("wireless")
end

--[[
@return 0:close 1:start 2:connect 3:error 4:timeout
]]
function getWifiWpsStatus()
    local LuciUtil = require("luci.util")
    local status = LuciUtil.exec(XQConfigs.GET_WPS_STATUS)
    if not XQFunction.isStrNil(status) then
        status = LuciUtil.trim(status)
        return tonumber(status)
    end
    return 0
end

function getWpsConDevMac()
    local LuciUtil = require("luci.util")
    local mac = LuciUtil.exec(XQConfigs.GET_WPS_CONMAC)
    if mac then
        return XQFunction.macFormat(LuciUtil.trim(mac))
    end
    return nil
end

function stopWps()
    local LuciUtil = require("luci.util")
    LuciUtil.exec(XQConfigs.CLOSE_WPS)
    return
end

function openWifiWps()
    local LuciUtil = require("luci.util")
    local XQPreference = require("xiaoqiang.XQPreference")
    LuciUtil.exec(XQConfigs.OPEN_WPS)
    local timestamp = tostring(os.time())
    XQPreference.set(XQConfigs.PREF_WPS_TIMESTAMP,timestamp)
    return timestamp
end

--[[
    WiFi Bridge
]]--

--local WIFI_LIST_CMD = [[iwpriv wl1 set SiteSurvey=1;iwpriv wl1 get_site_survey | awk '{print $2"|||"$3"|||"$4"|||"$5}']]
--[[
function _parseEncryption(encryption)
    if XQFunction.isStrNil(encryption) then
        return nil
    end
    encryption = string.lower(encryption)
    if encryption:match("none") then
        return "NONE"
    end
    if encryption:match("wpa2psk") then
        return "WPA2PSK"
    end
    if encryption:match("wpapsk") then
        return "WPAPSK"
    end
    if encryption:match("wpa2") then
        return "WPA2"
    end
    if encryption:match("wpa1") then
        return "WPA1"
    end
    return "NONE"
end

function getWifiScanList()
    local wifilist = {}
    local LuciUtil = require("luci.util")
    for _, line in ipairs(LuciUtil.execl(WIFI_LIST_CMD)) do
        local item = LuciUtil.split(line, "|||")
        if tonumber(item[4]) then
            local wifi = {["ssid"] = "", ["encryption"] = "", ["bssid"] = "", ["signal"] = 0}
            local enc = _parseEncryption(item[3])
            if enc then
                wifi.encryption = enc
            end
            wifi.ssid = item[1]
            wifi.bssid = item[2]
            wifi.signal = tonumber(item[4])
            table.insert(wifilist, wifi)
        end
    end
    return wifilist
end
]]--

-- "%-4s%-33s%-20s%-23s%-6s%-7s%-7s%-3s%-6s%-4s%-5s\n", "Ch", "SSID", "BSSID", "Security", "Sig(%)", "W-Mode", "ExtCH"," NT", "XM", "WPS", "DPID")
-- -->
-- "%-4s%-35s%-20s%-23s%-6s%-7s%-7s%-3s%-6s%-4s%-5s\n"
function _wifiScan()
    local LuciUtil = require("luci.util")
    local result = {}
    local scan = "iwpriv wl1 get_site_survey"
    local scanlist = LuciUtil.execi(scan)
    if scanlist then
        for line in scanlist do
            if not XQFunction.isStrNil(line) and #line >= 115 then
                local channel = string.sub(line, 1, 4):match("(%d+)")
                local ssid = string.sub(line, 5, 39):match("<(.+)>")
                local mac = string.sub(line, 40, 59):match("(%S+)")
                local security = string.sub(line, 60, 82):match("(%S+)")
                local signal = string.sub(line, 83, 88):match("(%S+)")
                local wmode = string.sub(line, 89, 95):match("(%S+)")
                local extch = string.sub(line, 96, 102):match("(%S+)")
                local nt = string.sub(line, 103, 105):match("(%S+)")
                local xm = string.sub(line, 106, 111):match("(%S+)") or ""
                local wps = string.sub(line, 112, 115):match("(%S+)")
                if channel and ssid and mac and security and signal and extch and xm then
                    local encryption
                    local enctype
                    local bandwidth
                    if security:match("WPA2PSK") then
                        encryption = "WPA2PSK"
                    elseif security:match("WPA1PSK") then
                        encryption = "WPA1PSK"
                    elseif security:match("WPAPSK") then
                        encryption = "WPAPSK"
                    elseif security:match("WEP") then
                        encryption = "WEP"
                    elseif security:match("NONE") then
                        encryption = "NONE"
                    end
                    if security:match("TKIPAES") then
                        enctype = "TKIPAES"
                    elseif security:match("AES") then
                        enctype = "AES"
                    elseif security:match("TKIP") then
                        enctype = "TKIP"
                    elseif security:match("WEP") then
                        enctype = "WEP"
                    else
                        enctype = "NONE"
                    end
                    if extch:match("NONE") then
                        bandwidth = 20
                    else
                        bandwidth = 40
                    end
                    if encryption and enctype then
                        local item = {
                            ["channel"]     = channel,
                            ["ssid"]        = ssid,
                            ["mac"]         = XQFunction.macFormat(mac),
                            ["encryption"]  = encryption,
                            ["enctype"]     = enctype,
                            ["bandwidth"]   = bandwidth,
                            ["signal"]      = signal,
                            ["xm"]          = xm
                        }
                        table.insert(result, item)
                    end
                end
            end
        end
    end
    return result
end

-- wifi ap client, for 2.4G
function getWifiScanlist(sitesurvey)
    local result = {}
    local scan
    local wifi_on = getWifiStatus(1).up
    if wifi_on ~= 1 then
        os.execute("uci set wireless."..WIFI2G..".disabled=0;uci commit wireless;/sbin/wifi enable "..WIFI2G..">/dev/null 2>/dev/null")
    end
    if XQFunction.isStrNil(sitesurvey) then
        scan = "iwpriv wl1 set SiteSurvey=;sleep 1"
    else
        scan = "iwpriv wl1 set SiteSurvey=\""..sitesurvey.."\";sleep 1"
    end
    os.execute(scan)
    for i=1, 3 do
        local scanresult = _wifiScan()
        if #scanresult > 0 then
            for _, item in ipairs(scanresult) do
                table.insert(result, item)
            end
        end
    end
    return result
end

--[[
    @param wifiIndex:1/2  2.4G/5G
]]
--[[
function setWifiBridge(wifiIndex, ssid, password, encryption)
    local LuciUtil = require("luci.util")
    local LuciNetwork = require("luci.model.network").init()
    local wifiDev = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    local clients = {}
    local key
    if encryption == "none" then
        key = ""
    else
        key = password
    end
    if wifiDev then
        local clientId
        for _, wifiNet in ipairs(wifiDev:get_wifinets()) do
            if wifiNet:active_mode() == "Client" then
                clientId = wifiNet:id()
            end
        end
        if XQFunction.isStrNil(clientId) then
            local iface = {
                device = wifiDev:name(),
                ifname = "apcli0",
                ssid = ssid,
                mode = "sta",
                encryption = encryption,
                key = key,
                network = "lan",
                disabled = "0"
            }
            wifiDev:add_wifinet(iface)
        else
            local wifiNet = wifiDev:get_wifinet(clientId)
            wifiNet:set("ssid", ssid)
            wifiNet:set("key", key)
            wifiNet:set("encryption", encryption)
        end
        LuciNetwork:save("wireless")
        LuciNetwork:commit("wireless")
        return true
    end
    return false
end
]]--
--[[
    @param wifiIndex:1/2  2.4G/5G
]]
--[[
function getWifiBridge(wifiIndex)
    local LuciNetwork = require("luci.model.network").init()
    local client
    local wifiDev = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(wifiIndex),".")[1])
    if wifiDev then
        local clientId
        for _, wifiNet in ipairs(wifiDev:get_wifinets()) do
            if wifiNet:active_mode() == "Client" then
                clientId = wifiNet:id()
            end
        end
        if clientId then
            local wifiNet = LuciNetwork:get_wifinet(clientId)
            if wifiNet:get("disabled") == "1" then
                return client
            end
            client = {}
            client["ssid"] = wifiNet:get("ssid")
            client["key"] = wifiNet:get("key")
            client["encryption"] = wifiNet:get("encryption")
            client["channel"] = wifiNet:get("channel")
        end
    end
    return client
end
]]--
--- model: 0/1  black/white list
function getWiFiMacfilterList(model)
    local uci = require("luci.model.uci").cursor()
    local config = tonumber(model) == 0 and "wifiblist" or "wifiwlist"
    local maclist = uci:get_list(config, "maclist", "mac") or {}
    return maclist
end

-- model: 0/1/2
-- 0 - Disable MAC address matching.
-- 1 - Deny association to stations on the MAC list.
-- 2 - Allow association to stations on the MAC list.

function getWiFiMacfilterModel()
    local LuciNetwork = require("luci.model.network").init()
    local wifiNet = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    local macfilter = wifiNet:get("macfilter")
    if macfilter == "disabled" then
        return 0
    elseif macfilter == "deny" then
        return 1
    elseif macfilter == "allow" then
        return 2
    else
        return 0
    end
end

function getCurrentMacfilterList()
    local LuciNetwork = require("luci.model.network").init()
    local wifiNet = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    return wifiNet:get("maclist")
end

--- 0/1/2 操作成功/数量超过限制/参数不正确
function addDevice(model, mac, name)
    local XQDBUtil = require("xiaoqiang.util.XQDBUtil")
    local XQSync = require("xiaoqiang.util.XQSynchrodata")
    if not XQFunction.isStrNil(mac) and not XQFunction.isStrNil(name) then
        mac = XQFunction.macFormat(mac)
        XQDBUtil.saveDeviceInfo(mac, name, name, "", "")
        local uci = require("luci.model.uci").cursor()
        local config = tonumber(model) == 0 and "wifiblist" or "wifiwlist"
        local maclist = uci:get_list(config, "maclist", "mac") or {}
        for _, macaddr in ipairs(maclist) do
            if mac == macaddr then
                return 0
            end
        end
        table.insert(maclist, mac)
        if #maclist > 32 then
            return 1
        end
        XQSync.syncDeviceInfo({["mac"] = mac, ["limited"] = 1})
        uci:set_list(config, "maclist", "mac", maclist)
        uci:commit(config)

        -- config
        local macfilter
        if tonumber(model) == 1 then
            macfilter = "allow"
        else
            macfilter = "deny"
        end
        --- Guest wifi
        local guestwifi = uci:get_all("wireless", "guest_2G")
        if guestwifi then
            guestwifi["macfilter"] = macfilter
            if maclist and #maclist > 0 then
                guestwifi["maclist"] = maclist
            else
                guestwifi["maclist"] = nil
                uci:delete("wireless", "guest_2G", "maclist")
            end
            uci:section("wireless", "wifi-iface", "guest_2G", guestwifi)
            uci:commit("wireless")
        end
        local LuciNetwork = require("luci.model.network").init()
        local wifiNet1 = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
        local wifiNet2 = LuciNetwork:get_wifinet(_wifiNameForIndex(2))
        if wifiNet1 then
            wifiNet1:set("macfilter", macfilter)
            if maclist and #maclist > 0 then
                wifiNet1:set_list("maclist", maclist)
            else
                wifiNet1:set_list("maclist", nil)
            end
        end
        if wifiNet2 then
            wifiNet2:set("macfilter", macfilter)
            if maclist and #maclist > 0 then
                wifiNet2:set_list("maclist", maclist)
            else
                wifiNet2:set_list("maclist", nil)
            end
        end
        LuciNetwork:save("wireless")
        LuciNetwork:commit("wireless")

        local macstr = XQFunction._cmdformat(mac)
        if tonumber(model) == 0 then
            os.execute("wl -i wl0 mac \""..macstr.."\"")
            os.execute("wl -i wl1 mac \""..macstr.."\"")
            os.execute("wl -i wl1.2 mac \""..macstr.."\"")
            os.execute("wl -i wl0 macmode 1")
            os.execute("wl -i wl1 macmode 1")
            os.execute("wl -i wl1.2 macmode 1")
            os.execute("wl -i wl0 deauthenticate \""..macstr.."\"")
            os.execute("wl -i wl1 deauthenticate \""..macstr.."\"")
            os.execute("wl -i wl1.2 deauthenticate \""..macstr.."\"")
        elseif tonumber(model) == 1 then
            os.execute("wl -i wl0 mac \""..macstr.."\"")
            os.execute("wl -i wl1 mac \""..macstr.."\"")
            os.execute("wl -i wl1.2 mac \""..macstr.."\"")
            os.execute("wl -i wl0 macmode 2")
            os.execute("wl -i wl1 macmode 2")
            os.execute("wl -i wl1.2 macmode 2")
        end
        return 0
    else
        return 2
    end
end

--- private function
--- model: 0/1  black/white list
--- option: 0/1 add/remove
function wl_editWiFiMacfilterList(model, macs, option)
    if not macs or XQFunction.isStrNil(option) then
        return
    end
    local XQSync = require("xiaoqiang.util.XQSynchrodata")
    local uci = require("luci.model.uci").cursor()
    local config = tonumber(model) == 0 and "wifiblist" or "wifiwlist"
    local maclist = uci:get_list(config, "maclist", "mac") or {}
    local cmodel = getWiFiMacfilterModel()
    local current = getCurrentMacfilterList()

    if option == 0 then
        local macdic = {}
        for _, macaddr in ipairs(maclist) do
            macdic[XQFunction.macFormat(macaddr)] = 1
        end
        for _, macaddr in ipairs(macs) do
            if not XQFunction.isStrNil(macaddr) then
                macdic[XQFunction.macFormat(macaddr)] = 1
            end
        end
        maclist = {}
        for mac, value in pairs(macdic) do
            if value == 1 then
                table.insert(maclist, mac)
            end
        end
        if #maclist > 32 then
            return 1
        end
    else
        local macdic = {}
        for _, macaddr in ipairs(maclist) do
            macdic[XQFunction.macFormat(macaddr)] = 1
        end
        for _, macaddr in ipairs(macs) do
            if not XQFunction.isStrNil(macaddr) then
                macdic[XQFunction.macFormat(macaddr)] = 0
            end
        end
        maclist = {}
        for mac, value in pairs(macdic) do
            if value == 1 then
                table.insert(maclist, mac)
            end
        end
    end

    if model == 0 then
        local dict = {}
        local needsync = {}
        if current then
            for _, mac in ipairs(current) do
                dict[XQFunction.macFormat(mac)] = 1
            end
        end
        if option == 0 then
            for _, mac in ipairs(macs) do
                mac = XQFunction.macFormat(mac)
                if not dict[mac] then
                    needsync[mac] = 1
                end
            end
        elseif option == 1 then
            for _, mac in ipairs(macs) do
                mac = XQFunction.macFormat(mac)
                if dict[mac] then
                    needsync[mac] = 0
                end
            end
        end
        for mac, limited in pairs(needsync) do
            XQSync.syncDeviceInfo({["mac"] = mac, ["limited"] = limited})
        end
    end

    os.execute("wl -i wl0 mac none")
    os.execute("wl -i wl1 mac none")
    os.execute("wl -i wl1.2 mac none")
    local nmaclist = {}
    for _, value in ipairs(maclist) do
        local nvalue = XQFunction._cmdformat(value)
        table.insert(nmaclist, nvalue)
    end
    local macstr = table.concat(nmaclist, "\" \"")
    if tonumber(model) == 0 then
        os.execute("wl -i wl0 mac \""..macstr.."\"")
        os.execute("wl -i wl1 mac \""..macstr.."\"")
        os.execute("wl -i wl1.2 mac \""..macstr.."\"")
        os.execute("wl -i wl0 macmode 1")
        os.execute("wl -i wl1 macmode 1")
        os.execute("wl -i wl1.2 macmode 1")
        for _, value in ipairs(nmaclist) do
            os.execute("wl -i wl0 deauthenticate \""..value.."\"")
            os.execute("wl -i wl1 deauthenticate \""..value.."\"")
            os.execute("wl -i wl1.2 deauthenticate \""..value.."\"")
        end
    elseif tonumber(model) == 1 then
        os.execute("wl -i wl0 mac \""..macstr.."\"")
        os.execute("wl -i wl1 mac \""..macstr.."\"")
        os.execute("wl -i wl1.2 mac \""..macstr.."\"")
        os.execute("wl -i wl0 macmode 2")
        os.execute("wl -i wl1 macmode 2")
        os.execute("wl -i wl1.2 macmode 2")
    end
    if #maclist > 0 then
        uci:set_list(config, "maclist", "mac", maclist)
    else
        uci:delete(config, "maclist", "mac")
    end
    uci:commit(config)
    -- wireless
    local macfilter
    if tonumber(model) == 1 then
        macfilter = "allow"
    else
        macfilter = "deny"
    end
    -- Guest wifi
    local guestwifi = uci:get_all("wireless", "guest_2G")
    if guestwifi then
        guestwifi["macfilter"] = macfilter
        if maclist and #maclist > 0 then
            guestwifi["maclist"] = maclist
        else
            guestwifi["maclist"] = nil
            uci:delete("wireless", "guest_2G", "maclist")
        end
        uci:section("wireless", "wifi-iface", "guest_2G", guestwifi)
        uci:commit("wireless")
    end
    local LuciNetwork = require("luci.model.network").init()
    local wifiNet1 = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    local wifiNet2 = LuciNetwork:get_wifinet(_wifiNameForIndex(2))
    if wifiNet1 then
        wifiNet1:set("macfilter", macfilter)
        if maclist and #maclist > 0 then
            wifiNet1:set_list("maclist", maclist)
        else
            wifiNet1:set_list("maclist", nil)
        end
    end
    if wifiNet2 then
        wifiNet2:set("macfilter", macfilter)
        if maclist and #maclist > 0 then
            wifiNet2:set_list("maclist", maclist)
        else
            wifiNet2:set_list("maclist", nil)
        end
    end
    LuciNetwork:save("wireless")
    LuciNetwork:commit("wireless")
    os.execute("ubus call trafficd update_assoclist")
end

--- private function
--- 0/1/2 操作成功/数量超过限制/参数不正确
--- model: 0/1  black/white list
--- macs: mac address array
--- option: 0/1 add/remove
function iwpriv_editWiFiMacfilterList(model, macs, option)
    local XQSync = require("xiaoqiang.util.XQSynchrodata")
    if not macs or type(macs) ~= "table" or XQFunction.isStrNil(option) then
        return 2
    end
    local uci = require("luci.model.uci").cursor()
    local config = tonumber(model) == 0 and "wifiblist" or "wifiwlist"
    local maclist = uci:get_list(config, "maclist", "mac") or {}
    local current = getCurrentMacfilterList()
    if option == 0 then
        local macdic = {}
        for _, macaddr in ipairs(maclist) do
            macdic[XQFunction.macFormat(macaddr)] = 1
        end
        for _, macaddr in ipairs(macs) do
            if not XQFunction.isStrNil(macaddr) then
                macdic[XQFunction.macFormat(macaddr)] = 1
            end
        end
        maclist = {}
        for mac, value in pairs(macdic) do
            if value == 1 then
                table.insert(maclist, mac)
            end
        end
        if #maclist > 32 then
            return 1
        end
    else
        local macdic = {}
        for _, macaddr in ipairs(maclist) do
            macdic[XQFunction.macFormat(macaddr)] = 1
        end
        for _, macaddr in ipairs(macs) do
            if not XQFunction.isStrNil(macaddr) then
                macdic[XQFunction.macFormat(macaddr)] = 0
            end
        end
        maclist = {}
        for mac, value in pairs(macdic) do
            if value == 1 then
                table.insert(maclist, mac)
            end
        end
    end

    if model == 0 then
        local dict = {}
        local needsync = {}
        if current then
            for _, mac in ipairs(current) do
                dict[XQFunction.macFormat(mac)] = 1
            end
        end
        if option == 0 then
            for _, mac in ipairs(macs) do
                mac = XQFunction.macFormat(mac)
                if not dict[mac] then
                    needsync[mac] = 1
                end
            end
        elseif option == 1 then
            for _, mac in ipairs(macs) do
                mac = XQFunction.macFormat(mac)
                if dict[mac] then
                    needsync[mac] = 0
                end
            end
        end
        for mac, limited in pairs(needsync) do
            XQSync.syncDeviceInfo({["mac"] = mac, ["limited"] = limited})
        end
    end
    -- local macstr = XQFunction._cmdformat(table.concat(maclist, ";"))
    -- os.execute("iwpriv wl0 set ACLClearAll=1")
    -- os.execute("iwpriv wl1 set ACLClearAll=1")
    -- os.execute("iwpriv wl3 set ACLClearAll=1")
    -- if tonumber(model) == 0 then
    --     for _, mac in ipairs(maclist) do
    --         local cmac = XQFunction._cmdformat(mac)
    --         os.execute("iwpriv wl0 set DisConnectSta=\""..cmac.."\"")
    --         os.execute("iwpriv wl1 set DisConnectSta=\""..cmac.."\"")
    --         os.execute("iwpriv wl3 set DisConnectSta=\""..cmac.."\"")
    --     end
    -- end
    -- os.execute("iwpriv wl0 set ACLAddEntry=\""..macstr.."\"")
    -- os.execute("iwpriv wl1 set ACLAddEntry=\""..macstr.."\"")
    -- os.execute("iwpriv wl3 set ACLAddEntry=\""..macstr.."\"")

    -- if tonumber(model) == 0 then
    --     os.execute("iwpriv wl0 set AccessPolicy=2")
    --     os.execute("iwpriv wl1 set AccessPolicy=2")
    --     os.execute("iwpriv wl3 set AccessPolicy=2")
    -- else
    --     os.execute("iwpriv wl0 set AccessPolicy=1")
    --     os.execute("iwpriv wl1 set AccessPolicy=1")
    --     os.execute("iwpriv wl3 set AccessPolicy=1")
    -- end
    if #maclist > 0 then
        uci:set_list(config, "maclist", "mac", maclist)
    else
        uci:delete(config, "maclist", "mac")
        -- os.execute("iwpriv wl0 set AccessPolicy=0")
        -- os.execute("iwpriv wl1 set AccessPolicy=0")
        -- os.execute("iwpriv wl3 set AccessPolicy=0")
    end
    uci:commit(config)
    -- wireless
    local macfilter
    if tonumber(model) == 1 then
        macfilter = "allow"
    else
        macfilter = "deny"
    end
    -- Guest wifi
    local guestwifi = uci:get_all("wireless", "guest_2G")
    if guestwifi then
        guestwifi["macfilter"] = macfilter
        if maclist and #maclist > 0 then
            guestwifi["maclist"] = maclist
        else
            guestwifi["maclist"] = nil
            uci:delete("wireless", "guest_2G", "maclist")
        end
        uci:section("wireless", "wifi-iface", "guest_2G", guestwifi)
        uci:commit("wireless")
    end
    local LuciNetwork = require("luci.model.network").init()
    local wifiNet1 = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    local wifiNet2 = LuciNetwork:get_wifinet(_wifiNameForIndex(2))
    if wifiNet1 then
        wifiNet1:set("macfilter", macfilter)
        if maclist and #maclist > 0 then
            wifiNet1:set_list("maclist", maclist)
        else
            wifiNet1:set_list("maclist", nil)
        end
    end
    if wifiNet2 then
        wifiNet2:set("macfilter", macfilter)
        if maclist and #maclist > 0 then
            wifiNet2:set_list("maclist", maclist)
        else
            wifiNet2:set_list("maclist", nil)
        end
    end
    LuciNetwork:save("wireless")
    LuciNetwork:commit("wireless")
    -- os.execute("ubus call trafficd update_assoclist")
    local json = require("json")
    local payload = json.encode({
        ["model"] = model,
        ["maclist"] = maclist
    })
    XQFunction.forkExec("lua /usr/sbin/iwpriv_macfilter.lua 2 \""..XQFunction._cmdformat(payload).."\"")
    return 0
end

--- model: 0/1  black/white list
--- option: 0/1 add/remove
editWiFiMacfilterList = wl_editWiFiMacfilterList

if HARDWARE:match("^r1c") then
    editWiFiMacfilterList = iwpriv_editWiFiMacfilterList
end

--- 2015.7.31, auth default: false->true (PM:cy)
--- model: 0/1  black/white list
function getWiFiMacfilterInfo(model)
    local LuciUtil      = require("luci.util")
    local LuciNetwork   = require("luci.model.network").init()
    local XQDBUtil      = require("xiaoqiang.util.XQDBUtil")
    local XQEquipment   = require("xiaoqiang.XQEquipment")
    local XQPushUtil    = require("xiaoqiang.util.XQPushUtil")
    local wifiNet = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    local settings = XQPushUtil.pushSettings()
    local info = {
        ["enable"] = settings.auth and 1 or 0,
        ["model"] = 0
    }
    if wifiNet then
        local macfilter = wifiNet:get("macfilter")
        if macfilter == "disabled" then
            info["model"] = 0
        elseif macfilter == "deny" then
            info["model"] = 0
        elseif macfilter == "allow" then
            info["model"] = 1
        else
            info["model"] = 0
        end
    end
    local maclist = {}
    local mlist = getWiFiMacfilterList(model == nil and info.model or model)
    for _, mac in ipairs(mlist) do
        mac = XQFunction.macFormat(mac)
        local item = {
            ["mac"] = mac
        }
        local name = ""
        local device = XQDBUtil.fetchDeviceInfo(mac)
        if device then
            local originName = device.oName
            local nickName = device.nickname
            if not XQFunction.isStrNil(nickName) then
                name = nickName
            else
                local company = XQEquipment.identifyDevice(mac, originName)
                local dtype = company["type"]
                if XQFunction.isStrNil(name) and not XQFunction.isStrNil(dtype.n) then
                    name = dtype.n
                end
                if XQFunction.isStrNil(name) and not XQFunction.isStrNil(originName) then
                    name = originName
                end
                if XQFunction.isStrNil(name) and not XQFunction.isStrNil(company.name) then
                    name = company.name
                end
                if XQFunction.isStrNil(name) then
                    name = mac
                end
                if dtype.c == 3 and XQFunction.isStrNil(nickName) then
                    name = dtype.n
                end
            end
            item["name"] = name
        end
        table.insert(maclist, item)
    end
    info["maclist"] = maclist
    info["weblist"] = mlist
    return info
end

--- model: 0/1  black/white list
function setWiFiMacfilterModel(enable, model)
    local macfilter
    local maclist
    if enable then
        if tonumber(model) == 1 then
            macfilter = "allow"
            maclist = getWiFiMacfilterList(1)
        else
            macfilter = "deny"
            maclist = getWiFiMacfilterList(0)
        end
    else
        macfilter = "disabled"
        local XQPushUtil = require("xiaoqiang.util.XQPushUtil")
        XQPushUtil.pushConfig("auth", "0")
    end
    -- Guest wifi
    local uci = require("luci.model.uci").cursor()
    local guestwifi = uci:get_all("wireless", "guest_2G")
    if guestwifi then
        guestwifi["macfilter"] = macfilter
        if maclist and #maclist > 0 then
            guestwifi["maclist"] = maclist
        else
            guestwifi["maclist"] = nil
            uci:delete("wireless", "guest_2G", "maclist")
        end
        uci:section("wireless", "wifi-iface", "guest_2G", guestwifi)
        uci:commit("wireless")
    end
    local LuciUtil = require("luci.util")
    local LuciNetwork = require("luci.model.network").init()
    local wifiNet1 = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    local wifiNet2 = LuciNetwork:get_wifinet(_wifiNameForIndex(2))
    if wifiNet1 then
        wifiNet1:set("macfilter", macfilter)
        if maclist and #maclist > 0 then
            wifiNet1:set_list("maclist", maclist)
        else
            wifiNet1:set_list("maclist", nil)
        end
    end
    if wifiNet2 then
        wifiNet2:set("macfilter", macfilter)
        if maclist and #maclist > 0 then
            wifiNet2:set_list("maclist", maclist)
        else
            wifiNet2:set_list("maclist", nil)
        end
    end
    LuciNetwork:save("wireless")
    LuciNetwork:commit("wireless")
    local wifi1 = getWifiConnectDeviceList(1)
    local wifi2 = getWifiConnectDeviceList(2)
    local macdict = {}
    if maclist and type(maclist) == "table" then
        for _, value in ipairs(maclist) do
            if value then
                macdict[value] = true
            end
        end
    end
    if not enable then
        if HARDWARE:match("^r1c") then
            -- os.execute("iwpriv wl0 set ACLClearAll=1")
            -- os.execute("iwpriv wl1 set ACLClearAll=1")
            -- os.execute("iwpriv wl3 set ACLClearAll=1")
            -- os.execute("iwpriv wl0 set AccessPolicy=0")
            -- os.execute("iwpriv wl1 set AccessPolicy=0")
            -- os.execute("iwpriv wl3 set AccessPolicy=0")
            local cmd = [[
                sleep 2;
                iwpriv wl0 set ACLClearAll=1;
                iwpriv wl1 set ACLClearAll=1;
                iwpriv wl3 set ACLClearAll=1;
                iwpriv wl0 set AccessPolicy=0;
                iwpriv wl1 set AccessPolicy=0;
                iwpriv wl3 set AccessPolicy=0
            ]]
            XQFunction.forkExec(cmd)
        else
            os.execute("wl -i wl0 mac none")
            os.execute("wl -i wl1 mac none")
            os.execute("wl -i wl1.2 mac none")
            os.execute("wl -i wl0 macmode 0")
            os.execute("wl -i wl1 macmode 0")
            os.execute("wl -i wl1.2 macmode 0")
            uci:delete("wireless", "guest", "maclist")
            uci:set("wireless", "guest", "macfilter", macfilter)
            uci:commit("wireless")
        end
    else
        if HARDWARE:match("^r1c") then
            -- local macstr = XQFunction._cmdformat(table.concat(maclist, ";"))
            -- os.execute("iwpriv wl0 set ACLClearAll=1")
            -- os.execute("iwpriv wl1 set ACLClearAll=1")
            -- os.execute("iwpriv wl3 set ACLClearAll=1")
            -- os.execute("iwpriv wl0 set ACLAddEntry=\""..macstr.."\"")
            -- os.execute("iwpriv wl1 set ACLAddEntry=\""..macstr.."\"")
            -- os.execute("iwpriv wl3 set ACLAddEntry=\""..macstr.."\"")

            -- if tonumber(model) == 0 then
            --     os.execute("iwpriv wl0 set AccessPolicy=2")
            --     os.execute("iwpriv wl1 set AccessPolicy=2")
            --     os.execute("iwpriv wl3 set AccessPolicy=2")
            --     for _, mac in ipairs(maclist) do
            --         local cmac = XQFunction._cmdformat(mac)
            --         os.execute("iwpriv wl0 set DisConnectSta=\""..cmac.."\"")
            --         os.execute("iwpriv wl1 set DisConnectSta=\""..cmac.."\"")
            --         os.execute("iwpriv wl3 set DisConnectSta=\""..cmac.."\"")
            --     end
            -- else
            --     os.execute("iwpriv wl0 set AccessPolicy=1")
            --     os.execute("iwpriv wl1 set AccessPolicy=1")
            --     os.execute("iwpriv wl3 set AccessPolicy=1")
            --     if wifi1 and type(wifi1) == "table" then
            --         for _, value in ipairs(wifi1) do
            --             if not macdict[value] then
            --                 local cmac = XQFunction._cmdformat(value)
            --                 os.execute("iwpriv wl1 set DisConnectSta=\""..cmac.."\"")
            --             end
            --         end
            --     end
            --     if wifi2 and type(wifi2) == "table" then
            --         for _, value in ipairs(wifi2) do
            --             if not macdict[value] then
            --                 local cmac = XQFunction._cmdformat(value)
            --                 os.execute("iwpriv wl0 set DisConnectSta=\""..cmac.."\"")
            --             end
            --         end
            --     end
            -- end
            local json = require("json")
            local payload = json.encode({
                ["model"] = model,
                ["maclist"] = maclist
            })
            XQFunction.forkExec("lua /usr/sbin/iwpriv_macfilter.lua 2 \""..XQFunction._cmdformat(payload).."\"")
        else
            os.execute("wl -i wl0 mac none")
            os.execute("wl -i wl1 mac none")
            os.execute("wl -i wl1.2 mac none")
            local nmaclist = {}
            for _, value in ipairs(maclist) do
                local nvalue = XQFunction._cmdformat(value)
                table.insert(nmaclist, nvalue)
            end
            local macstr = table.concat(nmaclist, "\" \"")
            if tonumber(model) == 0 then
                os.execute("wl -i wl0 mac \""..macstr.."\"")
                os.execute("wl -i wl1 mac \""..macstr.."\"")
                os.execute("wl -i wl1.2 mac \""..macstr.."\"")
                os.execute("wl -i wl0 macmode 1")
                os.execute("wl -i wl1 macmode 1")
                os.execute("wl -i wl1.2 macmode 1")
                for _, value in ipairs(nmaclist) do
                    os.execute("wl -i wl0 deauthenticate \""..value.."\"")
                    os.execute("wl -i wl1 deauthenticate \""..value.."\"")
                    os.execute("wl -i wl1.2 deauthenticate \""..value.."\"")
                end
            elseif tonumber(model) == 1 then
                os.execute("wl -i wl0 mac \""..macstr.."\"")
                os.execute("wl -i wl1 mac \""..macstr.."\"")
                os.execute("wl -i wl1.2 mac \""..macstr.."\"")
                os.execute("wl -i wl0 macmode 2")
                os.execute("wl -i wl1 macmode 2")
                os.execute("wl -i wl1.2 macmode 2")
                if wifi1 and type(wifi1) == "table" then
                    for _, value in ipairs(wifi1) do
                        if not macdict[value] then
                            local cmac = XQFunction._cmdformat(value)
                            os.execute("wl -i wl1 deauthenticate \""..cmac.."\"")
                        end
                    end
                end
                if wifi2 and type(wifi2) == "table" then
                    for _, value in ipairs(wifi2) do
                        if not macdict[value] then
                            local cmac = XQFunction._cmdformat(value)
                            os.execute("wl -i wl0 deauthenticate \""..cmac.."\"")
                        end
                    end
                end
                local assoclist = LuciUtil.execl("wl -i wl1.2 assoclist")
                if assoclist then
                    for _, line in ipairs(assoclist) do
                        if not XQFunction.isStrNil(line) then
                            local mac = line:match("assoclist (%S+)")
                            if mac then
                                mac = XQFunction._cmdformat(XQFunction.macFormat(mac))
                                os.execute("wl -i wl1.2 deauthenticate \""..mac.."\"")
                            end
                        end
                    end
                end
            end
        end
    end
end

function getGuestWifi(wifiIndex)
    local uci = require("luci.model.uci").cursor()
    local guest_wifi = uci:get("misc", "modules", "guestwifi")
    if not guest_wifi then
        return nil
    end
    local index = tonumber(wifiIndex)
    local status
    if index then
        status = getWifiStatus(index)
        if index == 1 then
            index = "guest_2G"
        elseif index == 2 then
            index = "guest_5G"
        else
            index = nil
        end
    end
    local guestwifi
    local defaultMac = require("xiaoqiang.util.XQLanWanUtil").getDefaultMacAddress()
    local ssidSuffix = string.sub(string.gsub(defaultMac,":",""), -4)
    if index and status then
        guestwifi = uci:get_all("wireless", index)
        if guestwifi then
            return {
                ["ifname"]      = guestwifi.ifname,
                ["ssid"]        = guestwifi.ssid or "Xiaomi_".. ssidSuffix.."_VIP",
                ["encryption"]  = guestwifi.encryption or "mixed-psk",
                ["password"]    = guestwifi.key or "12345678",
                ["status"]      = tonumber(guestwifi.disabled) == 0 and 1 or 0,
                ["enabled"]     = "1"
            }
        end
    end
    if not guestwifi then
        guestwifi = {
            ["ifname"]      = guest_wifi,
            ["ssid"]        = "Xiaomi_".. ssidSuffix.."_VIP",
            ["encryption"]  = "mixed-psk",
            ["password"]    = "12345678",
            ["status"]      = "0",
            ["enabled"]     = "1"
        }
    end
    return guestwifi
end

function setGuestWifi(wifiIndex, ssid, encryption, key, enabled, open, wps)
    local LuciNetwork = require("luci.model.network").init()
    local wifiDev = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(1),".")[1])
    local wifiNet = LuciNetwork:get_wifinet(_wifiNameForIndex(1))
    local macfilter = wifiNet:get("macfilter")
    local open = tonumber(open)
    local disabled = tonumber(wifiDev:get("disabled")) == 1
    if disabled and open == 1 then
        local bsd = wifiNet:get("bsd")
        if bsd and tonumber(bsd) == 1 then
            local wifiDev2 = LuciNetwork:get_wifidev(LuciUtil.split(_wifiNameForIndex(2),".")[1])
            if wifiDev2 then
                wifiDev2:set("disabled", "0")
            end
        end
        wifiDev:set("disabled", "0")
        LuciNetwork:commit("wireless")
    end

    local uci = require("luci.model.uci").cursor()
    local wifinetid, ifname
    local enabled = tonumber(enabled) == 1 and 1 or 0

    local guest_wifi = uci:get("misc", "modules", "guestwifi")
    if not guest_wifi then
        return true
    end

    if tonumber(wifiIndex) == 1 then
        wifinetid = "guest_2G"
        ifname = uci:get("misc", "wireless", "ifname_guest_2G")
    elseif tonumber(wifiIndex) == 2 then
        wifinetid = "guest_5G"
    else
        return false
    end
    guestwifi = uci:get_all("wireless", wifinetid)
    if guestwifi then
        guestwifi["ifname"] = ifname
        if not XQFunction.isStrNil(ssid) and XQFunction.checkSSID(ssid) then
            guestwifi["ssid"] = ssid
        end
        if encryption and string.lower(tostring(encryption)) == "none" then
            guestwifi["encryption"] = "none"
            guestwifi["key"] = ""
        end
        if encryption and string.lower(tostring(encryption)) ~= "none" and not XQFunction.isStrNil(key) then
            local check = checkWifiPasswd(key,encryption)
            if check == 0 then
                guestwifi["encryption"] = encryption
                guestwifi["key"] = key
            else
                return false
            end
        end
        local oldconf = guestwifi.disabled or 1
        if enabled then
            guestwifi["disabled"] = enabled == 1 and 0 or 1
        end
        if open then
            guestwifi["disabled"] = open == 1 and 0 or 1
        end
        if oldconf ~= guestwifi.disabled then
            if guestwifi.disabled == 1 then
                os.execute(string.format("wl -i %s bss down; ifconfig %s down", ifname, ifname))
            else
                XQFunction.forkExec(string.format("wl -i %s bss up; ifconfig %s up", ifname, ifname))
            end
        end
    else
        if XQFunction.isStrNil(ssid) or XQFunction.isStrNil(encryption) then
            return false
        end
        local gdisabled = 1
        if open == 1 then
            gdisabled = 0
        end
        guestwifi = {
            ["device"] = WIFI_DEVS[wifiIndex],
            ["ifname"] = ifname,
            ["network"] = "guest",
            ["ssid"] = ssid,
            ["mode"] = "ap",
            ["encryption"] = encryption,
            ["key"] = key,
            ["macfilter"] = macfilter,
            ["maclist"] = getCurrentMacfilterList(),
            ["disabled"] = gdisabled
        }
        if guestwifi.disabled == 1 then
            os.execute(string.format("wl -i %s bss down; ifconfig %s down", ifname, ifname))
        else
            XQFunction.forkExec(string.format("wl -i %s bss up; ifconfig %s up", ifname, ifname))
        end
    end
    guestwifi["wpsdevicename"] = wps or "XIAOMI_ROUTER_GUEST"
    uci:section("wireless", "wifi-iface", wifinetid, guestwifi)
    uci:commit("wireless")
    return true
end

function delGuestWifi(wifiIndex)
    local uci = require("luci.model.uci").cursor()
    local wifinetid
    if tonumber(wifiIndex) == 1 then
        wifinetid = "guest_2G"
    elseif tonumber(wifiIndex) == 2 then
        wifinetid = "guest_5G"
    else
        return false
    end
    uci:delete("wireless", wifinetid)
    uci:commit("wireless")
    return true
end

function scanWifiChannel(wifiIndex)
    local result = {["code"] = 0}
    local cchannel, schannel, cscore, sscore
    local wifi = tonumber(wifiIndex) == 1 and "wl1" or "wl0"
    local scancmd = "iwpriv "..tostring(wifi).." ScanResult"
    local scanresult = LuciUtil.execl(scancmd)
    local scandict = {}
    if scanresult then
        for _, line in ipairs(scanresult) do
            if not XQFunction.isStrNil(line) then
                if not cchannel or not cscore then
                    cchannel, cscore = line:match("^Current Channel (%S+) : Score = (%d+)")
                end
                if not schannel or not sscore then
                    schannel, sscore = line:match("^Select Channel (%S+) : Score = (%d+)")
                end
                local ichannel, iscore = line:match("^Channel (%S+) : Score = (%d+)")
                if ichannel and iscore then
                    scandict[ichannel] = tonumber(iscore)
                end
            end
        end
    end

    if cchannel and schannel and cscore and sscore then
        result["cchannel"] = tostring(cchannel)
        result["schannel"] = tostring(schannel)
        result["cscore"] = tonumber(cscore)
        result["sscore"] = tonumber(sscore)
        local ranking = 1
        for key, value in pairs(scandict) do
            if key ~= cchannel then
                if result.cscore > value then
                    ranking = ranking + 1
                end
            end
        end
        result["ranking"] = ranking
    else
        result["code"] = 1
        result["cchannel"] = tostring(cchannel) or ""
        result["schannel"] = tostring(schannel) or ""
        result["cscore"] = tonumber(cscore) or 0
        result["sscore"] = tonumber(sscore) or 0
        result["ranking"] = 0
    end
    return result
end

function wifiChannelQuality()
    local wifiinfo = getAllWifiInfo()
    if wifiinfo[1] and wifiinfo[1].status == "1" then
        XQFunction.forkExec("sleep 4; iwpriv wl1 set AutoChannelSel=3")
    end
    if wifiinfo[2] and wifiinfo[2].status == "1" then
        XQFunction.forkExec("sleep 4; iwpriv wl0 set AutoChannelSel=3")
    end
end

function iwprivSetChannel(channel1, channel2)
    if channel1 then
        local setcmd = "sleep 4; iwpriv wl1 set Channel="..tostring(channel1)
        local chinf = channelHelper(channel1)
        local network = LuciNetwork.init()
        local wifiDev = network:get_wifidev(LuciUtil.split(_wifiNameForIndex(1),".")[1])
        wifiDev:set("bw", chinf.bandwidth)
        wifiDev:set("autoch","0")
        wifiDev:set("channel", chinf.channel)
        network:commit("wireless")
        XQFunction.forkExec(setcmd)
    end
    --[[
    if channel2 then
        local setcmd = "sleep 4; iwpriv wl0 set Channel="..tostring(channel2)
        XQFunction.forkExec(setcmd)
    end
    ]]--
end

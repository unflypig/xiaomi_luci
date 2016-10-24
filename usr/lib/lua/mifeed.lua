module ("mifeed", package.seeall)

local Json = require("json")
local LuciDatatypes = require("luci.cbi.datatypes")
local XQFunction = require("xiaoqiang.common.XQFunction")

local MAX_INTERVAL = 8640000

function _formatStr(str)
    local str = string.gsub(str,"\"","\\\"")
    str = string.gsub(str, ";", "\\;")
    str = string.gsub(str, "&", "\\&")
    return str:gsub(" ", "")
end

function _feed(mac, payload)
    if not LuciDatatypes.macaddr(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    if payload then
        payload = _formatStr(Json.encode(payload))
    end
    local cmd = "/usr/bin/timeout -t 4 /usr/bin/matool --method devicelog --params "..mac.." "..payload
    os.execute(cmd)
end

function _wirelessdeviceInfo(isonlie)
    local uci = require("luci.model.uci").cursor()
    if isonlie then
        local online = uci:get_all("wirelessdevice", "online")
        if not online then
            online = {}
            uci:section("wirelessdevice", "record", "online", {})
            uci:commit("wirelessdevice")
        else
            local tonline = {}
            for key, value in pairs(online) do
                if not key:match("^%.") then
                    tonline[key] = value
                end
            end
            online = tonline
        end
        return online
    else
        local offline = uci:get_all("wirelessdevice", "offline")
        if not offline then
            offline = {}
            uci:section("wirelessdevice", "record", "offline", {})
            uci:commit("wirelessdevice")
        else
            local toffline = {}
            for key, value in pairs(offline) do
                if not key:match("^%.") then
                    toffline[key] = value
                end
            end
            offline = toffline
        end
        return offline
    end
end

function _addrecord(mac, dev, isonline)
    local uci = require("luci.model.uci").cursor()
    local mackey = mac:gsub(":", "")
    if isonline then
        local online = uci:get_all("wirelessdevice", "online")
        local ifname = uci:get_all("wirelessdevice", "ifname")
        if not online then
            online = {[mackey] = os.time()}
            uci:section("wirelessdevice", "record", "online", online)
        else
            uci:set("wirelessdevice", "online", mackey, os.time())
        end
        if not ifname then
            ifname = {[mackey] = dev}
            uci:section("wirelessdevice", "record", "ifname", ifname)
        else
            uci:set("wirelessdevice", "ifname", mackey, dev)
        end
    else
        local offline = uci:get_all("wirelessdevice", "offline")
        if not offline then
            offline = {[mackey] = os.time()}
            uci:section("wirelessdevice", "record", "offline", offline)
        else
            uci:set("wirelessdevice", "offline", mackey, os.time())
        end
    end
    uci:commit("wirelessdevice")
end

function _hookWifiConnect(data)
    if not LuciDatatypes.macaddr(data.mac) then
        return
    end
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local mackey = data.mac:gsub(":", "")
    local onlinerecords = _wirelessdeviceInfo(true)
    local offlinerecords = _wirelessdeviceInfo(false)
    local onlinerecord = onlinerecords[mackey]
    local offlinerecord = offlinerecords[mackey]
    _addrecord(data.mac, data.dev, true)
    if onlinerecord then
        local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
        local current = os.time()
        local payload = {
            ["location"] = XQSysUtil.getRouterLocale()
        }
        if os.date("%x",current) == os.date("%x", tonumber(onlinerecord)) and offlinerecord then
            local time = current - tonumber(offlinerecord)
            if time < 0 or time > MAX_INTERVAL then
                return
            end
            payload["id"] = 3
            payload["time"] = time
        else
            payload["id"] = 2
        end
        _feed(data.mac, payload)
    else
        -- new device
        local deviceinfo = XQDeviceUtil.getDeviceInfo(data.mac)
        if XQFunction.isStrNil(deviceinfo.dhcpname) then
            os.execute("sleep 5")
            deviceinfo = XQDeviceUtil.getDeviceInfo(mac)
        end
        local count = 0
        for _, _ in pairs(onlinerecords) do
            count = count + 1
        end
        local payload = {
            ["id"] = 1,
            ["name"] = deviceinfo.name,
            ["order"] = count + 1
        }
        _feed(data.mac, payload)
    end
end

function _hookWifiDisconnect(data)
    if not LuciDatatypes.macaddr(data.mac) then
        return
    end
    local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
    local mackey = data.mac:gsub(":", "")
    local onlinerecords = _wirelessdeviceInfo(true)
    local offlinerecords = _wirelessdeviceInfo(false)
    local onlinerecord = onlinerecords[mackey]
    local offlinerecord = offlinerecords[mackey]
    local payload = {
        ["location"] = XQSysUtil.getRouterLocale()
    }
    _addrecord(data.mac, data.dev, false)
    if offlinerecord then
        local current = os.time()
        if os.date("%x",current) == os.date("%x", tonumber(offlinerecord)) and onlinerecord then
            local time = current - tonumber(onlinerecord)
            if time < 0 or time > MAX_INTERVAL then
                return
            end
            payload["id"] = 5
            payload["time"] = time
        else
            payload["id"] = 4
        end
    else
        payload["id"] = 4
    end
    _feed(data.mac, payload)
end

function feed(payload)
    if XQFunction.isStrNil(payload) then
        return
    end
    local payload = Json.decode(payload)
    local feedtype = tonumber(payload["type"])
    if feedtype == 1 then
        _hookWifiConnect(payload.data)
    elseif feedtype == 2 then
        _hookWifiDisconnect(payload.data)
    end
end

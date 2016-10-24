
local posix = require("posix")
local sys = require("luci.sys")
local lutil = require("luci.util")
local datatypes = require("luci.cbi.datatypes")

local map = {
    1,2
}

function log(...)
    posix.openlog("tra_controller", "np", LOG_USER)
    for i, v in ipairs({...}) do
        posix.syslog(4, lutil.serialize_data(v))
    end
    posix.closelog()
end

function master()
    local uci = require("luci.model.uci").cursor()
    local mode = uci:get("xiaoqiang", "common", "NETMODE")
    if mode then
        return false
    else
        return true
    end
end

function permission(env)
    local mac, lan, wan, admin, pridisk = env.mac, env.lan, env.wan, env.admin, env.pridisk
    if mac and datatypes.macaddr(mac) then
        local xqsys = require("xiaoqiang.util.XQSysUtil")
        xqsys.setMacFilter(mac, lan, wan, admin, pridisk)
    end
end

function wifimacfilter(env)
    local wifi = require("xiaoqiang.util.XQWifiUtil")
    local mac, enable, model, option = env.mac, env.enable, env.model, env.option
    if mac and (datatypes.macaddr(mac) or mac:match(";")) then
        local macs = lutil.split(mac, ";")
        wifi.editWiFiMacfilterList(model, macs, option)
    else
        wifi.setWiFiMacfilterModel(enable, model)
    end
end

function dispatcher(env)
    local api = tonumber(env.api)
    if api == 1 then
        permission(env)
    elseif api == 2 then
        wifimacfilter(env)
    end
end

local env = sys.getenv()

log(env)

if env.api and tonumber(env.api) and map[tonumber(env.api)] then
    if not master() then
        dispatcher(env)
    else
        log("Master : Request ignored")
    end
else
    log("api not exist!!!")
end

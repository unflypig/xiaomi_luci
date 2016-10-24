module ("xiaoqiang.module.XQWifiShare", package.seeall)

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")
local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
local LuciUtil = require("luci.util")

local INTERVAL = 1800
local MAXTIMES = 5
local HARDWARE = string.upper(XQSysUtil.getHardware())

function wifi_share_info()
    local uci = require("luci.model.uci").cursor()
    local wifi = require("xiaoqiang.util.XQWifiUtil")
    local info = {
        ["guest"] = 0,
        ["share"] = 0,
        ["sns"] = {}
    }
    local guest = wifi.getGuestWifi(1)
    info["guest"] = tonumber(guest.status)
    info["data"] = {
        ["ssid"] = guest.ssid,
        ["encryption"] = guest.encryption,
        ["password"] = guest.password
    }
    local disabled = uci:get("wifishare", "global", "disabled") or 1
    if disabled then
        info.share = tonumber(disabled) == 0 and 1 or 0
    end
    -- 只有在未设置过时显示为wifi share模式
    local mark = uci:get("wifishare", "global", "mark")
    if not mark then
        if info.guest == 0 then
            info.share = 1
        end
    end
    info.sns = uci:get_list("wifishare", "global", "sns") or {}
    return info
end

function wifi_share_switch(on)
    local uci = require("luci.model.uci").cursor()
    uci:set("wifishare", "global", "disabled", on == 1 and "0" or "1")
    uci:commit("wifishare")
    if on == 1 then
        XQFunction.forkExec("sleep 4; /usr/sbin/wifishare.sh on")
    else
        XQFunction.forkExec("sleep 4; /usr/sbin/wifishare.sh off")
    end
end

function set_wifi_share(info)
    if not info or type(info) ~= "table" then
        return false
    end
    local uci = require("luci.model.uci").cursor()
    local guest = require("xiaoqiang.module.XQGuestWifi")
    if info.guest and info.share then
        local cmd = "/usr/sbin/wifishare.sh on"
        if info.share == 0 then
            cmd = "/usr/sbin/wifishare.sh off"
        end
        local function callback(networkrestart)
            if networkrestart then
                XQFunction.forkExec("sleep 4; /usr/sbin/guestwifi.sh open; "..cmd)
            else
                XQFunction.forkExec("sleep 4; /sbin/wifi >/dev/null 2>/dev/null; "..cmd)
            end
        end
        -- set wifi share
        if info.sns and type(info.sns) == "table" and #info.sns > 0 then
            uci:set_list("wifishare", "global", "sns", info.sns)
        end
        uci:set("wifishare", "global", "mark", "1")
        uci:set("wifishare", "global", "disabled", info.share == 1 and "0" or "1")
        uci:commit("wifishare")
        -- set guest wifi
        local ssid, encryption, key
        if info.data and type(info.data) == "table" then
            ssid = info.data.ssid
            encryption = info.data.encryption
            key = info.data.password
        end
        if info.share == 1 then
            encryption = "none"
        end
        local wps = "XIAOMI_ROUTER_GUEST"
        if info.share == 1 then
            wps = "XIAOMI_ROUTER_GUEST_WX"
        end
        guest.setGuestWifi(1, ssid, encryption, key, 1, info.guest, wps, callback)
    end
    return true
end

-- config device 'D04F7EC0D55D'
--      option disbaled '0'
--      option mac 'D0:4F:7E:C0:D5:5D'
--      option state 'auth'
--      option start_date       2015-06-18
--      option timeout '3600'
--      option sns 'wechat'
--      option guest_user_id '24214185'
--      option extra_payload 'payload test'
function wifi_access(mac, sns, uid, grant, extra)
    local uci = require("luci.model.uci").cursor()
    if XQFunction.isStrNil(mac) then
        return false
    end
    local mac = XQFunction.macFormat(mac)
    local key = mac:gsub(":", "")
    local info = uci:get_all("wifishare", key)
    if info then
        info["mac"] = mac
        if not XQFunction.isStrNil(sns) then
            info["sns"] = sns
        end
        if not XQFunction.isStrNil(uid) then
            info["guest_user_id"] = uid
        end
        if not XQFunction.isStrNil(extra) then
            info["extra_payload"] = extra
        end
        if grant then
            if grant == 0 then
                info["disabled"] = "1"
            elseif grant == 1 then
                info["disabled"] = "0"
            end
        end
    else
        if XQFunction.isStrNil(sns) or XQFunction.isStrNil(uid) or not grant then
            return false
        end
        info = {
            ["mac"] = mac,
            ["state"] = "auth",
            ["sns"] = sns,
            ["guest_user_id"] = uid,
            ["extra_payload"] = extra,
            ["disabled"] = grant == 1 and "0" or "1"
        }
    end
    uci:section("wifishare", "device", key, info)
    uci:commit("wifishare")
    if grant then
        if grant == 0 then
            os.execute("/usr/sbin/wifishare.sh deny "..mac)
        elseif grant == 1 then
            os.execute("/usr/sbin/wifishare.sh allow "..mac)
        end
    end
    return true
end

-- only for testing
function wifi_share_clearall(blacklist)
    local uci = require("luci.model.uci").cursor()
    uci:foreach("wifishare", "device",
        function(s)
            if s["mac"] then
                uci:delete("wifishare", s[".name"])
                os.execute("/usr/sbin/wifishare.sh deny "..s["mac"])
            end
        end
    )
    if blacklist then
        uci:delete("wifishare", "blacklist")
    end
    uci:commit("wifishare")
    if blacklist then
        os.execute("/usr/sbin/wifishare.sh block_apply")
    end
end

function sns_list(sns)
    local uci = require("luci.model.uci").cursor()
    local info = {}
    if XQFunction.isStrNil(sns) then
        return info
    end
    uci:foreach("wifishare", "device",
        function(s)
            if s["sns"] and s["sns"] == sns then
                if not s["disabled"] or tonumber(s["disabled"]) == 0 then
                    table.insert(info, s["guest_user_id"])
                end
            end
        end
    )
    return info
end

function wifi_share_prepare(mac)
    local uci = require("luci.model.uci").cursor()
    local result = true
    local key = mac:gsub(":", "").."_RECORD"
    local record = uci:get_all("wifishare", key)
    local currenttime = tonumber(os.time())
    if record then
        local check = currenttime - tonumber(record.timestamp)
        if check >= INTERVAL or check < 0 then
            record.timestamp = currenttime
            record.count = 0
        else
            local count = tonumber(record.count) + 1
            if count > MAXTIMES then
                if tonumber(record.count) <= MAXTIMES then
                    record.timestamp = currenttime
                end
                result = false
            end
            record.count = count
        end
    else
        record = {
            ["mac"] = mac,
            ["timestamp"] = os.time(),
            ["count"] = 1
        }
    end
    uci:section("wifishare", "record", key, record)
    uci:commit("wifishare")
    if result then
        os.execute("/usr/sbin/wifishare.sh prepare "..mac)
    end
    return result
end

function wifi_share_blacklist()
    local uci = require("luci.model.uci").cursor()
    local block = uci:get_all("wifishare", "blacklist")
    local blacklist = {}
    if block and block["mac"] and type(block["mac"]) == "table" then
        blacklist = block["mac"]
    end
    return blacklist
end

-- t1: table
-- t2: table
-- opt: +/- (t1 + t2)/(t1 - t2)
function merge(t1, t2, opt)
    if not t1 and not t2 then
        return nil
    end
    if opt == "+" then
        if t1 then
            if not t2 then
                return t1
            end
            local d = {}
            for _, v in ipairs(t1) do
                d[v] = true
            end
            for _, v in ipairs(t2) do
                if not d[v] then
                    table.insert(t1, v)
                end
            end
            return t1
        else
            if not t2 then
                return nil
            else
                return t2
            end
        end
    elseif opt == "-" then
        if t1 then
            if not t2 then
                return t1
            end
            local s = {}
            local d = {}
            for _, v in ipairs(t2) do
                d[v] = true
            end
            for _, v in ipairs(t1) do
                if not d[v] then
                    table.insert(s, v)
                end
            end
            return s
        end
    end
    return nil
end

-- macs table<mac>
-- option "+"/"-" (add/delete)
function wifi_share_blacklist_edit(macs, option)
    local uci = require("luci.model.uci").cursor()
    local block = uci:get_all("wifishare", "blacklist")
    local blist
    if block then
        blist = block["mac"]
    end
    local mergelist = merge(blist, macs, option)
    if block then
        if mergelist and #mergelist > 0 then
            block["mac"] = mergelist
            uci:section("wifishare", "block", "blacklist", block)
        else
            uci:delete("wifishare", "blacklist", "mac")
        end
        uci:commit("wifishare")
    else
        if mergelist and #mergelist > 0 then
            uci:section("wifishare", "block", "blacklist", {["mac"] = mergelist})
            uci:commit("wifishare")
        end
    end
    if HARDWARE:match("^R1C") then
        XQFunction.forkExec("sleep 2; /usr/sbin/wifishare.sh block_apply")
    else
        os.execute("/usr/sbin/wifishare.sh block_apply")
    end
end

--
-- 查询授权状态
--
-- @return 0/1/2 处理中/成功/失败
function authorization_status(mac)
    local status = 0
    if not mac then
        return status
    end
    local uci = require("luci.model.uci").cursor()
    local key = mac:gsub(":", "")
    local record = uci:get_all("wifishare", key)
    if record then
        if record.sns and record.sns == "direct_request" then
            if record.disabled and tonumber(record.disabled) == 1 then
                status = 2
            else
                status = 1
            end
        end
    else
        local blacklist = uci:get_list("wifishare", "blacklist", "mac")
        if blacklist and type(blacklist) == "table" then
            for _, lmac in ipairs(blacklist) do
                if mac == lmac then
                    status = 2
                    break
                end
            end
        end
    end
    return status
end
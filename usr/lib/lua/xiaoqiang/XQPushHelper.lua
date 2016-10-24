module ("xiaoqiang.XQPushHelper", package.seeall)

local Json = require("json")

local XQLog = require("xiaoqiang.XQLog")
local XQPreference = require("xiaoqiang.XQPreference")
local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")
local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
local XQPushUtil = require("xiaoqiang.util.XQPushUtil")
local XQCacheUtil = require("xiaoqiang.util.XQCacheUtil")

local EXCEPTION = {
    "^chuangmi%-plug",
    "^antscam",
    "^yeelink%-light",
    "^lumi%-gateway",
    "^zhimi%-airpurifier",
    "^yunmi%-waterpurifier",
    "^midea%-aircondition",
    "^xiaomirepeater"
}

-- @PM lidan
function _exception(hostname)
    if hostname then
        for _, rule in ipairs(EXCEPTION) do
            if hostname:match(rule) then
                return true
            end
        end
    end
    return false
end

function _formatStr(str)
    local str = string.gsub(str,"\"","\\\"")
    str = string.gsub(str, ";", "\\;")
    str = string.gsub(str, "&", "\\&")
    return str:gsub(" ","")
end

function _doPush(payload, title, description, ptype, async)
    if not payload or not title or not description then
        return
    end
    payload = _formatStr(payload)
    local pushtype = "1"
    if ptype then
        pushtype = tostring(ptype)
    end
    local cmd = string.format("matool --method notify --params \"%s\"", payload)
    if async then
        XQFunction.forkExec(cmd)
    else
        os.execute(cmd)
    end
    XQLog.log(6,"matool notify:",payload)
end

function _matool(str, async)
    if XQFunction.isStrNil(str) then
        return
    end
    local cmd = string.format("matool --method reportEvents --params '[%s]'", str)
    XQLog.log(4, cmd)
    if async then
        XQFunction.forkExec(cmd)
    else
        os.execute(cmd)
    end
    XQLog.log(4, "WiFi/LOGIN Authen failed: "..str)
end

function _hookSysUpgraded()
    local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
    local ver = XQSysUtil.getRomVersion()
    local payload = {
        ["type"] = 1,
        ["ver"] = ver
    }
    _doPush(Json.encode(payload), "系统升级", "系统升级")
end

function _hookWifiConnect(mac, dev)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local mackey = mac:gsub(":", "")
    local notify, timestamp = XQPushUtil.specialNotify(mac)
    local settings = XQPushUtil.pushSettings()
    local uci = require("luci.model.uci").cursor()
    local unknown = uci:get("devicelist", "history", mackey) == nil and true or false
    local guest = uci:get("misc", "wireless", "guest_2G") or ""

    if unknown then
        uci:set("devicelist", "history", mackey, 1)
        uci:commit("devicelist")
    end

    -- @PM chenyong [guest wifi share]
    -- Send push when the device is really connected to the network
    if dev == guest then
        local share = uci:get("wifishare", "global", "disabled")
        share = tonumber(share)
        if share == 0 then
            return
        end
    end

    local currenttime = tonumber(os.time())
    local admin = XQPushUtil.getAdminDevice(mackey)
    if admin then
        -- @PM chenyong
        -- interval: a week -> 3 days
        if currenttime - admin >= 259200 then
            XQPushUtil.setAdminDevice(mackey, currenttime)
            XQFunction.forkExec("sleep 4; iwpriv wl1 set AutoChannelSel=4")
        end
    end
    if notify then
        -- interval: 30 min
        if currenttime - timestamp > 1800 then
            notify = true
            XQPushUtil.setSpecialNotify(mac, true, currenttime)
        else
            notify = false
        end
    end

    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local deviceinfo = XQDeviceUtil.getDeviceInfo(mac)

    if (unknown or notify) and XQFunction.isStrNil(deviceinfo.dhcpname) then
        os.execute("sleep 5")
        deviceinfo = XQDeviceUtil.getDeviceInfo(mac)
    end

    if (unknown or notify) and not XQFunction.isStrNil(deviceinfo.dhcpname) then
        local dhcpname = string.lower(deviceinfo.dhcpname)
        if dhcpname:match("^miwifi%-r1c") then
            local payload = {
                ["type"] = 23,
                ["name"] = "小米路由器mini"
            }
            _doPush(Json.encode(payload), "中继成功", "中继成功")
            return
        elseif dhcpname:match("^miwifi%-r1d") or dhcpname:match("^miwifi%-r2d") then
            local payload = {
                ["type"] = 23,
                ["name"] = "小米路由器"
            }
            _doPush(Json.encode(payload), "中继成功", "中继成功")
            return
        elseif dhcpname:match("^xiaomirepeater") then
            local payload = {
                ["type"] = 56,
                ["name"] = "小米中继器",
                ["mac"]  = mac
            }
            _doPush(Json.encode(payload), "中继成功", "中继成功")
            return
        end
    end

    if unknown or notify then
        local name = deviceinfo.name
        local dhcpname = string.lower(deviceinfo.dhcpname)
        if unknown and _exception(dhcpname) then
            return
        end
        if name and string.lower(name):match("android-%S+") and #name > 12 then
            name = name:sub(1, 12)
        end
        if (deviceinfo["type"].c == 2 and deviceinfo["type"].p == 6)
            or (deviceinfo["type"].c == 3 and deviceinfo["type"].p == 2)
            or (deviceinfo["type"].c == 3 and deviceinfo["type"].p == 7) then
            return
        end
        if unknown and settings.auth and settings.level and settings.level >= 2 then
            local payload = {
                ["type"] = 3,
                ["mac"] = mac,
                ["name"] = name
            }
            if dev == guest then
                payload["type"] = 27
            end
            _doPush(Json.encode(payload), "陌生设备上线", "陌生设备上线")
            if deviceinfo.flag == 0 then
                XQDBUtil.saveDeviceInfo(mac,deviceinfo.dhcpname,"","","")
            end
            XQLog.log(6, "New Device Connect.", deviceinfo)
        elseif notify then
            local payload = {
                ["type"] = 28,
                ["mac"] = mac,
                ["name"] = name
            }
            _doPush(Json.encode(payload), "指定设备上线", "指定设备上线")
            XQLog.log(6, "Special Device Connect.", deviceinfo)
        end
    end
end

function _guestWifiConnectPush(mac, sns, snsname)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local deviceinfo = XQDeviceUtil.getDeviceInfo(mac)
    local name = snsname
    local dhcpname = string.lower(deviceinfo.dhcpname)
    if _exception(dhcpname) then
        return
    end
    if (deviceinfo["type"].c == 2 and deviceinfo["type"].p == 6)
        or (deviceinfo["type"].c == 3 and deviceinfo["type"].p == 2)
        or (deviceinfo["type"].c == 3 and deviceinfo["type"].p == 7) then
        return
    end
    local payload = {
        ["type"] = 60,
        ["mac"]  = mac,
        ["name"] = name,
        ["sns"]  = sns
    }
    _doPush(Json.encode(payload), "Guest wifi", "Guest wifi")
end

function _hookWifiDisconnect(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local notify, timestamp = XQPushUtil.specialNotify(mac)
    if notify then
        XQPushUtil.setSpecialNotify(mac, true, tonumber(os.time()))
    end
    XQLog.log(6, "Device Disconnet:"..mac)
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local count = #XQWifiUtil.getWifiConnectDeviceList(1) + #XQWifiUtil.getWifiConnectDeviceList(2)
    if count == 0 then
        local payload = {
            ["type"] = 4
        }
        _doPush(Json.encode(payload), "所有WiFi设备离线", "所有WiFi设备离线")
        XQLog.log(6, "WiFi clear")
    end
end

function _hookAllDownloadFinished()
    XQLog.log(6, "All download finished")
    local payload = {
        ["type"] = 5
    }
    _doPush(Json.encode(payload), "下载完成", "下载完成")
end

function _hookIntelligentScene(name, actions)
    local sname = name
    if XQFunction.isStrNil(sname) then
        sname = ""
    end
    XQLog.log(6, "Intelligent Scene:"..name.." finished!")
    local payload = {
        ["type"] = 6,
        ["name"] = name,
        ["actions"] = actions
    }
    _doPush(Json.encode(payload), "智能场景", "智能场景")
end

function _hookDetectFinished(lan, wan)
    if lan and wan then
        XQLog.log(6, "network detect finished!")
        local payload = {
            ["type"] = 7,
            ["lan"] = lan,
            ["wan"] = wan
        }
        _doPush(Json.encode(payload), "网络检测", "网络检测")
    end
end

function _hookCachecenterEvent(hitcount, timesaver)
    if hitcount and timesaver then
        XQLog.log(6, "cachecenter event!")
        local payload = {
            ["type"] = 13,
            ["hitcount"] = hitcount,
            ["timesaver"] = timesaver
        }
        _doPush(Json.encode(payload), "加速相关", "加速相关")
    end
end

function _hookDownloadEvent(count)
    if tonumber(count) then
        XQLog.log(6, "download event!")
        local payload = {
            ["type"] = 17,
            ["count"] = tonumber(count)
        }
        _doPush(Json.encode(payload), "下载完成", "下载完成")
    end
end

function _hookUploadEvent(count)
    if tonumber(count) then
        XQLog.log(6, "upload event!")
        local payload = {
            ["type"] = 18,
            ["count"] = tonumber(count)
        }
        _doPush(Json.encode(payload), "上传完成", "上传完成")
    end
end

function _hookADFilterEvent(page, all)
    if tonumber(page) and tonumber(all) then
        XQLog.log(6, "upload event!")
        local payload = {
            ["type"] = 19,
            ["page"] = tonumber(page),
            ["all"] = tonumber(all)
        }
        _doPush(Json.encode(payload), "广告过滤", "广告过滤")
    end
end

function _hookDefault(data)
    XQLog.log(6, "Unknown Feed")
    local payload = {
        ["type"] = 999,
        ["data"] = data
    }
    _doPush(Json.encode(payload), "新消息", "未定义")
end

function _hookNewRomVersionDetected(version)
    XQLog.log(6, "New ROM version detected")
    local routerName = XQPreference.get(XQConfigs.PREF_ROUTER_NAME, "")
    local _romChannel = XQSysUtil.getChannel()
    local payload = {
        ["type"] = 14,
        ["name"] = routerName,
        ["version"] = version,
        ["channel"] = _romChannel
    }
    _doPush(Json.encode(payload), "发现新版本", "发现新版本")
end

function _hookWifiImproveNotify()
    local payload = {
        ["type"] = 29
    }
    _doPush(Json.encode(payload), "信道可以优化", "信道可以优化")
end

function _hookWifiAuthenFailed(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local XQAntiRubNetwork = require("xiaoqiang.module.XQAntiRubNetwork")
    local currenttime = tonumber(os.time())
    local settings = XQPushUtil.pushSettings()
    local count = XQAntiRubNetwork.wifiAuthenFailedAction(mac)
    if count and settings.auth then
        if settings.level and settings.level == 2 then
            local payload = {
                ["type"]    = 51,
                ["mac"]     = mac,
                ["count"]   = count
            }
            local event = {
                ["eventID"] = 1001,
                ["payload"] = {
                    ["mac"]     = mac,
                    ["count"]   = count
                }
            }
            _matool(Json.encode(event))
            local key = "MWIFI_"..mac:gsub(":", "")
            local timestamp = XQPushUtil.getTimestamp(key)
            if currenttime - timestamp > 7200 then
                _doPush(Json.encode(payload), "WiFi密码错误", "有风险")
                XQPushUtil.setTimestamp(key, currenttime)
            end
        elseif settings.level and settings.level == 3 then
            local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
            XQWifiUtil.editWiFiMacfilterList(0, {mac}, 0)
            local payload = {
                ["type"]    = 52,
                ["mac"]     = mac,
                ["count"]   = count
            }
            local event = {
                ["eventID"] = 1002,
                ["payload"] = {
                    ["mac"]     = mac,
                    ["count"]   = count
                }
            }
            _matool(Json.encode(event))
            local key = "HWIFI_"..mac:gsub(":", "")
            local timestamp = XQPushUtil.getTimestamp(key)
            if currenttime - timestamp > 7200 then
                _doPush(Json.encode(payload), "WiFi密码错误", "强制拉黑")
                XQPushUtil.setTimestamp(key, currenttime)
            end
        end
    end
end

function _hookLoginAuthenFailed(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local XQAntiRubNetwork = require("xiaoqiang.module.XQAntiRubNetwork")
    local currenttime = tonumber(os.time())
    local settings = XQPushUtil.pushSettings()
    local count = XQAntiRubNetwork.LoginAuthenFailedAction(mac)
    -- ban admin (default 30min)
    if count then
        local datatypes = require("luci.cbi.datatypes")
        if mac and datatypes.macaddr(mac) then
            os.execute("/usr/sbin/ban_admin ban "..mac)
        end
    end
    if count and settings.auth then
        local wifidict = XQWifiUtil.getAllWifiConnetDeviceDict()
        if not wifidict[mac] then
            return
        end
        if settings.level and settings.level == 2 then
            local payload = {
                ["type"]    = 53,
                ["mac"]     = mac,
                ["count"]   = count
            }
            local event = {
                ["eventID"] = 1003,
                ["payload"] = {
                    ["mac"]     = mac,
                    ["count"]   = count
                }
            }
            _matool(Json.encode(event))
            local key = "MLOGIN_"..mac:gsub(":", "")
            local timestamp = XQPushUtil.getTimestamp(key)
            if currenttime - timestamp > 7200 then
                _doPush(Json.encode(payload), "管理员密码错误", "有风险")
                XQPushUtil.setTimestamp(key, currenttime)
            end
        elseif settings.level and settings.level == 3 then
            XQWifiUtil.editWiFiMacfilterList(0, {mac}, 0)
            local payload = {
                ["type"]    = 54,
                ["mac"]     = mac,
                ["count"]   = count
            }
            local event = {
                ["eventID"] = 1004,
                ["payload"] = {
                    ["mac"]     = mac,
                    ["count"]   = count
                }
            }
            _matool(Json.encode(event), true)
            local key = "HLOGIN_"..mac:gsub(":", "")
            local timestamp = XQPushUtil.getTimestamp(key)
            if currenttime - timestamp > 7200 then
                _doPush(Json.encode(payload), "管理员密码错误", "强制拉黑")
                XQPushUtil.setTimestamp(key, currenttime)
            end
        end
    end
end

function _hookWifiBlacklisted(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    -- local mackey = mac:gsub(":", "")
    -- local settings = XQPushUtil.pushSettings()
    -- local times = XQPushUtil.getAuthenFailedTimes(mac)
    -- if settings.auth then
    --     local cachekey = mackey.."_black"
    --     local cache = XQCacheUtil.getCache(cachekey)
    --     if cache then
    --         return
    --     else
    --         times = times + 1
    --         XQCacheUtil.saveCache(mackey, mackey, 2)
    --         XQPushUtil.setAuthenFailedTimes(mac, times)
    --     end
    -- end
    -- blacklisted event
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local XQAntiRubNetwork = require("xiaoqiang.module.XQAntiRubNetwork")
    local settings = XQPushUtil.pushSettings()
    local count = XQAntiRubNetwork.wifiBlacklistedAction(mac)
    local cwmode = XQWifiUtil.getWiFiMacfilterModel()
    if count and settings.auth then
        local event = {
            ["eventID"] = 1005,
            ["payload"] = {
                ["mac"]     = mac,
                ["count"]   = count
            }
        }
        if cwmode and cwmode == 2 then
            event.eventID = 1001
        end
        _matool(Json.encode(event))
    end
end

function _hook5GWifiCrashed()
    local MessageBox = require("xiaoqiang.module.XQMessageBox")
    MessageBox.addMessage({["type"] = 3, ["data"]={}})
    _doPush("{\"type\":55}", "5G WiFi嗝屁了", "5G WiFi嗝屁了")
end

function push_request_lua(payload)
    local ptype = tonumber(payload.type)
    if ptype == 1 then
        _hookWifiConnect(payload.data.mac, payload.data.dev)
    elseif ptype == 2 then
        --_hookWifiDisconnect(payload.data.mac)
    elseif ptype == 3 then
        _hookSysUpgraded()
    elseif ptype == 4 then
        _hookAllDownloadFinished()
    elseif ptype == 5 then
        _hookIntelligentScene(payload.data.name,payload.data.list)
    elseif ptype == 6 then
        _hookDetectFinished(payload.data.lan, payload.data.wan)
    elseif ptype == 7 then
        _hookCachecenterEvent(payload.data.hit_count, payload.data.timesaver)
    elseif ptype == 8 then
        _hookNewRomVersionDetected(payload.data.version)
    elseif ptype == 9 then
        _hookDownloadEvent(payload.data.count)
    elseif ptype == 10 then
        _hookUploadEvent(payload.data.count)
    elseif ptype == 11 then
        _hookADFilterEvent(payload.data.filter_page, payload.data.filter_all)
    elseif ptype == 13 then
        _hookWifiImproveNotify()
    elseif ptype == 14 then
        _hookWifiAuthenFailed(payload.data.mac)
    elseif ptype == 15 then
        _hookWifiBlacklisted(payload.data.mac)
    elseif ptype == 16 then
        _hookLoginAuthenFailed(payload.data.mac)
    elseif ptype == 50 then
        _hook5GWifiCrashed()
    else
        _hookDefault(payload.data)
    end
    return true
end

--
-- type:{1,2,3...}
-- data:{...}
--
function push_request(payload)
    if XQFunction.isStrNil(payload) then
        return false
    end
    -- XQLog.log(6,"Push request:",payload)
    local payload = Json.decode(payload)
    return push_request_lua(payload)
end
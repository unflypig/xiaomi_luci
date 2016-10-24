module ("xiaoqiang.module.XQVASModule", package.seeall)

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

local bit = require("bit")
local uci = require("luci.model.uci").cursor()
local lutil = require("luci.util")
local json = require("json")

local DEFAULTS = {
    ["auto_upgrade"] = {
        ["title"] = "系统自动升级",
        ["desc"] = "在闲暇时自动为您升级路由器系统"
    },
    ["security_page"] = {
        ["title"] = "恶意网址提醒",
        ["desc"] = "防欺诈防盗号防木马，为安全上网保驾护航"
    },
    ["shopping_bar"] = {
        ["title"] = "比价助手",
        ["desc"] = "为您找到最便宜的同类产品，直达所需"
    },
    ["baidu_video_bar"] = {
        ["title"] = "看片助手",
        ["desc"] = "帮你搜罗最热相关视频，支持跨平台收藏"
    }
}

function _rule_merge(t1, t2)
    local t = {}
    for k, v in pairs(t1) do
        if t2[k] then
            t[k] = bit.band(v, t2[k])
        else
            t[k] = v
        end
    end
    return t
end

function _country_code_rule()
    local cc = require("xiaoqiang.XQCountryCode")
    local ccrules = uci:get_all("vas", "countrycode")
    local currentcc = cc.getBDataCountryCode()
    local info = {}
    if ccrules then
        for k, v in pairs(ccrules) do
            if not k:match("^%.") then
                if not info[k] and v:match(currentcc) then
                    info[k] = 1
                else
                    info[k] = 0
                end
            end
        end
    end
    return info
end

FUNCTIONS = {
    ["countrycode"] = _country_code_rule
}

function vas_info(conf)
    local info = {}
    if conf ~= "vas" and conf ~= "vas_user" then
        return info
    end
    local services = uci:get_all(conf, "services")
    if services then
        for k, v in pairs(services) do
            if not k:match("^%.") then
                v = tonumber(v)
                if v and v == -1 then
                    local cmd = uci:get("vas", k, "status")
                    if XQFunction.isStrNil(cmd) then
                        v = 1
                    else
                        local va = lutil.exec(cmd)
                        if va then
                            va = lutil.trim(va)
                            v = tonumber(va) or 1
                        else
                            v = 0
                        end
                    end
                end
                if v and v ~= -2 and v ~= -3 then
                    info[k] = v
                end
            end
        end
    end
    return info
end

function get_new_vas()
    local info = {}
    local vas = vas_info("vas")
    local vas_user = vas_info("vas_user")
    if not vas then
        return info
    end
    local show
    uci:foreach("vas", "rule",
        function(s)
            local f = FUNCTIONS[s[".name"]]
            if f and type(f) == "function" then
                if show then
                    show = _rule_merge(show, f())
                else
                    show = f()
                end
            end
        end
    )
    for k, v in pairs(vas) do
        if v and not vas_user[k] and (not show or (show and show[k] == 1)) then
            info[k] = v
        end
    end
    return info
end

function get_vas()
    local info = {}
    local vas = vas_info("vas")
    local vas_user = vas_info("vas_user")
    if not vas then
        return info
    end
    local show
    uci:foreach("vas", "rule",
        function(s)
            local f = FUNCTIONS[s[".name"]]
            if f and type(f) == "function" then
                if show then
                    show = _rule_merge(show, f())
                else
                    show = f()
                end
            end
        end
    )
    for k, v in pairs(vas) do
        if not show or (show and show[k] == 1) then
            if v and not vas_user[k] then
                info[k] = v
            else
                info[k] = vas_user[k]
            end
        end
    end
    if not info["invalid_page"] then
        local enabled = uci:get("http_status_stat", "settings", "enabled") or 0
        info["invalid_page"] = tonumber(enabled)
    end
    return info
end

function get_vas_kv_info()
    local info = {
        ["invalid_page_status"]     = "off",
        ["security_page_status"]    = "off",
        ["gouwudang_status"]        = "off",
        ["baidu_video_bar"]         = "off"
    }
    local vas = vas_info("vas")
    local vasinfo = vas_info("vas_user")
    for key, value in pairs(vas) do
        if key == "invalid_page" then
            if tonumber(vasinfo.invalid_page) == 1 then
                info.invalid_page_status = "on"
            end
        elseif key == "security_page" then
            if tonumber(vasinfo.security_page) == 1 then
                info.security_page_status = "on"
            end
        elseif key == "shopping_bar" then
            if tonumber(vasinfo.shopping_bar) == 1 then
                info.gouwudang_status = "on"
            end
        elseif key == "baidu_video_bar" then
            if tonumber(vasinfo.baidu_video_bar) == 1 then
                info.baidu_video_bar = "on"
            end
        else
            if tonumber(vasinfo[key]) == 1 then
                info[key] = "on"
            else
                info[key] = "off"
            end
        end
    end
    return info
end

function set_vas(info)
    if not info or type(info) ~= "table" then
        return false
    end
    local cmds = {}
    local vas = vas_info("vas")
    local vas_user = vas_info("vas_user")
    for k, v in pairs(info) do
        vas_user[k] = v
        local cmd
        if v == 1 then
            cmd = uci:get("vas", k, "on")
        else
            cmd = uci:get("vas", k, "off")
        end
        if cmd then
            table.insert(cmds, cmd)
        end
    end
    uci:section("vas_user", "settings", "services", vas_user)
    uci:commit("vas_user")
    for _, cmd in ipairs(cmds) do
        XQFunction.forkExec(cmd)
    end
end

--
-- for messagingagent
--
function updateVasConf(info)
    if not info or type(info) ~= "table" then
        return false
    end
    for key, value in pairs(info) do
        if value and type(value) == "table" then
            if value.status then
                uci:set("vas", "services", key, value.status)
                if tonumber(value.status) == -3 then
                    if value.service and value.service.off then
                        XQFunction.forkExec(value.service.off)
                    end
                end
            end
            if value.rules and type(value.rules) == "table" then
                for rkey, rvalue in pairs(value.rules) do
                    if not uci:get_all("vas", rkey) then
                        uci:section("vas", "rule", rkey, {[key] = rvalue})
                    else
                        uci:set("vas", rkey, key, rvalue)
                    end
                end
            end
            if value.service and type(value.service) == "table" then
                uci:section("vas", "service", key, value.service)
            end
        end
    end
    uci:commit("vas")
    return true
end

--- merge vas & vas_user
function get_vas_info()
    local vas = vas_info("vas")
    local vas_user = vas_info("vas_user")
    for k, v in pairs(vas_user) do
        vas[k] = v
    end
    return vas
end

-- for web
function do_query(lan)
    if not lan then
        return nil
    end
    local httpclient = require("xiaoqiang.util.XQHttpUtil")
    local URL = "http://api.miwifi.com/data/new_feature_switch/"..lan
    local response = httpclient.httpGetRequest(URL)
    if tonumber(response.code) == 200 and response.res then
        local suc, info = pcall(json.decode, response.res)
        if suc and info then
            return info
        end
    end
    return nil
end

function get_server_vas_details()
    local FILE = "/tmp/vas_details"
    local fs = require("nixio.fs")
    local cc = require("xiaoqiang.XQCountryCode")
    local lan = cc.getCurrentJLan()
    local timestamp = os.time()
    if fs.access(FILE) then
        local content = fs.readfile(FILE)
        local suc, info = pcall(json.decode, content)
        if suc and info and info.res then
            if info.lan == lan and info.timestamp and (tonumber(timestamp) - tonumber(info.timestamp) < 300) then
                return info.res
            end
        end
    end
    local qres = do_query(lan)
    if qres then
        local result = {
            ["res"] = qres,
            ["lan"] = lan,
            ["timestamp"] = timestamp
        }
        fs.writefile(FILE, json.encode(result))
        return qres
    end
    return nil
end

function get_vas_details(keys)
    local fs = require("nixio.fs")
    local details = {}
    if keys and type(keys) == "table" then
        local sdetails = get_server_vas_details()
        for _, key in ipairs(keys) do
            local item = {}
            if fs.access("/www/vas/"..key..".png") then
                item["icon"] = key..".png"
            else
                item["icon"] = "vas_default.png"
            end
            if sdetails and sdetails[key] then
                item["title"] = sdetails[key]["title"]
                item["desc"] = sdetails[key]["desc"]
            else
                if DEFAULTS[key] then
                    item["title"] = DEFAULTS[key]["title"]
                    item["desc"] = DEFAULTS[key]["desc"]
                end
            end
            if item.title and item.desc then
                details[key] = item
            end
        end
    end
    return details
end
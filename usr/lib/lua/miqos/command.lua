#!/usr/bin/lua
-- 命令解析和处理相关

require 'miqos.common'
local json= require 'json'

local fcmd={}


local function uci_commit_save()
    g_cursor:commit('miqos')
    -- tmp下的配置改变,复写回/etc下
    if not tmp2cfg() then
        logger(1, 'copy tmp cfg to /etc/config/ failed.')
    end
end

local function update_qos_enabled(qos_on_flag)
    if qos_on_flag then
        g_cursor:set('miqos','settings','enabled','1')
    else
        g_cursor:set('miqos','settings','enabled','0')
    end

    g_cursor:commit('miqos')
end

-- 开启band-limit-QoS
function fcmd.on()
    update_qos_enabled(true)
    cfg.enabled.started=true

    -- 读取网络配置
    if not read_network_conf() then
        logger(3, 'failed to read network config when `qos on`!')
    end

    return {status=0,data='ok'},true
end

-- 关闭band-limit-QoS,开启优先级-QoS
function fcmd.off()
    update_qos_enabled(false)
    cfg.enabled.started=true

    -- 读取网络配置
    if not read_network_conf() then
        logger(3, 'failed to read network config when `qos off`!')
    end

    return {status=0,data='ok'},true
end

-- 关闭所有QoS规则，但保持服务在线(调用qdisc-clean)
function fcmd.shutdown()
    cleanup_system()
    cfg.enabled.started=false
    return {status=0,data='ok'},true
end

-- 优先级调整
function fcmd.nprio(act,ip,type)
    if not act or not ip or not type then
        logger(3,'ERROR: parameter lost for cmd `nprio`')
        return {status=1,data='unkown error.'},false
    end

    if g_debug then
        logger(3,'nprio ' .. act ..','.. ip .. ',' .. type)
    end

    if act == 'add' then
        if not special_host_list.host[ip] or type ~=  special_host_list.host[ip] then
            special_host_list.host[ip]=type
            special_host_list.changed=true
            return {status=0,data='ok'},false
        else
            return {status=0,data='already in list.'},false
        end

    elseif act == 'del' then
        if special_host_list.host[ip] then
            special_host_list.host[ip]=nil
            special_host_list.changed=true
            return {status=0,data='ok'},false
        else
            return {status=0,data='not exist in list.'},false
        end
    else
        return {status=1,data='not supported action for cmd `nprio`.'},false
    end
end


-- 更新预留带宽特殊设备列表
function fcmd.reserve(act,ip,type)
    if not act or not ip or not type then
        logger(3,'ERROR: parameter lost for cmd `reserve`')
        return {status=1,data='unkown error.'},false
    end
    if g_debug then
        logger(3, 'update_reserved_hosts, act:' .. act ..', ip:'..ip ..', type:' .. type)
    end


    if act == 'add' then
        if not band_reserve_hosts[type] then
            band_reserve_hosts[type]={}
        end
        if band_reserve_hosts[type] and band_reserve_hosts[type][ip] then
            return {status=0,data='already reserved.'}, false
        end
        band_reserve_hosts[type][ip]=type
    elseif act == 'del' then
        if band_reserve_hosts[type] and band_reserve_hosts[type][ip] then
            band_reserve_hosts[type][ip]=nil
        else
            return {status=0,data='already delted.'}, false
        end
    else
        logger(3,'do not support act: ' .. act)
        return {status=1,data='not supported.'},false
    end

    band_reserve_hosts.changed=true

    return {status=0,data='ok'},false

end


local function update_bw(max_up,max_down)

    if tonumber(max_up) >= 0 and tonumber(max_down) >= 0 then
        g_cursor:set('miqos','settings','upload',max_up)
        g_cursor:set('miqos','settings','download',max_down)

        uci_commit_save()
        return true
    end
    return false
end

-- 修改band参数
function fcmd.change_band(up,down)
    if up and down and update_bw(up,down) then
        return {status=0,data='ok'},true
    end
    return {status=1,data='update bandwidth failed.'},false
end

local function get_bw()
    local up = g_cursor:get('miqos','settings','upload') or '0'
    local down=g_cursor:get('miqos','settings','download') or '0'
    return up,down
end

-- 输出band参数
function fcmd.show_band()
    local data={}
    data['uplink'],data['downlink']=get_bw()
    return {status=0,data=data},false
end

local function update_guest(in_up,in_down)

    g_cursor:set('miqos','guest','up_per',in_up)
    g_cursor:set('miqos','guest','down_per',in_down)

    uci_commit_save()
    return true
end

-- 设置guest的限制参数
function fcmd.on_guest(up,down)
    if up and down and update_guest(up,down) then
        return {status=0,data='ok'},true
    end
    return {status=1,data='update guest limit failed.'},false
end

-- 输出guest参数
function fcmd.show_guest()
    return {status=0,data=cfg.guest},false
end

-- 显示每个host的限速数据
function fcmd.show_limit()
    return {
        status=0,
        data=g_limit,   -- 全局g_limit保存返回的数据
        mode=cfg.qos_type.mode,
        arrange_bandwidth={
            upload=cfg.bands[UP],
            download=cfg.bands[DOWN],
        },
    },false
end

-- 简化配置中MAC设置
local function compact_output_group_def()
    local ret={}
    local t={'max_grp_uplink','min_grp_uplink','max_grp_downlink','min_grp_downlink'}
    for k, v in pairs(g_group_def) do
        if k ~= cfg.group.default then
            ret[k]={}
            for _,n in pairs(t) do
                ret[k][n]=v[n]
            end
        end
    end
    return ret
end

-- 限速每个host的限速配置
function fcmd.show_cfg()
    return {status=0,data=compact_output_group_def(),mode=cfg.qos_type.mode}
end

local function add_or_change_group(mac, maxup, maxdown,minup,mindown)

    local str_mac=string.upper(mac)
    local mac_name=string.gsub(str_mac,':','')
    local all=g_cursor:get_all('miqos')
    local name = ''
    for k,v in pairs(all) do
        if v['.type'] == 'group' and v['name'] == str_mac then
            name = k
            break
        end
    end

    if name == '' then
        name = g_cursor:section('miqos','group',mac_name)
        g_cursor:set('miqos',name,'name',str_mac)
        g_cursor:set('miqos',name,'min_grp_uplink','0.5')
        g_cursor:set('miqos',name,'min_grp_downlink','0.5')
        g_cursor:set('miqos',name,'max_grp_uplink','0')
        g_cursor:set('miqos',name,'max_grp_downlink','0')
        g_cursor:set('miqos',name,'mode','general')
        g_cursor:set('miqos',name,'mac',{str_mac})
    end

    local tmp_num
    if minup then
        tmp_num = tonumber(minup)
        if tmp_num <= 0 or tmp_num > 1 then
            minup = g_default_min_updown_factor
            if g_debug then
                logger(3,'setting min reserve out of range, set it to default value.')
            end
        end
        g_cursor:set('miqos',name,'min_grp_uplink',minup)
    end
    if mindown then
        tmp_num = tonumber(mindown)
        if tmp_num <= 0 or tmp_num > 1 then
            mindown = g_default_min_updown_factor
            if g_debug then
                logger(3,'setting min reserve out of range, set it to default value.')
            end
        end
        g_cursor:set('miqos',name,'min_grp_downlink',mindown)
    end
    if maxup then
        tmp_num = tonumber(maxup)
        if tmp_num < 8 then
            maxup = 0
            if g_debug then
                logger(3,'NOTE: setting min reserve out of range, set it to default value.')
            end
        end
        g_cursor:set('miqos',name,'max_grp_uplink',maxup)
    end
    if maxdown then
        tmp_num = tonumber(maxdown)
        if tmp_num < 8 then
            maxdown = 0
            if g_debug then
                logger(3,'NOTE: setting min reserve out of range, set it to default value.')
            end
        end
        g_cursor:set('miqos',name,'max_grp_downlink',maxdown)
    end

    uci_commit_save()
end

-- 开启某个host的限速
function fcmd.on_limit(mode,mac,u1,d1,u2,d2)
    if mode == 'max' then
        add_or_change_group(mac,u1,d1,nil,nil)
    elseif mode == 'min' then
        add_or_change_group(mac,nil,nil,u1,d1)
    elseif mode == 'both' then
        add_or_change_group(mac,u1,d1,u2,d2)
    else
        logger(3,'not supported on_limit mode.')
        return {status=1,data='not supported on_limit mode.'},false
    end

    cfg.group.changed=true  -- 告知有限速设置变化需要重新刷host规则

    return {status=0,data='ok'},true
end

function fcmd.set_limit(mode,mac,u1,d1,u2,d2)
    if mode == 'max' then
        add_or_change_group(mac,u1,d1,nil,nil)
    elseif mode == 'min' then
        add_or_change_group(mac,nil,nil,u1,d1)
    elseif mode == 'both' then
        add_or_change_group(mac,u1,d1,u2,d2)
    else
        logger(3,'not supported on_limit mode.')
        return {status=1,data='not supported on_limit mode.'},false
    end

    cfg.group.changed=true  -- 告知有限速设置变化需要重新刷host规则

    return {status=0,data='ok'},false
end

function fcmd.apply()
    return {status=0,data='ok'},true
end

local function del_group(mac)
    local all=g_cursor:get_all('miqos')

    if mac then
        local str_mac = string.upper(mac)
        for k,v in pairs(all) do
            if v['.type'] == 'group' and v['name'] == str_mac then
                g_cursor:delete('miqos',k)
                break
            end
        end
    else
        for k,v in pairs(all) do
            if v['.type'] == 'group' and v['name'] ~= '00' then
                g_cursor:delete('miqos',k)
            end
        end
    end

    uci_commit_save()
end

-- 关闭host的限速
function fcmd.off_limit(mac)
    del_group(mac)
    cfg.group.changed=true  -- 告知有限速设置变化需要重新刷host规则
    return {status=0,data='ok'},true
end

local function update_qos_auto_mode(mode)

    g_cursor:set('miqos','settings','qos_auto',mode)
    uci_commit_save()
end

-- 设置QoS运行模式,auto,min,max,both
function fcmd.set_type(type)
    if type == 'auto' then
        logger(3, "----->>set to auto-limit-mode.")
    elseif type == 'min' then
        logger(3, "----->>set to min-limit-mode.")
    elseif type == 'max' then
        logger(3, "----->>set to max-limit-mode.")
    elseif type == 'both' then
        logger(3, "----->>set to both-limit-mode.")
    else
        logger(3, "----->>set to service-limit-mode.")
        type = 'service'
    end

    update_qos_auto_mode(type)

    return {status=0,data='ok'},true
end

function fcmd.set_seq(seq)
    g_cursor:set('miqos','param','flow',seq)
    uci_commit_save()

    return {status=0,data='ok'},true
end

function fcmd.get_seq()
    local str=cfg.flow.seq
    if str == '' then
        str = cfg.flow.dft
    end
    return {status=0,data={seq=str}},false
end

-- 命令处理的包装函数
function process_cmd(cmd, ...)
    if not cmd or not fcmd[cmd] then
        if cmd then
            logger(3, 'cmd `' .. cmd .. '` is not defined.')
        else
            logger(3, 'cmd is NULL. r u sure?')
        end
        return {status=1,data='cmd is not defined.'}
    else
        logger(3,p_sysinfo() .. '===CMD: `qos ' .. cmd .. '` ')
        -- 返回错误码和对应的数据,json的展开形式
        return fcmd[cmd](unpack(arg))
    end
end






#!/usr/bin/lua
-- fixed global cfg and variables

local fs = require "nixio.fs"

local cfg_dir='/etc/config/'
local tmp_cfg_dir='/tmp/etc/config/'
local cfg_file=cfg_dir .. 'miqos'
local tmp_cfg_file=tmp_cfg_dir .. 'miqos'

function uci_init()
    if not g_cursor then
        g_cursor = uci.cursor()
    end
    return g_cursor:set_confdir(tmp_cfg_dir)
end

-- 读取cfg到tmp的meory文件夹中
function cfg2tmp()
    local r1,r2,r3 = fs.mkdirr(tmp_cfg_dir)
    if not r1 then
        logger(3, 'fatal error: mkdir failed, code:' .. r2 .. ',msg:'..r3)
        return nil
    end

    r1,r2,r3 = fs.copy(cfg_file,tmp_cfg_file)
    if not r1 then
        logger(3,'fatal error: copy cfg file 2 /tmp memory failed. code:' .. r2 .. ',msg:'..r3)
        return nil
    end
    return true
end

-- 十进制转十六进制
function dec2hexstr(d)
    return string.format("%x",d)
end

-- 拷贝最新配置到memory中
function tmp2cfg()
    if not fs.copy(tmp_cfg_file,cfg_file) then
        logger(3,'fatal error: copy /tmp cfg file 2 /etc/config/ failed. exit.')
        return nil
    end
    return true
end

-- 深拷贝table
function copytab(st)
    local tab={}
    for k,v in pairs(st or {}) do
        if type(v) ~= 'table' then tab[k]=v
        else tab[k]=copytab(v) end
    end
    return tab
end

-- 从标准config中读取配置,(可能没用了)
function get_conf_std(conf,type,opt,default)
    local x=uci.cursor()
    local _,e = pcall(function() return x:get(conf,type,opt) end)
    return e or default
end

-- 从缓存config中读取配置
function get_tbls(conf,type)
    local tbls={}
    local _,e = pcall(function() g_cursor:foreach(conf, type, function(s) tbls[s['name']]=s end) end)
    return tbls or {}
end

-- 读取更新group配置
function read_qos_group_config()
    g_group_def=get_tbls('miqos','group')
    -- QOS_TYPE: auto 最小保证和最大带宽设置均无效， min 最小保证设置有效， max 最大带宽设置有效, both 最大最小均可调整
    -- 自动模式设置组为group 00
    g_group_def[cfg.group.default]['min_grp_uplink']=cfg.group.min_default
    g_group_def[cfg.group.default]['min_grp_downlink']=cfg.group.min_default
    if cfg.qos_type.mode == 'auto' then
        for k,v in pairs(g_group_def) do
            if v['name'] ~= cfg.group.default then
                g_group_def[k] = nil
            else
                g_group_def[k]['min_grp_uplink']=cfg.group.min_default
                g_group_def[k]['min_grp_downlink']=cfg.group.min_default
            end
        end
    elseif cfg.qos_type.mode == 'min' then
        for k,v in pairs(g_group_def) do
            if v['name'] ~= cfg.group.default then
                g_group_def[k]['max_grp_uplink'] = 0
                g_group_def[k]['max_grp_downlink'] = 0
            end
            if g_group_def[k]['min_grp_uplink'] == 0 then
                g_group_def[k]['min_grp_uplink'] = cfg.group.min_default
            end
            if g_group_def[k]['min_grp_downlink'] == 0 then
                g_group_def[k]['min_grp_downlink'] = cfg.group.min_default
            end
        end
    elseif cfg.qos_type.mode == 'max' then
        for k,v in pairs(g_group_def) do
            if v['name'] ~= cfg.group.default then
                g_group_def[k]['min_grp_uplink'] = 0
                g_group_def[k]['min_grp_downlink'] = 0
            end
            if g_group_def[k]['min_grp_uplink'] == 0 then
                g_group_def[k]['min_grp_uplink'] = cfg.group.min_default
            end
            if g_group_def[k]['min_grp_downlink'] == 0 then
                g_group_def[k]['min_grp_downlink'] = cfg.group.min_default
            end
        end
    elseif cfg.qos_type.mode == 'both' then
        -- keep config for both changes.
    elseif cfg.qos_type.mode == 'service' then
        -- keep config for service mode
    else
        logger(3,'ERROR: not supported qos type MODE.')
        return false
    end
    return true
end

-- 读取更新guest配置
function read_qos_guest_config()
    local guest_tbl=get_tbls('miqos','limit')
    -- guest 参数变化
    tmp_str1,tmp_str2=guest_tbl['guest']['up_per'] or '0',guest_tbl['guest']['down_per'] or '0'
    -- 读取参数时，做默认值归一化
    if tmp_str1 == '0' then tmp_str1 = cfg.guest.default end
    if tmp_str2 == '0' then tmp_str2 = cfg.guest.default end
    if cfg.guest.inner.UP ~= tmp_str1 or cfg.guest.inner.DOWN ~= tmp_str2 then
        cfg.guest.inner.UP,cfg.guest.inner.DOWN=tmp_str1,tmp_str2

        cfg.guest.changed=1
    else
        cfg.guest.changed=0
    end

    for _,dir in pairs({'UP','DOWN'}) do
        local inner=tonumber(cfg.guest.inner[dir])
        if inner < 0 then
            cfg.guest[dir] = tonumber(cfg.bands[dir])
        elseif inner < 1 then
            cfg.guest[dir] = math.ceil(cfg.bands[dir] * inner )
        else
            cfg.guest[dir] = math.ceil(inner)
        end
    end

    return true
end

-- 无输出执行命令
function exec_cmd(tblist, ignore_error)
    local outlog ='/tmp/miqos.log'
    for _,v in pairs(tblist) do
        local cmd = v

        if g_debug then
            logger(3, '++' .. cmd)
            cmd = cmd .. ' >/dev/null 2>>' .. outlog
        else
            cmd = cmd .. " &>/dev/null "
        end

        if os.execute(cmd) ~= 0 and ignore_error ~= 1 then
            if g_debug then
                os.execute('echo "^^^ '.. cmd .. ' ^^^ " >>' .. outlog)
            end
            logger(3, '[ERROR]:  ' .. cmd .. ' failed!')
            dump_qdisc(cfg.DEVS)

            -- 出错，则退出系统
            system_exit()
            return false
        end
    end

    return true
end

-- 集合数据结构
function newset()
    local reverse = {}
    local set = {}
    return setmetatable(set, {__index = {
        insert = function(set, value)
            if not reverse[value] then
                table.insert(set, value)
                reverse[value] = table.getn(set)
            end
        end,
        remove = function(set, value)
            local index = reverse[value]
            if index then
                reverse[value] = nil
                local top = table.remove(set)
                if top ~= value then
                    reverse[top] = index
                    set[index] = top
                end
            end
        end
    }})
end

--split string with chars '$p'
string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end

local function print_r(root,ind)
    local indent="    " .. ind

    for k,v in pairs(root or {}) do
            if(type(v) == "table") then
                    logger(3,indent .. k .. " = {")
                    print_r(v,indent)
                    logger(3, indent .. "}")
            elseif(type(v) == "boolean") then
                local tmp = 'false'
                if v then tmp = 'true' end
                logger(3, indent .. k .. '=' .. tmp)
            else
                logger(3, indent .. k .. "=" .. v)
            end
    end
end

function pr(root)
    print_r(root,'')
end

function p_sysinfo()
    local tmp='INFO,' .. 'Qdisc:' .. (cfg.qdisc.cur or '') .. ',Mode:' .. cfg.qos_type.mode .. ',Band: U:'.. cfg.bands.UP .. 'kbps,D:' .. cfg.bands.DOWN .. 'kbps'
    return tmp;
end

local cmd_dump_qdisc='tc -d qdisc show | sort '
local cmd_show_class='tc -d class show dev '
local cmd_show_filter='tc -d filter show dev '
-- 出错后dump规则用于除错
function dump_qdisc(devs)
    local tblist={}
    table.insert(tblist,cmd_dump_qdisc)

    for _,dev in pairs(devs) do
        table.insert(tblist,  cmd_show_class .. dev.dev .. ' | sort ')
    end
    for _,dev in pairs(devs) do
        table.insert(tblist,  cmd_show_filter .. dev.dev)
    end
    logger(3, '--------------miqos error dump START--------------------')
    local pp,data
    for _,cmd in pairs(tblist) do
        pp=io.popen(cmd)
        if pp then
            for d in pp:lines() do
                logger(3, d)
            end
        end
    end
    pp:close()
    logger(3, '--------------miqos error dump END--------------------')
end

--根据带宽计算codel的target和interval参数,单位us
function calc_fq_codel_params(band)
    local _target,_interval=5000,100000

    if band <= 0 then
        return _target,_interval
    end

    -- target, 单位us
    _target = 1000*1000*1600*8/1000/band
    if _target < 5000 then
        _target = 5000
    end

    -- interval, 单位us
    _interval = (100 - 5) * 1000 + _target

    return _target,_interval
end
--
function apply_leaf_qdisc(tblist,dev,flow_id,parent_cid,ceil, is_new)
    local tmp_act='add'
    local expr
    local tmp_tblist={}
    if g_leaf_type == 'sfq' then
        -- sfq leaf
        if not is_new then
            expr = string.format(" %s del dev %s parent %s:%s sfq", const_tc_qdisc, dev, flow_id, parent_cid)
            table.insert(tmp_tblist, expr)
        end

        expr = string.format(" %s %s dev %s parent %s:%s sfq perturb 10 ", const_tc_qdisc, tmp_act, dev, flow_id, parent_cid)
        table.insert(tblist, expr)
    elseif g_leaf_type == 'fq_codel' then
        -- fq_codel
        if not is_new then
            expr = string.format(" %s del dev %s parent %s:%s ", const_tc_qdisc, dev, flow_id, parent_cid)
            table.insert(tmp_tblist, expr)
        end

        local target,interval=calc_fq_codel_params(ceil)

        expr = string.format(" %s %s dev %s parent %s:%s fq_codel limit 1024 flows 1024 target %sus interval %sus ",
            const_tc_qdisc, tmp_act, dev, flow_id, parent_cid, target, interval)
        table.insert(tblist, expr)
    else
        -- pfifo as default
        if not is_new then
            expr = string.format(" %s del dev %s parent %s:%s ", const_tc_qdisc, dev, flow_id, parent_cid)
            table.insert(tmp_tblist, expr)
        end

        expr = string.format(" %s %s dev %s parent %s:%s pfifo limit 1024 ",
            const_tc_qdisc, tmp_act, dev, flow_id, parent_cid)
        table.insert(tblist, expr)
    end

    exec_cmd(tmp_tblist,1)

end

-- 特殊的流，arp，<64kb的小包优先, 都走到flow_id:prio_class_id
function apply_arp_small_filter(tblist, dev, act, flow_id, prio_class_id)
    local expr=''
    local proto_id,offset,fprio='ip',0,'3'

    -- pppoe以外，所有协议均为ip
    if cfg.virtual_proto == 'pppoe' then
        -- pppoe-wan,eth0.2,ifb0
        if dev == 'pppoe-wan' then      -- R1CM的pppoe-wan上行是IP包
            offset=0
        elseif dev == 'eth0.2' then     -- R1D/R2D的eth0.2上行包是ppp-sess包
            offset=8
            proto_id='0x8864'
        else -- ifb0, for ctf, it's ip, for std, it' pppoe-wan,only DOWN
            if QOS_VER == 'STD' then    -- R1CM的ifb下行，是pppoe-sess包
                proto_id='0x8864'
                offset=8
            else
                proto_id='ip'   -- R1D/R2D的ifb下行，是IP包
                offset=0
            end
        end
    end

    -- ARP
    --[[
    expr=string.format(" %s %s dev %s parent %s: prio %s protocol arp u32 match u8 0x00 0x00 at 0 flowid %s:%s ",
                    const_tc_filter, act, dev, flow_id, fprio, flow_id, prio_class_id)
    table.insert(tblist,expr)
    --]]

    -- 小包 <64 kbytes, 会包含TCP的SYN/EST/FIN/RST
    local mask = '0xffc0'
    expr=string.format(" %s %s dev %s parent %s: prio %s protocol %s u32 match u16 0x0000 %s at %d flowid %s:%s ",
                    const_tc_filter, act, dev, flow_id, fprio, proto_id, mask, offset + 2, flow_id,  prio_class_id)
    table.insert(tblist,expr)

end

-- 根据interface类型不同，返回stab参数的string
-- Note：因为路由器现在只支持ethernet，不需要类似ATM的分packet，就不需要mpu来做映射
-- 只需要增加每个packet的overhead即可保证限速的精确性
-- Overhead: pppoe, 22; ether, 14
function get_stab_string(dev)
    if g_enable_stab then
        local overhead='0'
        if cfg.virtual_proto == 'pppoe' then
            if dev == 'pppoe-wan' then
                overhead = '14'
            elseif dev == 'eth0.2' then
                overhead = '22'
            else
                if QOS_VER == 'STD' then
                    overhead = '22'
                else
                    overhead = '14'
                end
            end
        else
            overhead = '14'
        end

        return 'stab linklayer ethernet mpu 0 overhead ' .. overhead
    else
        return ' '
    end
end


#!/usr/bin/lua
--通过data flow进行队列分流,使用算法htb,可以对不同的类型的队列进行优先级排序

require 'miqos.common'
-- 流队列的配置
local THIS_QDISC='flow'


-- 将对应的处理方法加入qdisc表
local qdisc_df ={}
qdisc[THIS_QDISC]= qdisc_df

local FLOW_TYPE={
    root={
        fwmark={ {mark='0x00010000/0x000f0000', fprio='3',} },
    },
    high={
        fwmark={ {mark='0x00020000/0x000f0000', fprio='3', }, }, -- special game
        rate='0.10',
        ceil='1.00',
        prio='1',
        quan=8,
        highest_prio='1',
    },
    game={
        fwmark={
            {mark='0x00130000/0x00ff0000', fprio='4', },    -- host-game
        },
        rate='0.1',
        ceil='1.00',
        prio='',
        quan=5,
    },
    web={
        fwmark={ { mark='0x00230000/0x00ff0000', fprio='4'}, }, -- host-web
        rate='0.15',
        ceil='1.00',
        prio='',
        quan=5,
    },
    video={
        fwmark={ { mark='0x00330000/0x00ff0000', fprio='4'}, }, -- host-video
        rate='0.15',
        ceil='0.95',
        prio='',
        quan=5,
    },
    download={
        fwmark={
        { mark='0x00430000/0x00ff0000', fprio='4'},
        { mark='0x00030000/0x00ff0000', fprio='4'},
         },
        rate='0.05',
        ceil='0.95',
        prio='',
        quan=5,
    },
    guest={
        fwmark={ { mark='0x00040000/0x000f0000', fprio='5'}, },
        rate='0.05',
        ceil='0.95',
        prio='6',
        quan=2,
    },
    xq={
        fwmark={ { mark='0x00050000/0x000f0000', fprio='5'}, },
        rate='0.05',
        ceil='0.95',
        prio='7',
        quan=2,
    }
}

local base_rate=0.1
local delta=0.02

-- 不同数据类型的优先级排序
local flow_seq ={
    cur={},
    dft={'game','web','video','download'},
    changed=false,
}

local CLASS_HIER ={
    dft=0x5000,         -- qdisc默认的队列最低优先级队列
    quan_v=1500,        -- quan 至少必须 > MTU,否则会出现发不出包的情况
    ['root']={
        id=0x1000,
        quan=8,
    },
    ['child']={
        ['1']={
            id=0x2000,
            type='high',
        },
        ['2']={
            id=0x3001,
            type='game',
        },
        ['3']={
            id=0x3002,
            type='web',
        },
        ['4']={
            id=0x3003,
            type='video',
        },
        ['5']={
            id=0x3004,
            type='download',
        },
        ['6']={
            id=0x4000,
            type='guest',
        },
        ['7']={
            id=0x5000,
            type='xq',
        },
    }
}

-- 清理dataflow的qdisc规则
function qdisc_df.clean(devs)
    local expr,tblist='',{}
    for _,dev in pairs(devs) do
        expr = string.format("%s del dev %s root ", const_tc_qdisc, dev.dev)
        table.insert(tblist,expr)
    end

    if not exec_cmd(tblist,1) then
        logger(3, 'clean qdisc rules for dataflow mode failed!')
    end

end

local prio_base=1
-- 根据flow-seq更新不同类型的优先级
local function update_prio_on_flow()
    for k, v in pairs(flow_seq.cur) do
        FLOW_TYPE[v].prio=prio_base + k
    end
end

-- //------- 下面来自于host规则的speical rule同样适用于flow优先级调整

-- htb适用的special rule
local special_rule={
    ['HIGH_PRIO_WITHOUT_LIMIT']={
        ftprio='1',
        flow='0',       -- 优先级最高，不受qos影响
    },
    ['HIGH_PRIO_WITH_BANDLIMIT']={
        ftprio='2',
        flow='2000',    -- 优先级较高
    },
}

-- 更新特殊设备的分流规则，分到高级优先级队列
local function apply_special_host_prio_filter(tblist, devs)

    local tmp_tblist={}
    for k, v in pairs(devs) do
        local dir,dev,flow_id=k,v['dev'],v['id']

        -- 先删除所有已经存在的优先级filter
        for type,rule in pairs(special_rule) do
            local expr=string.format("%s del dev %s parent %s: prio %s ",
                const_tc_filter, dev, flow_id, rule.ftprio)
            table.insert(tmp_tblist,expr)
        end

        -- 为所有的special host增加filter
        for k, v in pairs(special_host_list.host) do
            if special_rule[v] then
                local prio = special_rule[v].ftprio
                local flow = special_rule[v].flow
                local nid=tonumber(string.split(k,'.')[4])
                nid='0x' .. dec2hexstr(nid) .. '000000/0xff000000'
                local expr = string.format(" %s replace dev %s parent %s: prio %s handle %s fw classid %s:%s ",
                const_tc_filter, dev, flow_id, prio, nid, flow_id, flow)
                table.insert(tblist, expr)
            end
        end
    end

    -- 执行删除先,因为删除不需要care结果(注意这里是tmp_tblist)
    exec_cmd(tmp_tblist,1)

    return true
end
-- //-------

-- 生成dataflow的qdisc
local function apply_qdisc_class_filter(tblist, devs, act, bands)

    local expr=''

    -- local tmp_tblist={}

    for k, v in pairs(devs) do
        local dir,dev,flow_id=k,v['dev'],v['id']

        -- qdisc 根
        if act == 'add' then
            expr=string.format("%s %s dev %s root handle %s: %s htb default %s ",
                const_tc_qdisc, act, dev, flow_id, get_stab_string(dev), dec2hexstr(CLASS_HIER['dft']) )
            table.insert(tblist,expr)

            -- 根的最高优先级filter
            for _, fwmark in pairs(FLOW_TYPE.root.fwmark) do
                expr=string.format(" %s %s dev %s parent %s: prio %s handle %s fw classid %s:%s",
                    const_tc_filter, act, dev, flow_id, fwmark['fprio'], fwmark['mark'],
                    flow_id, '0')
                table.insert(tblist,expr)
            end
        end

        -- qdisc 类根
        local ratelimit= bands[k]
        local quan_v=math.ceil(CLASS_HIER['quan_v']* CLASS_HIER['root']['quan'])
        local cid=dec2hexstr(CLASS_HIER['root']['id'])
        local buffer = math.ceil(tonumber(ratelimit)*1024/8.0/g_CONFIG_HZ*g_htb_buffer_factor)
        expr = string.format(" %s %s dev %s parent %s: classid %s:%s htb rate %s%s quantum %d burst %d cburst %d",
            const_tc_class, act, dev, flow_id, flow_id, cid, ratelimit, UNIT, quan_v, buffer, buffer)
        table.insert(tblist,expr)

        local pid=cid   -- 父节点id
        -- child 类
        for seq,chd in pairs(CLASS_HIER['child']) do
            local flow_type = FLOW_TYPE[chd['type']]      -- 固定的队列配置
            local cid, lprio = dec2hexstr(chd['id']), flow_type['prio'] --  Note: prio已经被更新了
            --local lrate = math.ceil(ratelimit*flow_type['rate'])
            local lrate = math.ceil(ratelimit*(flow_type['rate']+delta*(7-lprio)))
            local lceil = math.ceil(ratelimit*flow_type['ceil'])
            local buffer=math.ceil(lceil*1024/8.0/g_CONFIG_HZ*g_htb_buffer_factor)
            local quan_v = math.ceil(flow_type.quan * CLASS_HIER['quan_v'])

            -- class
            expr=string.format(" %s %s dev %s parent %s:%s classid %s:%s htb " ..
                    " rate %s%s ceil %s%s prio %s quantum %s burst %d cburst %d",
                    const_tc_class, act, dev, flow_id, pid, flow_id, cid, lrate,
                    UNIT, lceil, UNIT, lprio, quan_v, buffer, buffer)
            table.insert(tblist, expr)

            -- highest_prio
            if chd['highest_prio'] then
                -- arp, 小包 直接进 x:1优先级队列
                apply_arp_small_filter(tblist, dev, 'add', flow_id, cid)
            end

            -- leaf qdisc replace
            apply_leaf_qdisc(tblist,dev,flow_id,cid,lceil)

            if act == 'add' then
                -- filters
                for _, fwmark in pairs(flow_type.fwmark) do
                    expr=string.format(" %s %s dev %s parent %s: prio %s handle %s fw classid %s:%s",
                    const_tc_filter, act, dev, flow_id, fwmark['fprio'], fwmark['mark'],
                    flow_id, cid)
                    table.insert(tblist,expr)
                end
            end

        end
    end

    -- exec_cmd(tmp_tblist,1)

    return true
end

-- 读取flow的配置
function qdisc_df.read_qos_config()
    local system_tbl=get_tbls('miqos','system')
    local tmp_str1=system_tbl['param']['flow']
    if cfg.flow.seq ~= tmp_str1 then
        cfg.flow.seq = tmp_str1
        cfg.flow.changed=true
    end
end

-- 检测dataflow相关的因素是否变化
-- 1.整体带宽值; 2.flow相对的优先级; 3. guest变化
function qdisc_df.changed()
    local flag=false
    local strlog=''
    if cfg.bands.changed then
        strlog = strlog .. '/band'
        cfg.bands.changed=false
        flag=true
    end

    if cfg.guest.changed == 1 then       -- guest限速变化
        strlog = strlog .. '/guest'
        cfg.guest.changed = 0
        flag = true
    end

    if cfg.flow.changed then
        strlog = strlog .. '/flow seq'
        cfg.flow.changed = false

        flow_seq.cur=string.split(cfg.flow.seq,',') -- seq 以`,`做分隔
        if #flow_seq.cur ~= #flow_seq.dft then
            flow_seq.cur = flow.seq.dft
            logger(3,'flow seq parameter error. set rule with default flow-seq.')
        end

        -- 根据新的flow seq更新对应flow的prio
        update_prio_on_flow()

        flag = true
    end

    --Note: 一般情况下，如果有特殊设备加入，都会有host加入从而触发host规则重刷
    if special_host_list.changed then
        strlog = strlog .. '/special host list'
        special_host_list.changed = false
        flag = true
    end

    if strlog ~= '' then
        logger(3,'CHANGE: ' .. strlog)
    end

    return flag
end

-- dataflow的qdisc规则应用
function qdisc_df.apply(origin_qdisc, bands,devs, clean_flag)

    -- origin_qdisc来决定如何处理已经存在的qdisc
    local act='add'
    if not origin_qdisc then    -- origin qdisc空
        act = 'add'
    elseif not qdisc[origin_qdisc] then     --origin qdisc对应的处理函数空
        logger(3, 'ERR: qdisc `' .. origin_qdisc .. '` not found. ')
        return false
    elseif clean_flag then      -- 恒定清除
        qdisc_df.clean(devs)
        act = 'add'
    elseif origin_qdisc == THIS_QDISC then      -- 原始qdisc与当前qdisc相同
        act = 'change'
    else                                        -- 原始qdisc与当前qdisc不同
        qdisc_df.clean(devs)
        act = 'add'
    end

    local tblist={}
    apply_qdisc_class_filter(tblist,devs,act,bands)

    -- 特殊设备的规则
    apply_special_host_prio_filter(tblist, devs)

    if not exec_cmd(tblist, nil) then
        logger(3, 'apply dataflow qdisc failed.')
        return false
    end

    return true
end



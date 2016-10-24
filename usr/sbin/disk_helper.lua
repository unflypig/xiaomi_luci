local fs    = require("nixio.fs")
local nixio = require("nixio")

local pidfile = "/tmp/check_disk_pid"
local notify = false

-- 1:检测中
-- 2:优
-- 3:良
-- 4:差
-- 5:出错:停止插件服务或umount磁盘失败
-- 6:出错:未知磁盘无法操作
-- 7:出错:未挂载磁盘
-- 8:出错:未知错误

function disk_check()
    local disk = require("xiaoqiang.module.XQDisk")
    disk.save_diskstatus(1)
    local hdd = disk.hdd_status()
    if hdd == 98 then
        disk.save_diskstatus(6)
        return
    end
    if hdd == 99 then
        disk.save_diskstatus(7)
        return
    end
    -- if hdd == 2 then
    --     disk.save_diskstatus(4)
    --     return
    -- end
    local prepare = disk.diskchk_prepare()
    if not prepare then
        disk.save_diskstatus(5)
        disk.diskchk_restore()
        return
    end
    local probe = disk.diskchk_probe()
    -- hdd = disk.hdd_status()
    -- if hdd == 2 then
    --     disk.save_diskstatus(4)
    -- elseif hdd < 2 then
    --     if probe then
    --         disk.save_diskstatus(2)
    --     else
    --         disk.save_diskstatus(3)
    --     end
    -- else
    --     disk.save_diskstatus(3)
    -- end
    disk.diskchk_restore()
    if notify then
        os.execute("matool --method notify --params '{\"type\":66}'")
    end
    if probe then
        disk.save_diskstatus(2)
    else
        disk.save_diskstatus(3)
    end
end

function disk_repair()
    local disk = require("xiaoqiang.module.XQDisk")
    disk.save_diskrstatus(1)
    local prepare = disk.diskchk_prepare()
    if not prepare then
        disk.save_diskrstatus(4)
        disk.diskchk_restore()
        return
    end
    local fix = disk.diskchk_fix()
    disk.diskchk_restore()
    if notify then
        os.execute("matool --method notify --params '{\"type\":67}'")
    end
    if fix then
        disk.save_diskrstatus(2)
        disk.save_diskstatus(2)
    else
        disk.save_diskrstatus(3)
    end
end

function disk_fromat()
    local disk = require("xiaoqiang.module.XQDisk")
    disk.save_diskfstatus(1)
    local format = disk.disk_format()
    if format then
        disk.save_diskfstatus(2)
    else
        disk.save_diskfstatus(3)
    end
end

function main()
    local opt = arg[1]
    if arg[2] then
        notify = true
    end
    if not opt then
        return
    end
    local disk = require("xiaoqiang.module.XQDisk")
    local data = fs.readfile(pidfile)
    local pid = data and data:match("(%d+)") or nil
    local lopt = data and data:match("%d+%s(%S+)") or nil
    if pid and pid ~= "" then
        local code = os.execute("kill -0 "..tostring(pid))
        if code == 0 then
            if lopt and lopt ~= opt then
                if opt == "check" then
                    disk.save_diskstatus(0)
                elseif opt == "repair" then
                    disk.save_diskrstatus(0)
                elseif opt == "format" then
                    disk.save_diskfstatus(0)
                end
            end
            return
        end
    end
    pid = nixio.getpid()
    fs.writefile(pidfile, pid.." "..opt)
    if opt == "check" then
        pcall(disk_check)
    elseif opt == "repair" then
        pcall(disk_repair)
    elseif opt == "format" then
        pcall(disk_fromat)
    end
end

main()
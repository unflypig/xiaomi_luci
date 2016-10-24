local fs = require("nixio.fs")
local nixio = require("nixio")
local util = require("luci.util")
local crypto = require("xiaoqiang.util.XQCryptoUtil")

local pid = util.exec("cat /tmp/backup_files_pid 2>/dev/null")
if pid and pid ~= "" then
    local code = os.execute("kill -0 "..tostring(pid))
    if code == 0 then
        return
    end
end

pid = nixio.getpid()
os.execute("echo "..pid.." > /tmp/backup_files_pid")

local param = arg[1]

if param then
    local json = require("json")
    param = crypto.binaryBase64Dec(param)
    local files
    local function decode(str)
        files = json.decode(str)
    end
    if pcall(decode, param) then
        local sys = require("xiaoqiang.util.XQSysUtil")
        sys.backupFiles(files)
    else
        os.execute("echo 3 > /tmp/backup_files_status")
    end
end

local ap        = require("xiaoqiang.module.XQAPModule")
local nixio     = require("nixio")
local posix     = require("posix")
local util      = require("luci.util")
local crypto    = require("xiaoqiang.util.XQCryptoUtil")
local uci       = require("luci.model.uci").cursor()

function log(...)
    posix.openlog("ap-connect", "np", LOG_USER)
    for i, v in ipairs({...}) do
        posix.syslog(4, util.serialize_data(v))
    end
    posix.closelog()
end

function main()
    local pid = util.exec("cat /tmp/ap_connect_pid 2>/dev/null")
    if pid and pid ~= "" then
        local code = os.execute("kill -0 "..tostring(pid))
        if code == 0 then
            log("Already running")
            return
        end
    end

    pid = nixio.getpid()
    os.execute("echo "..pid.." > /tmp/ap_connect_pid")

    local ssid = uci:get("xiaoqiang", "common", "BEUSED_SSID")
    local passwd = uci:get("xiaoqiang", "common", "BEUSED_PASSWD")

    if ssid then
        local encryption
        if not passwd or passwd == "" then
            encryption = "NONE"
        end
        uci:set("xiaoqiang", "common", "AP_STATUS", "CONNECTING")
        local result = ap.setWifiAPMode(ssid, encryption, nil, passwd, nil, nil, nil, nil, nil, true)
        if result.ip then
            -- succeed
            uci:set("xiaoqiang", "common", "AP_STATUS", "SUCCEED")
            ap.serviceRestart(true)
        else
            -- failed
            uci:set("xiaoqiang", "common", "AP_STATUS", "FAILED")
        end
        uci:commit("xiaoqiang")
        log(result)
    else
        log("Param error")
    end
end

main()
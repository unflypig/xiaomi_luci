local net = require("xiaoqiang.util.XQNetUtil")

local key = arg[1]

if key then
    os.execute("/usr/sbin/log_collection.sh")
    net.uploadLogV2(key)
end
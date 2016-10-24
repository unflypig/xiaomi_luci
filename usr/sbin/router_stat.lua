#!/usr/bin/lua

local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
local XQFunction = require("xiaoqiang.common.XQFunction")
local JSON = require("json")

local result = {}

local wan = XQDeviceUtil.getWanLanNetworkStatistics("wan")
local lan = XQDeviceUtil.getWanLanNetworkStatistics("lan")
local disk = XQFunction.thrift_tunnel_to_datacenter([[{"api":26}]])


result["wanSpeed"] = tonumber(wan.downspeed)
result["lanSpeed"] = tonumber(lan.downspeed)
    
    
if disk and disk.code == 0 then
    result["useableSpace"] = math.floor(tonumber(disk.free) / 1024)
else
    result["useableSpace"] = 0
end


local downloads = 0
local downloading = 0
local download = XQFunction.thrift_tunnel_to_datacenter([[{"api":503}]])
if download and download.code == 0 then
  table.foreach(download.uncompletedList,
    function(i,v)
      -- downloads = downloads + 1
      if v.downloadStatus == 1 or v.downloadStatus == 2 then
        downloading = downloading + 1
      end
    end
  )

  table.foreach(download.completedList,
      function(i,v)
          if v.downloadStatus == 4 then
              downloads = downloads + 1
          end     
      end
  )
end

result["downloads"] = downloads
result["downloading"] = downloading

local plugin = XQFunction.thrift_tunnel_to_datacenter([[{"api":601}]])
if plugin and plugin.code == 0 then
    result["installedPluginCount"] = #plugin.data
else
    result["installedPluginCount"] = 0
end
local tmp = {}
tmp["code"] = 0
tmp["result"] = result
print(JSON.encode(tmp))


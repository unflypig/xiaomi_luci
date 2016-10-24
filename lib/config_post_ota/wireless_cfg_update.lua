#!/usr/bin/lua
local px =  require "Posix"
local uci=  require 'luci.model.uci'

function update_section(curs, conf, type, network, device, ifname)
    local id = nil
    curs:foreach(
        conf, type,
        function(s)
            if s['network'] == network and s['device'] == device and not s["ifname"] then
                id = s['.name']
            end
        end)
    if id then
        curs:set(conf, id, 'ifname', ifname)
    end
end


function update_wifi_disabled_section(curs, conf, type)
	local hardwaremodel = curs:get('misc','hardware','model')
	if hardwaremodel ~= 'R1D' then
		return
	end
	curs:foreach(
		conf,type,
		function(s)
			local enabled = curs:get(conf, s['.name'], 'enabled')
			local open = curs:get(conf, s['.name'], 'open')
			if open ~= nil then
				if open == '0' then
					curs:set(conf, s['.name'], 'disabled', '1')
				end
				curs:delete(conf, s['.name'],'open')
			end

			if enabled ~= nil then
				if enabled == '0' then
					curs:set(conf, s['.name'], 'disabled', '1')
				end
				curs:delete(conf, s['.name'], 'enabled')
			end
	end)

end

function add_miwifiready_section(curs, conf, type, name, network, device, ifname, mode, ssid, encryption, hidden, key, disabled)
    local exist = false
    curs:foreach(
	conf,type,
	function(s)
		if s['.name'] == name then
			exist = true
		end
	end)
    if exist == false then
	curs:set(conf, name,'wifi-iface')
	curs:set(conf, name,'device', device)
	curs:set(conf, name,'network', network)
	curs:set(conf, name,'mode', mode)
	curs:set(conf, name,'ifname', ifname)
	curs:set(conf, name,'encryption', encryption)
	curs:set(conf, name,'key', key)
	curs:set(conf, name,'ssid', ssid)
	curs:set(conf, name,'disabled', disabled)
	curs:set(conf, name,'hidden', hidden)
    end
end

function add_guestwifi_section(curs, conf, type, name, network, device, ifname, mode, ssid, encryption, hidden, key, disabled)
    local exist = false
    curs:foreach(
    conf,type,
    function(s)
        if s['.name'] == name then
            exist = true
        end
    end)
    if exist == false then
        curs:set(conf, name,'wifi-iface')
        curs:set(conf, name,'device', device)
        curs:set(conf, name,'network', network)
        curs:set(conf, name,'mode', mode)
        curs:set(conf, name,'ifname', ifname)
        curs:set(conf, name,'disabled', disabled)
    end
end

function main()

    local curs = uci.cursor()
    local hardwaremodel = curs:get('misc','hardware','model')

    -- r1d
    update_section(curs, 'wireless', 'wifi-iface', 'lan', 'wl0', 'wl0')
    update_section(curs, 'wireless', 'wifi-iface', 'lan', 'wl1', 'wl1')
    update_section(curs, 'wireless', 'wifi-iface', 'guest', 'wl1', 'wl1.2')
    if hardwaremodel == 'R1D' or hardwaremodel == 'R2D' then
        add_miwifiready_section(curs, 'wireless', 'wifi-iface', 'miwifi_ready', 'ready', 'wl1', 'wl1.3', 'ap', 'miwifi_ready', 'none', '1', '', '')
    end
    update_wifi_disabled_section(curs, 'wireless', 'wifi-iface')
    -- r1cm
    update_section(curs, 'wireless', 'wifi-iface', 'lan', 'mt7612', 'wl0')
    update_section(curs, 'wireless', 'wifi-iface', 'lan', 'mt7620', 'wl1')
    if hardwaremodel == 'R1CM' then
        add_miwifiready_section(curs, 'wireless', 'wifi-iface', 'miwifi_ready', 'ready', 'mt7620', 'wl2', 'ap', 'miwifi_ready', 'none', '1', '', '')
        add_guestwifi_section(curs, 'wireless', 'wifi-iface', 'guest_2G', 'guest', 'mt7620', 'wl3', 'ap', 'guest_2G', 'none', '1', '', '1')
    end
    -- r1cl
    update_section(curs, 'wireless', 'wifi-iface', 'lan', 'mt7628', 'wl1')
    if hardwaremodel == 'R1CL' then
        add_miwifiready_section(curs, 'wireless', 'wifi-iface', 'miwifi_ready', 'ready', 'mt7628', 'wl2', 'ap', 'miwifi_ready', 'none', '1', '', '')
        add_guestwifi_section(curs, 'wireless', 'wifi-iface', 'guest_2G', 'guest', 'mt7628', 'wl3', 'ap', 'guest_2G', 'none', '1', '', '1')
    end
    curs:save('wireless')
    curs:commit('wireless')

end

main()





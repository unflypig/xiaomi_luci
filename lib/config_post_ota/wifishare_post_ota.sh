#!/bin/sh
# Copyright (C) 2015 Xiaomi
. /lib/functions.sh

old_timeout=$(uci get wifishare.global.auth_timeout 2>/dev/null)
[ "$old_timeout" == "30" ] && { uci set wifishare.global.auth_timeout=60; uci commit wifishare;}

guest_configed=$(uci get wireless.guest_2G  2>/dev/null)
isolate_configed=$(uci get wireless.guest_2G.ap_isolate  2>/dev/null)

[ "$guest_configed" != "" ] && [ "$isolate_configed" == "" ] && {
    uci set wireless.guest_2G.ap_isolate=1;
    uci commit wireless
}

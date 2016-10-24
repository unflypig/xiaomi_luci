#!/bin/sh /etc/rc.common
# Copyright (C) 2010-2012 OpenWrt.org

START=99
STOP=20

start()
{
	$1/xiaomi_router/bin/plugin_start_impl_R1CM.sh $1 &
}

stop()
{
	$1/xiaomi_router/bin/plugin_stop_impl_R1CM.sh $1 &
}

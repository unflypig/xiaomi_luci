#!/bin/sh

pid=`pidof flash.sh`
[ -z "$pid" ] && {
	#no upgrade in progress, just reboot
	reboot
}

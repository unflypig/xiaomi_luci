#!/bin/sh /etc/rc.common
# Copyright (C) 2010-2012 OpenWrt.org

START=99
STOP=20

#usbDeployRootPath=$(cat /proc/mounts | grep /dev/sd |head -n1|cut -d' ' -f2);
usbDeployRootPath=

get_root_path(){
cat /proc/mounts | grep /dev/sd | while read line
do
	local dev=$(echo $line | cut -d' ' -f1)
	if [ -n "$dev" ] && [ -e "$dev" ]; then
		usbDeployRootPath=$(echo $line | cut -d' ' -f2)
		echo $usbDeployRootPath > /tmp/usbDeployRootPath.conf
		break
	fi
done
}

list_alldir(){  
	local init_root=$1
	local action=$2
	for file in `ls $init_root`  
	do  
		if [ -f "$init_root/$file" ];then

			if [ "$file" = "000-cp_preinstall_plugins.sh" ];then
				continue
			fi

			if [ "$file" = "001-samba" ];then
				continue
			fi
			if [ "$file" = "xunlei" ];then
				continue
			fi
			if [ "$file" = "plugin_start_script_R1CM.sh" ];then
				continue
			fi
			$init_root/$file $action $usbDeployRootPath &
		fi  
	done  
}  

start()
{

	get_root_path
	usbDeployRootPath=$(cat /tmp/usbDeployRootPath.conf)

	rm -rf $usbDeployRootPath/xiaomi_router/appdata/app_infos/2882303761517280998.manifest
        rm -rf $usbDeployRootPath/xiaomi_router/appdata/2882303761517280998/

	/usr/sbin/sysapihttpd -s reload

	if [ -n "$usbDeployRootPath" ];then
		rm -rf /tmp/xiaomi_router
		mkdir -p /tmp/xiaomi_router
		cp -r $usbDeployRootPath/xiaomi_router/init /tmp/xiaomi_router/
		if [ -f "$usbDeployRootPath/xiaomi_router/init/000-cp_preinstall_plugins.sh" ];then
			$usbDeployRootPath/xiaomi_router/init/000-cp_preinstall_plugins.sh start $usbDeployRootPath
		fi
		if [ -f "$usbDeployRootPath/xiaomi_router/init/001-samba" ];then
			$usbDeployRootPath/xiaomi_router/init/001-samba start $usbDeployRootPath
		fi
		if [ -f "$usbDeployRootPath/xiaomi_router/init/xunlei" ];then
			$usbDeployRootPath/xiaomi_router/init/xunlei start $usbDeployRootPath
		fi
		if [ -f "$usbDeployRootPath/xiaomi_router/init/plugin_start_script_R1CM.sh" ];then
			$usbDeployRootPath/xiaomi_router/init/plugin_start_script_R1CM.sh restart $usbDeployRootPath
		fi
		list_alldir $usbDeployRootPath/xiaomi_router/init start
	fi
}

stop()
{
	usbDeployRootPath=$(cat /tmp/usbDeployRootPath.conf)
	rm /tmp/usbDeployRootPath.conf
	if [ -n "$usbDeployRootPath" ];then
		list_alldir /tmp/xiaomi_router/init stop
		wait
		if [ -f "/tmp/xiaomi_router/init/xunlei" ];then
			/tmp/xiaomi_router/init/xunlei stop $usbDeployRootPath
		fi
		if [ -f "/tmp/xiaomi_router/init/001-samba" ];then
			/tmp/xiaomi_router/init/001-samba stop $usbDeployRootPath
		fi
		if [ -f "$usbDeployRootPath/xiaomi_router/init/plugin_start_script_R1CM.sh" ];then
			$usbDeployRootPath/xiaomi_router/init/plugin_start_script_R1CM.sh stop $usbDeployRootPath
		fi

		#local dev=$(getdisk mnt | grep "$usbDeployRootPath\$" | cut -d',' -f1)
		#if [ -n "$dev" ] && [ -e "$dev" ] ;then
		#	list_alldir $usbDeployRootPath/xiaomi_router/init stop
		#else
		#	list_alldir /tmp/xiaomi_router/init stop
		#fi
	fi
}


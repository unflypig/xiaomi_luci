#!/bin/sh
#

. /lib/upgrade/common.sh

klogger(){
	local msg1="$1"
	local msg2="$2"

	if [ "$msg1" = "-n" ]; then
		echo  -n "$msg2" >> /dev/kmsg 2>/dev/null
	else
		echo "$msg1" >> /dev/kmsg 2>/dev/null
	fi

	return 0
}

hndmsg() {
	if [ -n "$msg" ]; then
		echo "$msg" >> /dev/kmsg 2>/dev/null
		if [ `pwd` = "/tmp" ]; then
			rm -rf $filename 2>/dev/null
		fi
		exit 1
	fi
}

upgrade_uboot() {
	if [ -f uboot.bin ]; then
		klogger -n "Burning uboot..."
		mtd write uboot.bin Bootloader >& /dev/null
		if [ $? -eq 0 ]; then
			klogger "Done"
		else
			klogger "Error"
			exit 1
		fi
	fi
}

upgrade_firmware() {
	if [ -f firmware.bin ]; then
		klogger -n "Burning firmware..."
		mtd -r write firmware.bin OS1 >& /dev/null
		if [ $? -eq 0 ]; then
			klogger "Done"
		else
			klogger "Error"
			exit 1
		fi
	fi
}


if [ $# = 0 ] || [ $# -gt 2 ] ; then
	klogger "USAGE: $0 factory.bin 0(0:reboot, 1:don't reboot)"
	exit 1;
fi

#check pid exist
pid_file="/tmp/pid_xxxx"
if [ -f $pid_file ]; then
	exist_pid=`cat $pid_file`
	if [ -n $exist_pid ]; then
		kill -0 $exist_pid 2>/dev/null
		if [ $? -eq 0 ]; then
			klogger "Upgrading, exit... $?"
			exit 1
		else
			echo $$ > $pid_file
		fi
	else
		echo $$ > $pid_file
	fi
else
	echo $$ > $pid_file
fi

_ver=`cat /usr/share/xiaoqiang/xiaoqiang_version`
klogger "Begin Ugrading..., current version: $_ver"

echo 3 > /proc/sys/vm/drop_caches
sync

[ -f $1 ] || msg="dir: $1 is not existed, upgrade failed"
hndmsg

dir_name=`dirname $1`
klogger "Change Dir to: $dir_name"
cd $dir_name

filename=`basename $1`
[ -f $filename ] || msg="file: $filename is not existed, upgrade failed"
hndmsg

klogger -n "Verify Image: $filename..."
mkxqimage -v $filename || msg="Check Failed!!!"
hndmsg
klogger "Checksum O.K."

wifi down
rmmod mt7620
rmmod mt76x2e

if [ -f "/etc/init.d/sysapihttpd" ] ;then
    /etc/init.d/sysapihttpd stop 2>/dev/null
fi

if [ $dir_name != "/tmp" ]; then
	klogger "Change Dir to /tmp"
        cp $1 /tmp
        cd /tmp
fi

# gently stop pppd, let it close pppoe session
ifdown wan
timeout=5
while [ $timeout -gt 0 ]; do
    pidof pppd >/dev/null || break
    sleep 1
    let timeout=timeout-1
done

# clean up upgrading environment
# call shutdown scripts with some exceptions
wait_stat=0
klogger "Calling shutdown scripts"
for i in /etc/rc.d/K*; do
	# filter out K01reboot-wdt and K99umount
	echo "$i" | grep -q '[0-9]\{1,100\}reboot-wdt$'
	if [ $? -eq 0 ]
	then
		klogger "$i skipped"
		continue
	fi
	echo "$i" | grep -q '[0-9]\{1,100\}umount$'
	if [ $? -eq 0 ]
	then
		klogger "$i skipped"
		continue
	fi

	if [ ! -x "$i" ]
	then
		continue
	fi

	# wait for high-priority K* scripts to finish
	echo "$i" | grep -qE "K9"
	if [ $? -eq 0 ]
	then
		if [ $wait_stat -eq 0 ]
		then
			wait
			sleep 2
			wait_stat=1
		fi
		$i shutdown 2>&1
	else
		$i shutdown 2>&1 &
	fi
done

# try to kill all userspace processes
# at this point the process tree should look like
# init(1)---sh(***)---flash.sh(***)
for i in $(ps w | grep -v "flash.sh" | grep -v "/bin/ash" | grep -v "PID" | awk '{print $1}'); do
        if [ $i -gt 100 ]; then
	        kill -9 $i 2>/dev/null
        fi
done

gpio 1 1
gpio 3 1
gpio l 26 2 2 1 0 4000 #led yellow flashing

#update nvram setting when upgrading
if [ "$2" = "1" ]; then
	nvram set restore_defaults=1
	klogger "Restore defaults is set."
else
	nvram set restore_defaults=2
fi
nvram set flag_flash_permission=0
nvram set flag_ota_reboot=1
nvram set flag_upgrade_push=1
nvram commit

# tell server upgrade is finished
uci set /etc/config/messaging.deviceInfo.UPGRADE_STATUS_UPLOAD=0
uci commit
klogger "messaging.deviceInfo.UPGRADE_STATUS_UPLOAD=`uci get /etc/config/messaging.deviceInfo.UPGRADE_STATUS_UPLOAD`"
klogger "/etc/config/messaging : `cat /etc/config/messaging`"

# prepare the minimum working environment
mount -o remount,size=100% /tmp
lib_list="/lib/ld-uClibc.so.0 /lib/libc.so.0 /lib/libdl.so.0 /lib/libm.so.0 \
/lib/libubox.so /lib/libcrypt.so.0 /lib/libgcc_s.so.1 /usr/lib/libcrypto.so.1.0.0"
bin_list="/bin/busybox /bin/ash /bin/sh /bin/cat /bin/mount /bin/umount \
/bin/mkxqimage /sbin/reboot /usr/sbin/nvram"

mkdir -p /tmp/update_environment/lib
mkdir -p /tmp/update_environment/bin
mkdir -p /tmp/update_environment/proc
mkdir -p /tmp/update_environment/dev
mkdir -p /tmp/update_environment/usr/share/xiaoqiang/
for lib in $lib_list
do
	if [ -e $lib ]
	then
		cp -L $lib /tmp/update_environment/lib
	else
		# in case the lib_list is outdated, abort early
		msg="Lib $lib not found"
		hndmsg
		reboot -f
	fi
done
for bin in $bin_list
do
	if [ -e $bin ]
	then
		cp -P $bin /tmp/update_environment/bin
	else
		# in case the bin_list is outdated, abort early
		msg="Bin $bin not found"
		hndmsg
		reboot -f
	fi
done
cp /usr/share/xiaoqiang/public.pem /tmp/update_environment/usr/share/xiaoqiang/
mv $filename /tmp/$filename
pivot /tmp/update_environment /old_root && {
	umount -l /old_root
	klogger "Switch to ram-based rootfs"
}

klogger -n "Begin Upgrading and Rebooting..."
mkxqimage -w /tmp/$filename || msg="Upgrade Failed!!!"
hndmsg

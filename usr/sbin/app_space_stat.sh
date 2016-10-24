#!/bin/sh
# Copyright (C) 2015 Xiaomi

TMPFILE1=/tmp/.app_storage1
TMPFILE2=/tmp/.app_storage2

remove_large_file() {
	lst=`find /data/userdisk/ -size +100000k -type f`
	for file in "$lst"
	do
		size=`stat -c %s "$file"`
		logger -s -p 3 -t "app_space" "Large file "$file", size="$size" Bytes"
		logger stat_points_none app_space_large=""$file":"$size""
		rm -rf "$file"
	done
}


du -xs /data/userdisk/* | sort -n > "$TMPFILE1"
du -xs /data/userdisk/appdata/* | sort -n >> "$TMPFILE1"

while read line
do
	sz=`echo $line | awk '{print $1}'`
	[ "$sz" = "0" ] && continue

	path=`echo $line | awk '{print $2}'`
	appid=`basename $path`

	echo -n "$appid":"$sz", >> "$TMPFILE2"
done < "$TMPFILE1"

tmp_free=`df | grep -w "/tmp" | head -n 1 | awk '{print $4}'`
echo -n "tmp":"$tmp_free", >> "$TMPFILE2"

data_free=`df | grep -w "/data" | head -n 1 | awk '{print $4}'`
echo -n "data":"$data_free" >> "$TMPFILE2"

value=`cat $TMPFILE2`
model=`cat /proc/xiaoqiang/model`

logger stat_points_none app_space_"$model"="$value"

rm -f "$TMPFILE1"
rm -f "$TMPFILE2"

remove_large_file

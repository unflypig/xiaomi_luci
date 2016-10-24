#!/bin/sh
root_path=$1
root_dev=$root_path/dev

umount $root_dev

mkdir -p $root_dev

mount /dev $root_dev
mount -t devpts devpts $root_dev/pts

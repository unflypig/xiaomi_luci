
REC=/tmp/record.txt
REC_VER=1

[ -b /dev/sda ] || exit 0

rm -f $REC
touch $REC

family=`smartctl -i /dev/sda | grep "Model Family" | awk -F ":" '{print $2}' | xargs | sed 's/ /_/g'`
dmodel=`smartctl -i /dev/sda | grep "Device Model" | awk -F ":" '{print $2}' | xargs | sed 's/ /_/g'`

#some device may not have smart capability
[ -z "$family" -a -z "$dmodel" ] && exit 0

echo -n "Version:$REC_VER;" >> $REC
echo -n "Family:$family;" >> $REC
echo -n "Model:$dmodel;" >> $REC

smartctl -A /dev/sda | grep ATTRIBUTE_NAME -A 100 | tail +2 | while read line
do
	[ -z "$line" ] && continue
	echo -n $line | awk '{printf "%d:%d,%d,%d,%s,%d;",$1,$4,$5,$6,$9,$10}' >> $REC
done

echo -n "END;" >> $REC
sed -i "s/ /_/g" $REC
value=`cat $REC`
model=`cat /proc/xiaoqiang/model`

logger stat_points_none hdd_stat_v2_"$model"="$value"

rm -f $REC

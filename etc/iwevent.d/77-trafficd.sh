[ "$ACTION" = "DISASSOC" ] && [ -n "$STA" ] && {
	/usr/bin/matool --method reportEvents --params "[ { \"eventID\": 0, \"mac\": \"$STA\", \"ip\": \"\", \"payload\": \"\" } ]"
	logger -p warn -t trafficd '/usr/bin/matool --method reportEvents --params ' "[ { \"eventID\": 0, \"mac\": \"$STA\", \"ip\": \"\", \"payload\": \"\" } ]"
}

[ "$ACTION" = "ASSOC" ] && [ -n "$STA" ] && {
	/usr/bin/matool --method reportEvents --params "[ { \"eventID\": 1, \"mac\": \"$STA\", \"ip\": \"\", \"payload\": \"\" } ]"
	logger -p warn -t trafficd '/usr/bin/matool --method reportEvents --params ' "[ { \"eventID\": 1, \"mac\": \"$STA\", \"ip\": \"\", \"payload\": \"\" } ]"
}

#!/bin/sh

authorize=`uci get misc.iwevent.authorize`

if [ "$authorize" = "1" ]; then
    [ "$ACTION" = "AUTHORIZE" ] && [ -n "$STA" ] && {
        feedPush "{\"type\":1,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
    }
else
    [ "$ACTION" = "ASSOC" ] && [ -n "$STA" ] && {
        feedPush "{\"type\":1,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
    }
fi

[ "$ACTION" = "DISASSOC" ] && [ -n "$STA" ] && {
    feedPush "{\"type\":2,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
}

[ "$ACTION" = "MIC_DIFF" ] && [ -n "$STA" ] && {
    feedPush "{\"type\":14,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
}

[ "$ACTION" = "BLACKLISTED" ] && [ -n "$STA" ] && {
    feedPush "{\"type\":15,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
}

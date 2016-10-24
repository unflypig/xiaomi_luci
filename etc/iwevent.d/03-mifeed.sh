#!/bin/sh

authorize=`uci get misc.iwevent.authorize`

if [ "$authorize" = "1" ]; then
    [ "$ACTION" = "AUTHORIZE" ] && [ -n "$STA" ] && {
        mifeed "{\"type\":1,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
    }
else
    [ "$ACTION" = "ASSOC" ] && [ -n "$STA" ] && {
        mifeed "{\"type\":1,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
    }
fi

[ "$ACTION" = "DISASSOC" ] && [ -n "$STA" ] && {
    mifeed "{\"type\":2,\"data\":{\"mac\":\"$STA\",\"dev\":\"$DEVNAME\"}}"
}
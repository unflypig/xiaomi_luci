#!/bin/sh

authorize=`uci get misc.iwevent.authorize`

if [ "$authorize" = "1" ]; then
    [ "$ACTION" = "AUTHORIZE" ] && [ -n "$STA" ] && {
        startscene.lua ASSOC $STA
    }
else
    [ "$ACTION" = "ASSOC" ] && [ -n "$STA" ] && {
        startscene.lua $ACTION $STA
    }
fi

[ "$ACTION" = "DISASSOC" ] && [ -n "$STA" ] && {
    startscene.lua $ACTION $STA
}
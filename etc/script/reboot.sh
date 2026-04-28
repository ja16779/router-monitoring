#!/bin/sh

DAY=$(date +%d)
WEEKDAY=$(date +%u)

# Verifica si es domingo y si el día es menor o igual a 7 (primera semana)
if [ "$WEEKDAY" -eq 7 ] && [ "$DAY" -le 7 ]; then
    /sbin/reboot
else

    echo $WEEKDAY && echo $DAY
fi


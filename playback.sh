#!/bin/bash - 
#===============================================================================
#
#          FILE: playback.sh
# 
#         USAGE: ./playback.sh 
#   DESCRIPTION: playback Android input events(touch screen & Hard keys)
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jituo.Xuan
#  ORGANIZATION: Personal
#       CREATED: 2015.08.13 16:38
#      REVISION: ---
#===============================================================================

#apk信息
PACKAGE=$(awk -F '=' '$1~/PACKAGE/{print $2;exit}' ./config.ini)
ACTIVITY=$(awk -F '=' '$1~/LAUNCH_ACTIVITY/{print $2;exit}' ./config.ini)
#重启app
adb shell am force-stop $PACKAGE
adb shell am start -W -n $PACKAGE/$ACTIVITY
#回放事件
adb shell /data/local/tmp/cmds
#不同的手机权限系统不一样，如果你得手机需要root权限下才能运行回放命令，请替换为以下回放命令
#adb shell su -c busybox chmod 755 /data/local/tmp/cmds
#adb shell su -c /data/local/tmp/cmds

adb shell am force-stop $PACKAGE
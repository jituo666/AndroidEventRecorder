#!/bin/bash - 
#===============================================================================
#
#          FILE: recorder.sh
# 
#         USAGE: ./recorder.sh 
#   DESCRIPTION: recording Android input events(touch screen & Hard keys)
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jituo.Xuan
#  ORGANIZATION: Personal
#       CREATED: 2015.08.13 16:38
#      REVISION: ---
#===============================================================================

if [ "$1" == "-h" ]; then
    echo "-s: to generate Shell file "
    echo "-c: to generate C program file "
    echo "-h: help "
    exit
fi
#apk信息
PACKAGE=$(awk -F '=' '$1~/PACKAGE/{print $2;exit}' ./config.ini)
ACTIVITY=$(awk -F '=' '$1~/LAUNCH_ACTIVITY/{print $2;exit}' ./config.ini)
#设备信息
DEVICE_NAME=$(awk -F '=' '$1~/DEVICE_NAME/{print $2;exit}' ./config.ini)
echo "Touch device is [ $DEVICE_NAME ]"
#文件定义
file=./out/cmds.txt
t0file=tmp0.txt
t1file=tmp1.txt
t2file=tmp2.txt

#-------------------------------------------------------------------------------
#  函数: 比较两个 Float 数值
#-------------------------------------------------------------------------------
compare_float(){
    local a=$1
    local b=$2
    awk -va=$a -vb=$b 'BEGIN {if(a>b) printf("true"); else printf("false")}'
}

compare_string(){
    local a=$1
    local b=$2
    awk -va=$a -vb=$b 'BEGIN {if(a!=b) printf("true"); else printf("false")}'
}

#组合事件过滤条件

echo "-----recorder started"
trap "echo  '= recoder stopped ='" SIGINT
#重启app
adb shell am force-stop $PACKAGE
adb shell am start -W -n $PACKAGE/$ACTIVITY
#获取输出事件并重定向到文件
adb shell getevent -t | grep -E --line-buffered "$DEVICE_NAME" >$t0file
echo "-=============$DEVICE_NAME"
#替换"[","]","/dev/input/event/",":"为空字符串
sed 's/\[//g;s/\]//g;s/\/dev\/input\/event//g;s/\://g' $t0file >$t1file
#把文件中的相关内容格式化
#正则解释:
#     1. awk - 转换 第3列 和 第4列 数值为十进制模式(因为ioctl接收的是十进制)
#     2. sed - 4294967295 实为 -1, 原因是-1为0xFFFF,FFFF(4294967295)
cat $t1file |\
    awk '{print $2, strtonum("0x"$3), strtonum("0x"$4), strtonum("0x"$5)}' |\
    sed 's/4294967295/-1/g' >$t0file

#sleep_arry_line=()                              # 有睡眠操作的event
#sleep_arry_time=()                              # 保存睡眠时间
awk '{print $1}' $t1file >$t2file                # 抽取时间列，存至 $t2file
tstart=$(sed -n '1p' $t2file)
tend=$(sed -n '$p' $t2file)
tdiff=0
index=1
while read t; do
    case $t in
        $tstart|$tend )                         # 第一个时间和最后一个时间无需比较
            tdiff=0.000000
            ;;
        * )
            prev=$(sed -n "$(($index-1)) p" $t2file)
            tdiff=$(awk -va=$t -vb=$prev 'BEGIN {printf("%lf\n",a-b)}')
            ;;
    esac
        echo "$tdiff "
        #sleep_arry_line+=($index)
        sleep_arry_time+=($(awk -va=$tdiff 'BEGIN {print a*1000000}'))

    ((index++))
done < $t2file >$t1file    

paste $t1file $t0file >$file

rm $t0file $t1file $t2file
echo "-----Generate txt file, output file is [ $file ]"

if ([[ $1 =~ "s" ]]); then
    # 两个event时间差
    # 因为一个触屏操作(如点击一下)，需由多个event来组成
    mindiff=0.01
    shellfile="./out/cmds.sh"
    scmdfile="scmd.txt"
    ssleepfile="ssleep.txt"
    ssleepfinalfile="sleep.txt"
    awk '{print "sendevent /dev/input/event"$2" "$3" "$4" "$5}' $file >$scmdfile 
    awk '{print $1}' $file >$ssleepfile
    index=1
    while read t;do
        if $(compare_float $mindiff $t); then
            echo ''
        else 
            echo "sleep $t; "
        fi
    done < $ssleepfile > $ssleepfinalfile
    paste $ssleepfinalfile $scmdfile >$shellfile
    rm $scmdfile $ssleepfinalfile $ssleepfile
    adb push ./out/cmds.sh /data/local/tmp/cmds.sh
    echo "-----Generate shell file , output file is [ $shellfile ]"
fi
if ([[ $1 =~ "c" ]]); then
    modelcfile=template.c                           # 模板C语言文件
    targetcfile=./jni/cmds.c
    tcfile=tmpc.c
    mindiff=$(awk -F '=' '$1~/TIME_INTERVAL/{print $2;exit}' ./config.ini)
    currentdev=""
    >$tcfile
    while read line; do                             # 输出临时C语言文件
        sleeptime=$(echo $line|awk '{print ($1)*1000000}')
        device=$(echo $line|awk '{print "/dev/input/event"$2}')
        type=$(echo $line|awk '{print $3}')
        code=$(echo $line|awk '{print $4}')
        value=$(echo $line|awk '{print $5}')
        if $(compare_float $sleeptime $mindiff); then
            echo "    usleep($sleeptime);" >>$tcfile
        fi
        if $(compare_string $currentdev $device);then 
            currentdev=$device
            cat<<EOF >>$tcfile
    event.type = $type;
    event.code = $code;
    event.value = ${value}u;
    fd = open("$device", O_RDWR);
    write(fd, &event, event_size);
EOF
        else
    cat<<EOF >>$tcfile
    event.type = $type;
    event.code = $code;
    event.value = ${value}u;
    write(fd, &event, event_size);
EOF
        fi
    done < $file
    append_line=55
    sed "$append_line r $tcfile" $modelcfile >$targetcfile
    rm $tcfile
    echo "-----Generate C file , output file is [ $targetcfile ]"
    #编译生成的c命令文件
    cd ./jni
    ndk-build
    cd ../
    cp ./libs/armeabi-v7a/cmds ./out/cmds
    adb push ./out/cmds /data/local/tmp/cmds
    rm -r ./libs ./obj
fi
#关闭app
adb shell am force-stop $PACKAGE
echo "-----Successfully, totally spent time: $SECONDS seconds"
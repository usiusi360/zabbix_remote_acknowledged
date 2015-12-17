#!/bin/bash
#=======================================================
# Usage：
# /usr/lib/zabbix/alertscripts/zabbix-slack-alertscript.sh "{TRIGGER.STATUS}" "{TRIGGER.NSEVERITY}" "{EVENT.DATE}  {EVENT.TIME}" "{TRIGGER.SEVERITY}" "{HOST.NAME1}" "{TRIGGER.NAME}:{ITEM.NAME1}" "({HOST.NAME1}:{ITEM.KEY1}): {ITEM.VALUE1}" "{ITEM.ID}"
#=======================================================
##### Slack Setting #####
# Slack incoming web-hook URL and user name
URL='https://hooks.slack.com/services/YourURL'
USERNAME='Zabbix'

# Slack Channel Name
## Channel ID you can confirm at this page
## https://api.slack.com/methods/channels.list/test

CHANNEL1='#alert_high'
CHANNEL1_ID='YourChannelID'
#CHANNEL2='#alert_low'
#CHANNEL2_ID='YourChannelID'
API_TOKEN='YourToken'

##### Zabbix Setting #####
ZB_USER='admin'
ZB_PASS='Your_Password'
ZB_URL='http://XXX.XXX.XXX.XXX/zabbix'

# Graph Setting
PERIOD=10800
HEIGHT=150
WIDTH=600

#####
CURL_OPT='-m 10 --retry 1 -w %{http_code}\n -s'

#=======================================================
function abort(){
     #local priority="user.info"
     #logger -i -p $priority -t `basename $0` "$1"
     echo "`date '+%Y/%m/%d %H:%M:%S'` $1" >> /var/log/zabbix/zabbix-slack-alertscript.log
     exit 1
}


#////////////////
#  Main 
#////////////////

COOKIE_NAME=/tmp/cookies.txt
STIME=`date +"%Y%m%d%H%M%S"`

TRIGGER_STATUS="$1"
if [ "${TRIGGER_STATUS}" == 'OK' ]; then
    EMOJI=':smile:'
elif [ "${TRIGGER_STATUS}" == 'PROBLEM' ]; then
    EMOJI=':rage:'
else
    EMOJI=':ghost:'
fi

#/// channel set
# $2:TRIGGER.NSEVERITY

#if [ $2 -gt 3 ]; then
    CHANNEL=${CHANNEL1}
    CHANNEL_ID=${CHANNEL1_ID}
    SEV_FLAG=HIGH
#else
#    CHANNEL=${CHANNEL2}
#    CHANNEL_ID=${CHANNEL2_ID}
#    SEV_FLAG=LOW
#fi

MESSAGE="STATUS:$1\nDATE:$3\nSEVERITY:$4\nHOST_NAME:$5\nTRIGGER_NAME:$6\nVALUE:$7"
PAYLOAD="payload={\"channel\": \"${CHANNEL}\", \"username\": \"${USERNAME}\", \"text\": \"${MESSAGE}\", \"icon_emoji\": \"${EMOJI}\"}"

#/// message write
RET_MES=`curl ${CURL_OPT} -o /dev/null -X POST --data-urlencode "${PAYLOAD}" ${URL}`
if [ "${RET_MES}" != "200" ]; then
    abort "[ERROR] slack message write error.[SEVERITY:$4/HOST_NAME:$5/TRIGGER_NAME:$6/ReturnCode:${RET_MES}]"
fi

#// graph upload
if [ "$8" != "" ]; then
    ITEM_ID="$8"
    OUTPUT_FILE="/tmp/ID${ITEM_ID}-${STIME}.png"

    RET_AUTH=`curl ${CURL_OPT}  -o /dev/null -c "${COOKIE_NAME}" \
       -d "form_refresh=1&name=${ZB_USER}&password=${ZB_PASS}&enter=Sign%20in" "${ZB_URL}/index.php"`
    if [ "${RET_AUTH}" != "302" ]; then
        abort "[ERROR] Zabbix auth error.[SEVERITY:$4/HOST_NAME:$5/TRIGGER_NAME:$6/ITEM_ID:$8/ReturnCode:${RET_AUTH}]"
    fi

    RET_DOWNFILE=`curl ${CURL_OPT} -o "${OUTPUT_FILE}" \
       -b "${COOKIE_NAME}" "${ZB_URL}/chart.php?itemids=${ITEM_ID}&period=${PERIOD}&stime=${STIME}&height=${HEIGHT}&width=${WIDTH}"`
    if [ "${RET_DOWNFILE}" != "200" ]; then
        abort "[ERROR] Zabbix graph download error.[SEVERITY:$4/HOST_NAME:$5/TRIGGER_NAME:$6/ITEM_ID:$8/ReturnCode:${RET_DOWNFILE}]"
    fi

    RET_UPFILE=`curl ${CURL_OPT}  -o /dev/null -F file=@${OUTPUT_FILE} -F channels="${CHANNEL_ID}" -F token="${API_TOKEN}" https://slack.com/api/files.upload`
    if [ "${RET_UPFILE}" != "200" ]; then   
        abort "[ERROR] Zabbix graph upload error.[SEVERITY:$4/HOST_NAME:$5/TRIGGER_NAME:$6/ITEM_ID:$8/ReturnCode:${RET_UPFILE}]"
    fi
    
    rm -f ${OUTPUT_FILE}
fi

exit 0

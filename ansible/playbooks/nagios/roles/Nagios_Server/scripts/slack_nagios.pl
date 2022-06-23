#!/bin/bash

WEBHOST_NAGIOS="nagios.adoptopenjdk.net"
SLACK_CHANNEL="#infrastructure-bot"
SLACK_BOTNAME="nagios"

#Set the message icon based on Nagios service state
if [ "$NAGIOS_SERVICESTATE" = "OK" ]
then
    ICON_EMOJI=":white_check_mark:"
elif [ "$NAGIOS_SERVICESTATE" = "WARNING" ]
then
    ICON_EMOJI=":warning:"
elif [ "$NAGIOS_SERVICESTATE" = "CRITICAL" ]
then
    ICON_EMOJI=":exclamation:"
elif [ "$NAGIOS_SERVICESTATE" = "UNKNOWN" ]
then
    ICON_EMOJI=":question:"
else
    ICON_EMOJI=":fire:"
fi


#request for posting to a channel
curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"icon_emoji\": \":nagios:\", \"text\": \"${ICON_EMOJI} HOST: ${NAGIOS_HOSTNAME}   SERVICE: ${NAGIOS_SERVICEDISPLAYNAME} STATE: ${NAGIOS_SERVICESTATE} MESSAGE: ${NAGIOS_SERVICEOUTPUT} <https://${WEBHOST_NAGIOS}/nagios/cgi-bin/status.cgi?host=${NAGIOS_HOSTNAME}|See Nagios>\"}" ${WEBHOOK_URL}

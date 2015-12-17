zabbix_remote_acknowledged
=======================

# DESCRIPTION
This tool will add an event acceptance function from the remote to Zabbix.
Also, in cooperation event information to Slack, do the time line manage .

# Requirements
* Zabbix2.4


# USAGE

### Zabbix Server

````
　cp zabbix-slack-alertscript.sh /usr/lib/zabbix/alertscripts/
　chmod 755 zabbix-slack-alertscript.sh
````

* Please change to suit your environment.

````
  vi zabbix-slack-alertscript.sh
````

### Postfix Server

````
　mkdir /opt/zabbix-alert-script
　cp -r lib/ /opt/zabbix-alert-script/
  cp zabbix_event_accept.pl /opt/zabbix-alert-script/
  cp zabbix_event_check.pl /opt/zabbix-alert-script/
　cp zabbix_event_cron /etc/cron.d/
````
* Please change to suit your environment.

````
　vi zabbix_event_accept.pl
  vi zabbix_event_check.pl
  vi lib/SlackAPI.pm
````

# Zabbix WebGUI Setting

### Configuration => Actions
* Name：#Slack
　Operations
　　/usr/lib/zabbix/alertscripts/zabbix-slack-alertscript.sh "{TRIGGER.STATUS}" "{TRIGGER.NSEVERITY}" "{EVENT.DATE}  {EVENT.TIME}" "{TRIGGER.SEVERITY}" "{HOST.NAME1}" "{TRIGGER.NAME}:{ITEM.NAME1}" "({HOST.NAME1}:{ITEM.KEY1}): {ITEM.VALUE1}" "{ITEM.ID}"

* Name：#Slack[log]
　　/usr/lib/zabbix/alertscripts/zabbix-slack-alertscript.sh "{TRIGGER.STATUS}" "{TRIGGER.NSEVERITY}" "{EVENT.DATE}  {EVENT.TIME}" "{TRIGGER.SEVERITY}" "{HOST.NAME1}" "{TRIGGER.NAME}:{ITEM.NAME1}" "({HOST.NAME1}:{ITEM.KEY1}): {ITEM.VALUE1}"
　　
** Since the log system does not need graph {ITEM.ID} is not attached to the argument. **



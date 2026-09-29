#!/bin/sh
set -eu
api='http://zabbix-web:8080/api_jsonrpc.php'
host_name='GUA-LAB-AGENT-001'
group_name='GIOP-LAB Targets'
monitor_key='net.tcp.service[http,gua-lab-srv-web-001,80]'
trigger_name='GIOP-LAB: controlled web workload TCP unavailable'
call_api() {
  method="$1"; params="$2"; auth="${3:-null}"
  curl -fsS -H 'Content-Type: application/json-rpc' --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"auth\":$auth,\"id\":1}" "$api"
}
token_of() { sed -n 's/.*"result":"\([^"]*\)".*/\1/p'; }
id_of() { sed -n 's/.*"\(hostid\|groupid\)":"\([0-9]*\)".*/\2/p'; }
echo 'Waiting for Zabbix web API...'
attempt=0
until call_api apiinfo.version '[]' >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 61 ] || exit 1; sleep 5
done
login=$(call_api user.login '{"username":"Admin","password":"zabbix"}' || true)
token=$(printf '%s' "$login" | token_of)
if [ -n "$token" ]; then
  update=$(call_api user.update "{\"userid\":\"1\",\"passwd\":\"$ZABBIX_ADMIN_PASSWORD\",\"current_passwd\":\"zabbix\"}" "\"$token\"")
  printf '%s' "$update" | grep -q '"userids"' || { echo "Zabbix password update failed: $update" >&2; exit 1; }
fi
login=$(call_api user.login "{\"username\":\"Admin\",\"password\":\"$ZABBIX_ADMIN_PASSWORD\"}")
token=$(printf '%s' "$login" | token_of)
[ -n "$token" ] || { echo "Zabbix authentication failed: $login" >&2; exit 1; }
# Remove the obsolete synthetic-only item/trigger created by early v0.1 previews.
legacy_trigger=$(call_api trigger.get '{"filter":{"description":["GIOP-LAB: controlled web workload unavailable"]}}' "\"$token\"")
legacy_triggerid=$(printf '%s' "$legacy_trigger" | sed -n 's/.*"triggerid":"\([0-9]*\)".*/\1/p')
if [ -n "$legacy_triggerid" ]; then
  call_api trigger.delete "[\"$legacy_triggerid\"]" "\"$token\"" >/dev/null
fi
legacy_item=$(call_api item.get '{"filter":{"key_":["lab.web.status"]}}' "\"$token\"")
legacy_itemid=$(printf '%s' "$legacy_item" | sed -n 's/.*"itemid":"\([0-9]*\)".*/\1/p')
if [ -n "$legacy_itemid" ]; then
  call_api item.delete "[\"$legacy_itemid\"]" "\"$token\"" >/dev/null
fi
group=$(call_api hostgroup.get "{\"filter\":{\"name\":[\"$group_name\"]}}" "\"$token\"")
groupid=$(printf '%s' "$group" | id_of)
if [ -z "$groupid" ]; then
  group=$(call_api hostgroup.create "{\"name\":\"$group_name\"}" "\"$token\"")
  groupid=$(printf '%s' "$group" | sed -n 's/.*"groupids":\["\([0-9]*\)"\].*/\1/p')
fi
host=$(call_api host.get "{\"filter\":{\"host\":[\"$host_name\"]}}" "\"$token\"")
hostid=$(printf '%s' "$host" | id_of)
if [ -z "$hostid" ]; then
  created=$(call_api host.create "{\"host\":\"$host_name\",\"name\":\"GUA-LAB-SRV-WEB-001 synthetic monitor\",\"groups\":[{\"groupid\":\"$groupid\"}],\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":0,\"ip\":\"127.0.0.1\",\"dns\":\"zabbix-agent2\",\"port\":\"10050\"}]}" "\"$token\"")
  hostid=$(printf '%s' "$created" | sed -n 's/.*"hostids":\["\([0-9]*\)"\].*/\1/p')
fi
item=$(call_api item.get "{\"hostids\":[\"$hostid\"],\"filter\":{\"key_\":[\"$monitor_key\"]}}" "\"$token\"")
if ! printf '%s' "$item" | grep -q '"itemid"'; then
  created=$(call_api item.create "{\"name\":\"Synthetic web workload TCP reachability\",\"key_\":\"$monitor_key\",\"hostid\":\"$hostid\",\"type\":3,\"value_type\":3,\"delay\":\"15s\"}" "\"$token\"")
  printf '%s' "$created" | grep -q '"itemids"' || { echo "Zabbix item creation failed: $created" >&2; exit 1; }
fi
trigger=$(call_api trigger.get "{\"filter\":{\"description\":[\"$trigger_name\"]}}" "\"$token\"")
if ! printf '%s' "$trigger" | grep -q '"triggerid"'; then
  created=$(call_api trigger.create "{\"description\":\"$trigger_name\",\"expression\":\"last(/$host_name/$monitor_key)=0\",\"priority\":3}" "\"$token\"")
  printf '%s' "$created" | grep -q '"triggerids"' || { echo "Zabbix trigger creation failed: $created" >&2; exit 1; }
fi
echo 'Zabbix synthetic target, item, and trigger are ready.'

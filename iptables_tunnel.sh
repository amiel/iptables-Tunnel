#!/bin/bash

IPTABLES="/sbin/iptables"


source functions.sh

get_port() {
	case $2 in
		backup) echo $[$1 + 5000] ;;
		*) echo $[$1 + 5500] ;;
	esac
}

add_server() {
	local ip=${1:?please supply a server} port=${2:?please supply a port}
	ebegin "setting up local $port to forward to $ip:$DESTINATION_PORT"
	$IPTABLES -t nat -A OUTPUT -p tcp --dport $port -j DNAT --to-destination $ip
	eend $?
}


remove_server() {
	local ip=${1:?please supply a server} port=${2:?please supply a port}
	ebegin "removing local $port forward to $ip:$DESTINATION_PORT"
	$IPTABLES -t nat -D OUTPUT -p tcp --dport $port -j DNAT --to-destination $ip
	eend $?
}


case $1 in
	add)
		add_server $3 $(get_port $2)
		add_server $3 $(get_port $2 backup)
		;;
	remove)
		remove_server $3 $(get_port $2)
		ebegin "waiting 10 seconds for server to finish handling requests"
		sleep 10
		eend 0
		remove_server $3 $(get_port $2 backup)
		;;
	*) eerror invalid action; exit 3 ;;
esac



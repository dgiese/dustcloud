#!/bin/bash
if [[ -f /mnt/data/valetudo ]]; then
#	iptables         -F OUTPUT
#	ip6tables        -F OUTPUT
#	iptables  -t nat -F OUTPUT
#	iptables  -t nat -A OUTPUT -p tcp --dport 80   -d 203.0.113.1 -j DNAT --to-destination 127.0.0.1:8053
#	iptables  -t nat -A OUTPUT -p udp --dport 8053 -j DNAT --to-destination 127.0.0.1:8053
#	iptables         -A OUTPUT                     -d 203.0.113.1/32  -j REJECT
#	ip6tables        -A OUTPUT                     -d 2001:db8::1/128 -j DROP
	ip addr add 203.0.113.1 dev lo
	VALETUDO_CONFIG_PATH=/mnt/data/valetudo_config.json /mnt/data/valetudo >> /tmp/valetudo.log 2>&1 &
fi
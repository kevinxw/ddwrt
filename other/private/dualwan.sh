#!/bin/sh

# ���� 10.24.2.19 �� 10.24.3.251 ��ͬһ�����ڣ������������ؾ���ʱֻ�ܾ���һ��·(��Ҫ���ݳ��ںͽ���mark)
# ����UDP����ֱ�ӽ��а����أ��������ֶ�ľ��- -

cat > $AUTOLOADER_PATH/script/firewall/dualwan.script << EOF
i=0
ROUT='ip route replace default scope global equalize'
# ��WRT54G2��TCP������
for WAN in \`nvram get wan_gateway\` 10.24.3.251 ; do
	let i++
	let TBL=\$i*10+100
	ip route add default via \$WAN table \$TBL
	ip route | grep link | while read ROUTE ; do
		ip route add table \$TBL to \$ROUTE
	done
	if [ \`ip rule | grep "lookup \$TBL" | wc -l\` -lt 1 ]; then
		ip rule add fwmark \$TBL table \$TBL prio \$TBL
	fi
	ip route flush table \$TBL
	ROUT="\$ROUT nexthop via \$WAN"
done
\$ROUT

# ��������·���ӵ�table160��ȥ
ip route replace default scope global equalize table 160 nexthop via \`nvram get wan_gateway\` nexthop via 10.24.3.251 nexthop via 10.24.2.19

iptables -A PREROUTING -t mangle -i br1 -j IMQ --todev 0
iptables -A PREROUTING -t mangle -i br1 -j SVQOS_IN
iptables -A POSTROUTING -t mangle -o br1 -j SVQOS_OUT

# ���ݽ����ڱ�ǣ�������У��·��Ҳ���Ա�ǣ���Ϊ10.24.3.251����·��
iptables -t mangle -A PREROUTING -i ppp0 -m conntrack --ctstate NEW -j CONNMARK --set-mark 110
iptables -t mangle -A PREROUTING -i br1 -m conntrack --ctstate NEW -j CONNMARK --set-mark 120
iptables -t mangle -A POSTROUTING -o ppp0 -m conntrack --ctstate NEW -j CONNMARK --set-mark 110
iptables -t mangle -A POSTROUTING -o br1 -m conntrack --ctstate NEW -j CONNMARK --set-mark 120

# ��53�˿��ر𱣻�һ�£�����dns�ٳ֣�Ҳ����OpenVPNʹ����53�˿�
iptables -t mangle -A PREROUTING -p udp ! --dport 53 -m mark --mark 0 -j MARK --set-mark 160
# Punish
iptables -t mangle -A PREROUTING -s 10.219.219.248/29 -j MARK --set-mark 120

# ԭ���Ǹ���br0 mark�������������
iptables -t mangle -A PREROUTING -s 10.24.6.254 -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -s 10.219.219.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark
iptables -t mangle -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

iptables -t mangle -D SVQOS_OUT -j CONNMARK --restore-mark 2> /dev/null
EOF

sh $AUTOLOADER_PATH/script/firewall/dualwan.script &
sleep 5; rm -f $0 &
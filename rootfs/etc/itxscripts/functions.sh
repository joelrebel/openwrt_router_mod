#!/bin/bash
#ned 
#set -x

# Timestamp needs to be added for each logline
powerresume_flag_check() {
		

		if [ -f $POWERON_FLAG ]; ## Many times I need to power off/on the box asap .. this helps
		then
			POWERRESUME_FLAG_COUNT=$POWERRESUME_FLAG_MAXCOUNT
			rm -f $POWERON_FLAG
		fi	

		if [[ $POWERRESUME_FLAG_COUNT -lt $POWERRESUME_FLAG_MAXCOUNT ]];		
		then
			POWERRESUME_FLAG_COUNT=$(( $POWERRESUME_FLAG_COUNT + 1 ))
			return $POWERRESUME_FLAG_COUNT #max count not yet reached
	
		elif [[ $POWERRESUME_FLAG_COUNT -eq $POWERRESUME_FLAG_MAXCOUNT ]]; #12 * LOOP_INTERVAL = 60 secs/ 1min 
		then
			return 0 #max count reached
			
		fi
}

powercut_flag_check() {
	
		
		if [ -f $POWEROFF_FLAG ]; ## Many times I need to power off/on the box asap .. this helps
		then
			POWERCUT_FLAG_COUNT=$POWERCUT_FLAG_MAXCOUNT
			rm -f $POWEROFF_FLAG
		fi	

		if [[ $POWERCUT_FLAG_COUNT -lt $POWERCUT_FLAG_MAXCOUNT ]];		
		then
			POWERCUT_FLAG_COUNT=$(( $POWERCUT_FLAG_COUNT + 1 ))
			return $POWERCUT_FLAG_COUNT #max count not yet reached
		
		elif [[ $POWERCUT_FLAG_COUNT -eq $POWERCUT_FLAG_MAXCOUNT ]]; #12 * LOOP_INTERVAL = 60 secs/ 1min 
		then
			return 0 #max count reached

			
		fi

}

checkrun_homeserver_ppp() {
	if [ ! $PPP_PID ];
	then
		logline info "->running pppoe start on homeserver<-"
		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP} -p2222 "pidof pppd >/tmp/pppoe.pid"
		/usr/bin/scp -P2222 -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP}:/tmp/pppoe.pid /tmp/pppoe.pid
		PPP_PID=$(cat /tmp/pppoe.pid)

		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP} -p2222 "nohup /usr/sbin/pppoe-start"

	else 
		logline info "pppd active at $PPP_PID on ${HOMESERVER_IP}"
	fi	
}


#power_off_server() {
#        echo 1 >/proc/diag/led/ses
#        sleep 5
#        echo 0 >/proc/diag/led/ses

#}
	
turn_homeserver_on() {

	if [ "$1" == "powerswitch" ];
	then
	        echo 1 >/proc/diag/led/bridge #light up bridge led to indicate we're attempting to power up the server  
        	echo 1 >/proc/diag/led/ses
        	sleep 1
        	echo 0 >/proc/diag/led/ses
        	echo 0 >/proc/diag/led/bridge
	else
		logline info "Running /usr/bin/wol on $HOMESERVER_IP"
		/usr/bin/wol -i 192.168.69.255 $HOMESERVER_MAC
		/usr/bin/wol -i 192.168.69.255 $FLOATING_MAC # needed since sometimes box goes down with this mac

		WOL_SENT_COUNT=$(( $WOL_SENT_COUNT + 1 ))
		logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, WOL_SENT_COUNT -> $WOL_SENT_COUNT"
	fi	
}

turn_homeserver_off() {
	logline info "->turn_homeserver_off<-"
	PPP_PID=''
	/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP} -p2222 "/opt/server_scripts/do_suspend.sh" &
}

#confusing name for the fucntion :s

turn_homeserver_normal() {
	logline info "->turn_homeserver_normal<-"
	PPP_PID=''
	/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP} -p2222 "/usr/sbin/pppoe-stop; \
										ifconfig $HOMESERVER_GATEWAY_INTF 0.0.0.0 down; \
										ifconfig $HOMESERVER_GATEWAY_INTF hw ether $HOMESERVER_MAC; \
										ifconfig $HOMESERVER_SECONDARY_INTF $HOMESERVER_IP down; \
										ifconfig $HOMESERVER_GATEWAY_INTF $HOMESERVER_IP up"
	if [ "$1" == "poweroff" ];
	then
		turn_homeserver_off
	fi	
}

turn_homeserver_gateway() {
	if [ "$MY_STATUS" == "GATEWAY" ];
	then
		logline error "WTF MY_STATUS -> $MY_STATUS, im not letting a splitbrain!" 
	else 
		logline info "->turn_homeserver_gateway<-"
		PPP_PID=''
		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP} -p2222 "ifconfig $HOMESERVER_GATEWAY_INTF 0.0.0.0 down; \
											ifconfig $HOMESERVER_GATEWAY_INTF hw ether $FLOATING_MAC; \
											ifconfig $HOMESERVER_GATEWAY_INTF $GATEWAY_IP up; \
											ifconfig $HOMESERVER_SECONDARY_INTF $HOMESERVER_IP up"
		sleep 5
		checkrun_homeserver_ppp
	fi	
}

#IPs are swapped between interfaces
#br-lan turns 192.168.69.1
#br-lan:1 turns 192.168.69.4
check_run_pppd() {

	PPID=$(pidof pppd)
	if [ ! $PPID ];
	then	

		logline into "->pppd connect<-"
	 	/usr/sbin/pppd plugin rp-pppoe.so $MY_GATEWAY_INTF noipdefault noauth default-asyncmap defaultroute hide-password nodetach mtu 1492 mru 1492 noaccomp nodeflate nopcomp novj novjccomp user $PPP_USER password $PPP_PASS lcp-echo-interval 20 lcp-echo-failure 3 maxfail 10 logfile /etc/itxscripts/pppd.log debug &
	
	fi

}

mod_bridge_intf() {
	#bridge interfaces can swap macs (and work fine) only with the macs on the bridged interfaces.	
	if [ "$1" == 'del_bridge' ];
	then
		ifconfig ${MY_LAN_INTF}.0 down
		ifconfig $MY_LAN_INTF down
		ifconfig $MY_WIFI_INTF down
		ifconfig $MY_GATEWAY_INTF down
		brctl delif $MY_GATEWAY_INTF ${MY_LAN_INTF}.0
		brctl delif $MY_GATEWAY_INTF $MY_WIFI_INTF
		brctl delbr $MY_GATEWAY_INTF
	fi
	
	if [ "$1" == 'add_bridge' ];
	then
		
		ifconfig ${MY_LAN_INTF}.0 up
		ifconfig $MY_LAN_INTF up
		ifconfig $MY_WIFI_INTF up
		brctl addbr $MY_GATEWAY_INTF
		brctl addif $MY_GATEWAY_INTF ${MY_LAN_INTF}.0
		brctl addif $MY_GATEWAY_INTF $MY_WIFI_INTF
		ifconfig $MY_GATEWAY_INTF up

	fi
	
	if [ "$1" == 'swap_hwaddr' ]; ##needs to be passed a mac addr to swap with
	then
	
		mod_bridge_intf del_bridge
		ifconfig ${MY_LAN_INTF}.0 hw ether $2
		mod_bridge_intf add_bridge
		ifconfig ${MY_GATEWAY_INTF} hw ether $2
		sleep 10
	fi

}

turn_self_gateway() { 

	logline info "->turn_self_gateway<-"
	ifconfig $MY_GATEWAY_INTF 0.0.0.0 down
	mod_bridge_intf swap_hwaddr $FLOATING_MAC
	ifconfig $MY_GATEWAY_INTF $GATEWAY_IP up
	ifconfig $MY_SECONDARY_INTF $MY_IP up
	check_run_pppd

	echo -e 'nameserver 208.67.220.220\nnameserver 8.8.8.8' >/etc/resolv.conf	
		
	/usr/sbin/iptables -t nat -A POSTROUTING -o ppp0 -s 192.168.69.98 -j MASQUERADE
	/usr/sbin/iptables -t nat -A POSTROUTING -o ppp0 -s 192.168.69.66 -j MASQUERADE
	/usr/sbin/iptables -t nat -A POSTROUTING -o ppp0 -s 192.168.69.88 -j MASQUERADE

	/usr/sbin/iptables -I zone_lan_REJECT -s 192.168.69.98 -j ACCEPT
	/usr/sbin/iptables -I zone_lan_REJECT -s 192.168.69.66 -j ACCEPT
	/usr/sbin/iptables -I zone_lan_REJECT -s 192.168.69.88 -j ACCEPT

}



turn_self_normal() {
	
	logline info "->turn_self_normal<-"
	MYPPP_PID=$(pidof pppd)
	if [ $MYPPP_PID ];
	then
		kill -s SIGTERM $MYPPP_PID
	fi
	ifconfig $MY_GATEWAY_INTF 0.0.0.0 down
	ifconfig $MY_SECONDARY_INTF $MY_IP down
	mod_bridge_intf swap_hwaddr $MY_MAC
	ifconfig $MY_GATEWAY_INTF $MY_IP up



	/usr/sbin/iptables -t nat -D POSTROUTING -o ppp0 -s 192.168.69.98 -j MASQUERADE
	/usr/sbin/iptables -t nat -D POSTROUTING -o ppp0 -s 192.168.69.66 -j MASQUERADE
	/usr/sbin/iptables -t nat -D POSTROUTING -o ppp0 -s 192.168.69.88 -j MASQUERADE


	/usr/sbin/iptables -D zone_lan_REJECT -s 192.168.69.98 -j ACCEPT
	/usr/sbin/iptables -D zone_lan_REJECT -s 192.168.69.66 -j ACCEPT
	/usr/sbin/iptables -D zone_lan_REJECT -s 192.168.69.88 -j ACCEPT
}

check_my_uptime() {
	
	UPTIME=$(cat /proc/uptime | awk -F . '{print $1}');
	if [[ $UPTIME -gt 172800 ]];
	then
		/sbin/reboot
	fi
}

check_mystatus() {
	
	MY_CURRENT_IP=$(ifconfig $MY_GATEWAY_INTF | awk -F ':' '/inet addr/{print $2}' | sed -e 's/  Bcast//g')
	logline info  "MY_CURRENT_IP -> $MY_CURRENT_IP, MY_IP -> $MY_IP" 
	if [ "$MY_CURRENT_IP" ==  "$MY_IP" ];
	then
		MY_STATUS=NORMAL
		return 3

	elif [ "$MY_CURRENT_IP" ==  "$GATEWAY_IP" ];
	then
		MY_STATUS=GATEWAY
		return 2
	fi
}


poll_gpio() {

 POWER_STATUS=$(cat /proc/diag/button/ses)
 if [[ $POWER_STATUS -eq 0 ]];
 then
	DIAG_LED=$(cat /proc/diag/led/diag)
 	if [[ $DIAG_LED -eq 1 ]];
	then
		echo 0 >/proc/diag/led/diag
		logline info "POWER_STATUS=ON"
	fi
 	POWER_STATUS=ON
	return 0

 elif [[ $POWER_STATUS -eq 1 ]];
 then	
 	DIAG_LED=$(cat /proc/diag/led/diag)
 	if [[ $DIAG_LED -eq 0 ]];
	then
		echo 1 >/proc/diag/led/diag
		logline info "POWER_STATUS=OFF"
	fi	
 	POWER_STATUS=OFF
	return 1
 fi	
 
  	 
}

ping_check() {

	PING_COUNT=0
	TO_PING=$1
	COUNT=0

	while [[ $COUNT -ne 5 ]]
	do	
		/usr/bin/arping -c1 $TO_PING -w2 -I $MY_GATEWAY_INTF &>/dev/null
		if [[ $? -eq 0 ]];
		then
	     		PING_COUNT=$(( PING_COUNT + 1 ))
		fi

		COUNT=$(( $COUNT + 1 ))	
	done	

	if [[ $PING_COUNT -ge 3 ]];
	then	
		STATUS=UP
		logline info "$TO_PING -> reachable"
		return 0 #$1 reachable
	else
		STATUS=DOWN
		logline info "$TO_PING -> UNreachable"
		return 1 #$1 unreachable
	fi	
}

logline() { 
	if [[ $LOG_LEVEL -eq "0" ]];
	then
		if [ "$1" == "error" ];
		then
			echo "error: $2" >> $LOG_FILE
		fi
	fi
	
	if [[ $LOG_LEVEL -eq "1" ]];
	then	
		if [ "$1" == "info" ];
		then	
			echo "info: $2"  >> $LOG_FILE
		elif [ "$1" == "error" ];
		then
			echo "error: $2"  >> $LOG_FILE
		fi
	fi
	
	if [[ $LOG_LEVEL -eq "2" ]];
	then
		if [ "$1" == "info" ];
		then
			echo "info: $2"  >> $LOG_FILE
		elif [ "$1" == "error" ];
		then
			echo "error: $2"  >> $LOG_FILE
		elif [ "$1" == "debug" ];
		then
			echo "debug: $2" >> $LOG_FILE
		fi
	fi	
}



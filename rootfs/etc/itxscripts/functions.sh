#!/bin/bash
#ned 
set -x

# function must be called with  log_line [debug|error] "some message here"
# Timestamp needs to be added for each logline
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
		if   [ "$1" == "debug" ]; 
		then
			echo "debug: $2"  >> $LOG_FILE
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

powerresume_flag_check() {
		
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
		if [[ $POWERCUT_FLAG_COUNT -lt $POWERCUT_FLAG_MAXCOUNT ]];		
		then
			POWERCUT_FLAG_COUNT=$(( $POWERCUT_FLAG_COUNT + 1 ))
			return $POWERCUT_FLAG_COUNT #max count not yet reached
	
		elif [[ $POWERCUT_FLAG_COUNT -eq $POWERCUT_FLAG_MAXCOUNT ]]; #12 * LOOP_INTERVAL = 60 secs/ 1min 
		then
			return 0 #max count reached
			
		fi

}

checkrun_atom_ppp() {
	if [ ! $PPP_PID ];
	then
		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222 "pidof pppd >/tmp/pppoe.pid"
		/usr/bin/scp -P2222 -i /etc/itxscripts/id_rsa root@${ATOM_IP}:/tmp/pppoe.pid /tmp/pppoe.pid
		PPP_PID=$(cat /tmp/pppoe.pid)

		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222 "nohup /usr/sbin/pppoe-start"

	else 
		echo "pppd active at $PPP_PID on ${ATOM_IP}"
	fi	
}
turn_atom_off() {
	PPP_PID=''
	/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222 "/sbin/halt"
}

#confusing name for the fucntion :s

turn_atom_normal() {
	PPP_PID=''
	/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222 "/usr/sbin/pppoe-stop; ifconfig $ATOM_GATEWAY_INTF down"
	/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222  "/sbin/iptables -F;/sbin/iptables -t nat -F;/sbin/iptables -t mangle -F"
	if [ "$1" == "poweroff" ];
	then
		turn_atom_off
	fi	
}

turn_atom_gateway() {
	if [ "$MY_STATUS" == "GATEWAY" ];
	then
		echo "WTF MY_STATUS -> $MY_STATUS, im not letting a splitbrain!" 
	else 
		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222 "ifconfig $ATOM_GATEWAY_INTF $GATEWAY_IP;"
		/usr/bin/ssh -y -i /etc/itxscripts/id_rsa root@${ATOM_IP} -p2222  "/bin/bash /opt/server_scripts/iptables"
		checkrun_atom_ppp
	fi	
}

#IPs are swapped between interfaces
#br-lan turns 192.168.0.1
#br-lan:1 turns 192.168.0.4
turn_self_gateway() { 
	echo "->turn_self_gateway<-"

	ifconfig $MY_GATEWAY_INTF $GATEWAY_IP up
	ifconfig $MY_SECONDARY_INTF $MY_IP up

	>/etc/itxscripts/pppd.log
	/usr/sbin/pppd plugin rp-pppoe.so br-lan noipdefault noauth default-asyncmap defaultroute hide-password nodetach mtu 1492 mru 1492 noaccomp nodeflate nopcomp novj novjccomp user slrebello password sallu199 lcp-echo-interval 20 lcp-echo-failure 3 maxfail 10 logfile /etc/itxscripts/pppd.log debug &
	echo -e 'nameserver 208.67.220.220\nnameserver 8.8.8.8' >/etc/resolv.conf	
	/usr/sbin/iptables -t nat -A POSTROUTING -o ppp0 -s 192.168.0.98 -j MASQUERADE

}

turn_self_normal() {
	
	echo "->turn_self_normal<-"
	MYPPP_PID=$(pidof pppd)
	if [ $MYPPP_PID ];
	then
		kill -s SIGTERM $MYPPP_PID
	fi
	ifconfig $MY_GATEWAY_INTF $MY_IP up
	ifconfig  $MY_SECONDARY_INTF down
	/usr/sbin/iptables -t nat -D POSTROUTING -o ppp0 -s 192.168.0.98 -j MASQUERADE
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
	fi
 	POWER_STATUS=ON
	return 0

 elif [[ $POWER_STATUS -eq 1 ]];
 then	
 	DIAG_LED=$(cat /proc/diag/led/diag)
 	if [[ $DIAG_LED -eq 0 ]];
	then
		echo 1 >/proc/diag/led/diag
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
		/usr/bin/arping -c1 $TO_PING -w2 -I $MY_GATEWAY_INTF
		# returns 1 if sucess,
		# returns 0 if fail
		
		if [[ $? -eq 0 ]];
		then
	     		PING_COUNT=$(( PING_COUNT + 1 ))
		fi

		COUNT=$(( $COUNT + 1 ))	
	done	

	if [[ $PING_COUNT -ge 3 ]];
	then	
		STATUS=UP
		return 0 #$1 reachable
	else
		STATUS=DOWN	
		return 1 #$1 unreachable
	fi	
}

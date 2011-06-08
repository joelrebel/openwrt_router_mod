#!/bin/sh

#set -x
#router should be hooked to the invertor
#GPIO input pin should be hooked to a high when theres power.
#GPIO input pin should be monitored for powercuts..
#
#
#                            
#1) Power resumed/ Powered up
#                                            
#       1) boot using normal ip (192.168.69.4)                            
#       2) check if homeserver server is up - ping alternate ip (192.168.69.110)
#               if down                 
#                       bind 192.168.69.1            
#                       start homeserver_boot_timer script
#                       send /usr/bin/wol end of timer script
#            
#2) Power cut                                                      
#       1) check if homeserver server is up, run halt on the server if up
#       3) turn self into gateway
#
#router will have secondary ip with  br-lan:1 
#TOFIX - POWERRESUME_FLAG_COUNT needs to be reset at proper times

export HOME=/root #added for dropbears scp

rm -f /etc/itxscripts/pppd.log
LOG_LEVEL='0' 
LOG_FILE=/etc/itxscripts/gateway_controller.log
> $LOG_FILE
# 0 - error logs only
# 1 - error + info logs
# 2 - error  + info  + debug logs
LOOP_INTERVAL=5 # in seconds
WOL_SENT_COUNT=0;

GATEWAY_IP='192.168.69.1'
FLOATING_MAC='00:66:de:ad:be:ef'

PPP_USER='joelr'
PPP_PASS='instanet'
MY_MAC='00:16:01:92:0A:90'
MY_IP='192.168.69.4'
MY_GATEWAY_INTF='br-lan' #brwlan
MY_SECONDARY_INTF='br-lan:1' #swaps ips with gateway




HOMESERVER_MAC="1c:6f:65:92:70:0b"
HOMESERVER_IP='192.168.69.110'
HOMESERVER_GATEWAY_INTF='eth0'
HOMESERVER_SECONDARY_INTF='eth0:1'



POWERCUT_FLAG_COUNT=0;
POWERCUT_FLAG_MAXCOUNT=36; #36 -default $POWERCUT_FLAG_COUNT * LOOP_INTERVAL = number of seconds the script would wait to take action on the router..
			   # once the script hits maxcount, we run halt	

POWERRESUME_FLAG_COUNT=0;
POWERRESUME_FLAG_MAXCOUNT=60; #60 -default

MY_STATUS='UNKOWN'
HOMESERVER_STATUS='UNKOWN'
POWER_STATUS='UNKOWN'
GATEWAY_STATUS='UNKOWN'
. /etc/itxscripts/functions.sh
mkdir -p /root/.ssh/
cp  /etc/itxscripts/known_hosts /root/.ssh/

while [[ 1 ]];
do	
	check_my_uptime	
	check_mystatus #returns NORMAL|GATEWAY
	logline debug "MY_STATUS-> $MY_STATUS"
	if [ "$MY_STATUS" == "NORMAL" ];
	then
		ping_check $GATEWAY_IP
		if [ "$STATUS" == "DOWN" ];
		then
			GATEWAY_STATUS=DOWN
		elif [ "$STATUS" == "UP" ];
		then
			GATEWAY_STATUS=UP
		fi	

	elif [ "$MY_STATUS" == "GATEWAY" ];
	then
		GATEWAY_STATUS=UP
	fi
	
	ping_check $HOMESERVER_IP
	if [ "$STATUS" == "DOWN" ];
	then
		HOMESERVER_STATUS=DOWN
	elif [ "$STATUS" == "UP" ];
	then
		HOMESERVER_STATUS=UP
	fi

	poll_gpio
	if [ "$POWER_STATUS" == "ON" ]; #GPIO indicates power is ON
	then	
		logline info "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
		powerresume_flag_check
		POWERCUT_FLAG_COUNT=0; # since power is present, resetting flag to 0	
		
		if [ "$MY_STATUS" == "NORMAL" ]; # Router isnt the gateway and power is present we need to ensure homeserver is gateway
		then
			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS "
		
			if [ "$HOMESERVER_STATUS" == "DOWN" ]; # HOMESERVER_IP is down, server down
			then
				logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
		
				if [ "$GATEWAY_STATUS" == "DOWN" ]; # NO one is using the gateway IP
				then
					logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS"
		
					if [[ $POWERRESUME_FLAG_COUNT -eq $POWERRESUME_FLAG_MAXCOUNT ]];
					then	
	 					POWERRESUME_FLAG_COUNT=0
						logline info "Running /usr/bin/wol on $HOMESERVER_IP"
						/usr/bin/wol -i 192.168.69.255 $HOMESERVER_MAC
						WOL_SENT_COUNT=$(( $WOL_SENT_COUNT + 1 ))
						logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, WOL_SENT_COUNT -> $WOL_SENT_COUNT"
						if [[ $WOL_SENT_COUNT -eq 15 ]];
						then
							logline error "WOL_SENT_COUNT -> 15, something wrong with the HOMESERVER Server??"
						fi
					else
						logline debug "wol skipped, POWERRESUME_FLAG_COUNT - $POWERRESUME_FLAG_COUNT needs to hit $POWERRESUME_FLAG_MAXCOUNT"
						turn_self_gateway
				
	 		   		fi ##	 if [[ $POWERRESUME_FLAG_COUNT -eq $POWERRESUME_FLAG_MAXCOUNT ]];

				elif [ "$GATEWAY_STATUS" == "UP" ]; # unkown on gateway ip
				then
					logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MYSTATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS - but GATEWAY_STATUS -> $GATEWAY_STATUS :S"
				fi #end if [ "$HOMESERVER_STATUS" == "DOWN" ];
		 	elif [ "$HOMESERVER_STATUS" == "UP" ]; #HOMESERVER_IP reachable, ensure homeserver is the gateway - 
			then	
		 		logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
			
				if [ "$GATEWAY_STATUS" == "UP" ]; # 
		        	then
                               		logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS"
					#Hit two bugs at this point 
					#- piping|redirecting  dropbear ssh output just doesnt work in non-interactive env
					#- dropbear scp doesnt seem to honour ssh options like scp -P2222 -oStrictHostKeyChecking=no   root@192.168.69.133:/tmp/test1234 .
					#- hence doing the below :s
					/usr/bin/ssh -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP} -p2222 "ifconfig $HOMESERVER_GATEWAY_INTF >/tmp/intf"
					/usr/bin/scp -P2222 -i /etc/itxscripts/id_rsa root@${HOMESERVER_IP}:/tmp/intf /tmp/intf
					TEMP=$(cat /tmp/intf | awk -F ':' '/inet addr/{print $2}' | sed -e 's/  Bcast//g' )	
			
					if [ "$TEMP" == "$GATEWAY_IP" ];
			 		then
			 			logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, HOMESERVER is GATEWAY \0/"
						checkrun_homeserver_ppp
					 else 
			 			logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS TEMP -> $TEMP, HOMESERVER is NOT the GATEWAY :S"
				 	fi
		        
				elif [ "$GATEWAY_STATUS" == "DOWN" ];
		 		then
					logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, Turning homeserver into gateway .."
					turn_homeserver_gateway
				fi
			
			fi #end HOMESERVER_STATUS UP
		elif [ "$MY_STATUS" == "GATEWAY" ]; #Power is present, router is the gateway - we need to check and turn homeserver into the gateway
		then	
			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS"
		
			if [ "$HOMESERVER_STATUS" == "DOWN" ]; # HOMESERVER_IP is down, 
			then
				logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
		
				if [[ $POWERRESUME_FLAG_COUNT -eq $POWERRESUME_FLAG_MAXCOUNT ]];
				then	
					POWERRESUME_FLAG_COUNT=0		
					logline debug "Running /usr/bin/wol on $HOMESERVER_IP"
					/usr/bin/wol -i 192.168.69.255 $HOMESERVER_MAC
					WOL_SENT_COUNT=$(( $WOL_SENT_COUNT + 1 ))
					logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, WOL_SENT_COUNT -> $WOL_SENT_COUNT"
				else
					check_run_pppd
					logline info "wol skipped, POWERRESUME_FLAG_COUNT - $POWERRESUME_FLAG_COUNT needs to hit $POWERRESUME_FLAG_MAXCOUNT"
					
	 		   	fi ##	 if [[ $POWERRESUME_FLAG_COUNT -eq $POWERRESUME_FLAG_MAXCOUNT ]];
				#end HOMESERVER_STATUS DOWN
		 	elif [ "$HOMESERVER_STATUS" == "UP" ]; #HOMESERVER_IP UP, ensure homeserver is the gateway - 
			then	
				POWERRESUME_FLAG_COUNT=0
		 		logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
				turn_self_normal
				turn_homeserver_gateway
				fi #end HOMESERVER_IP reachable
			fi	
################################POWER OFF###############################################
	elif [ "$POWER_STATUS" == "OFF" ]; #GPIO indicates power is OFF
	then
		logline info "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
		powercut_flag_check
		POWERRESUME_FLAG_COUNT=0;
		
		if [ "$MY_STATUS" == "NORMAL" ]; # IM not the gateway
		then
			logline debug "POWER_STATUS -> $POWER_STATUS, POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT, MY_STATUS -> $MY_STATUS"
		
			if [ "$HOMESERVER_STATUS" == "DOWN" ]; # HOMESERVER_IP is down, server down
			then
				logline debug "POWER_STATUS -> $POWER_STATUS, POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
				
				if [ "$GATEWAY_STATUS" == "DOWN" ]; # NO one is using the gateway IP
				then
						turn_self_gateway

				elif [ "$GATEWAY_STATUS" == "UP" ]; # unkown on gateway ip
				then
					logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS,  GATEWAY_STATUS -> $GATEWAY_STATUS, :S"
				fi
	 		elif [ "$HOMESERVER_STATUS" == "UP" ]; #HOMESERVER_IP reachable, need to turn it off
	 		then	

	 			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
				if [[ $POWERCUT_FLAG_COUNT -eq $POWERCUT_FLAG_MAXCOUNT  ]]; #POWERCUT_FLAG_MAXCOUNT hit, we check homeserver, gateway - initiate turn_gateway 
				then	
					POWERCUT_FLAG_COUNT=0
					turn_homeserver_normal poweroff
					if [ "$GATEWAY_STATUS" == "UP" ]; # 
	        			then
                               			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS,  GATEWAY_STATUS -> $GATEWAY_STATUS"

					elif [ "$GATEWAY_STATUS" == "DOWN" ];
		 			then
						turn_self_gateway
					fi
				else
					logline info "POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT needs to hit $POWERCUT_FLAG_MAXCOUNT"	
					if [ "$GATEWAY_STATUS" == "DOWN" ];
                                        then
                                               turn_homeserver_gateway #homeserver can run as gateway untill its POWERCUT_FLAG_MAXCOUNT is reached
                                        fi
				fi
			fi #end HOMESERVER_IP reachable
		elif [ "$MY_STATUS" == "GATEWAY" ]; #Power is out, need to ensure homeserver is down
		then	
			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS"
			
			if [ "$HOMESERVER_STATUS" == "DOWN" ]; #  
			then
	                                check_run_pppd
					logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
	 		elif [ "$HOMESERVER_STATUS" == "UP" ]; 
			then	
		 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, HOMESERVER_STATUS -> $HOMESERVER_STATUS"
				if [[ $POWERCUT_FLAG_COUNT -eq $POWERCUT_FLAG_MAXCOUNT  ]]; #POWERCUT_FLAG_MAXCOUNT hit, we check homeserver, gateway - initiate turn_gateway 
				then
					POWERCUT_FLAG_COUNT=0
					turn_homeserver_normal poweroff
				else
					logline info "POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT needs to hit $POWERCUT_FLAG_MAXCOUNT"	
				fi	
			fi	
		fi 
fi #end elif GPIO
sleep $LOOP_INTERVAL
done #end main loop

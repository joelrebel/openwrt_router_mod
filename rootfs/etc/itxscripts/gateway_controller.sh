#!/bin/sh

set -x
#router should be hooked to the invertor
#GPIO input pin should be hooked to a high when theres power.
#GPIO input pin should be monitored for powercuts..
#
#
#                            
#1) Power resumed/ Powered up
#                                            
#       1) boot using normal ip (192.168.0.4)                            
#       2) check if atom server is up - ping alternate ip (192.168.0.110)
#               if down                 
#                       bind 192.168.0.1            
#                       start atom_boot_timer script
#                       send wol end of timer script
#            
#2) Power cut                                                      
#       1) check if atom server is up, run halt on the server if up
#       2) kill timer script.    
#       3) turn self into gateway
#
#router will have secondary ip with  br-lan:1 
#log levels are
LOG_LEVEL='2' 
# 0 - error logs only
# 1 - error + debug logs
# 2 - error + debug  + info logs
LOOP_INTERVAL=5 # in seconds
WOL_SENT_COUNT=0;
ATOM_MAC="00:1c:c0:d5:ed:60"

MY_IP='192.168.0.4'
MY_SECONDARY_IP='192.168.0.140'
MY_GATEWAY_INTF='br-lan:1' #brwlan

ATOM_IP='192.168.0.110'
ATOM_GATEWAY_INTF='eth0:1'

GATEWAY_IP='192.168.0.1'

POWERCUT_FLAG_COUNT=0;
POWERCUT_FLAG_MAXCOUNT=3; # $POWERCUT_FLAG_COUNT * LOOP_INTERVAL = number of seconds the script would wait to take action on the router..
			   # once the script hits maxcount, we run halt	

MY_STATUS='UNKOWN'
ATOM_STATUS='UNKOWN'
POWER_STATUS='UNKOWN'
GATEWAY_STATUS='UNKOWN'
. functions.sh

while [[ 1 ]];
do	
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
	
	ping_check $ATOM_IP
	if [ "$STATUS" == "DOWN" ];
	then
		ATOM_STATUS=DOWN
	elif [ "$STATUS" == "UP" ];
	then
		ATOM_STATUS=UP
	fi

	poll_gpio
	if [ "$POWER_STATUS" == "ON" ]; #GPIO indicates power is ON
	then	
		logline debug "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
		POWERCUT_FLAG_COUNT=0; # since power is present, resetting flag to 0	
		if [ "$MY_STATUS" == "NORMAL" ]; # Router isnt the gateway and power is present we need to ensure atom is gateway
		then
			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS "
		
			if [ "$ATOM_STATUS" == "DOWN" ]; # ATOM_IP is down, server down
			then
			
				logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
				if [ "$GATEWAY_STATUS" == "DOWN" ]; # NO one is using the gateway IP
				then
					logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS"
					logline info "Running wol on $ATOM_IP"

					wol -i 192.168.0.255 $ATOM_MAC
				
					WOL_SENT_COUNT=$(( $WOL_SENT_COUNT + 1 ))
					logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, WOL_SENT_COUNT -> $WOL_SENT_COUNT"
					if [[ $WOL_SENT_COUNT -eq 15 ]];
					then
						logline error "WOL_SENT_COUNT -> 15, something wrong with the ATOM Server??"
					fi	

				elif [ "$GATEWAY_STATUS" == "UP" ]; # unkown on gateway ip
				then
					logline error "ping_check returned GATEWAY_IP -> REACHABLE"
					logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MYSTATUS, ATOM_STATUS -> $ATOM_STATUS - but GATEWAY_STATUS -> $GATEWAY_STATUS :S"
					#do nothing, 
					#continue in loop
				fi

			####end ATOM_STATUS DOWN
		 	elif [ "$ATOM_STATUS" == "UP" ]; #ATOM_IP reachable, ensure atom is the gateway - 
			then	


		 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
				if [ "$GATEWAY_STATUS" == "UP" ]; # 
		        	then
                                	logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS"
				 	#wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
				 	
					TEMP=$(ssh -i id_rsa root@${ATOM_IP} -p2222 "ifconfig $ATOM_GATEWAY_INTF" | awk -F ':' '/inet addr/{print $2}' | sed -e 's/  Bcast//g' )	
				 	if [ "$TEMP" == "$GATEWAY_IP" ];
				 	then
				 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, ATOM is GATEWAY \0/"
						checkrun_atom_ppp
					 else 
				 		logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, ATOM is NOT the GATEWAY :S"
						#do nothing,
						#continue looping
				 	fi
		        	
				elif [ "$GATEWAY_STATUS" == "DOWN" ];
			 	then
			 		
					logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, Turning atom into gateway .."
					turn_atom_gateway
				fi
			
			fi #end ATOM_STATUS UP
		elif [ "$MY_STATUS" == "GATEWAY" ]; #Power is present, router is the gateway - we need to check and turn atom into the gateway
		then	
			logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS"
			if [ "$ATOM_STATUS" == "DOWN" ]; # ATOM_IP is down, 
			then
			
				logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
				logline info "Running wol on $ATOM_IP"


				wol -i 192.168.0.255 $ATOM_MAC
				WOL_SENT_COUNT=$(( $WOL_SENT_COUNT + 1 ))
				logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, WOL_SENT_COUNT -> $WOL_SENT_COUNT"
				if [[ $WOL_SENT_COUNT -eq 15 ]];
				then
					logline error "WOL_SENT_COUNT -> 15, something wrong with the ATOM Server??"
				fi	

			#end ATOM_STATUS DOWN
		 	elif [ "$ATOM_STATUS" == "UP" ]; #ATOM_IP UP, ensure atom is the gateway - 
			then	

		 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
				turn_self_normal
				turn_atom_gateway
			
			fi #end ATOM_IP reachable
		fi	


################################POWER OFF###############################################

	elif [ "$POWER_STATUS" == "OFF" ]; #GPIO indicates power is OFF
	then
		logline debug "poll_gpio returned POWER_STATUS -> $POWER_STATUS"

		powercut_flag_check
		logline info "POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT"
		if [[ $POWERCUT_FLAG_COUNT -eq $POWERCUT_FLAG_MAXCOUNT  ]]; #POWERCUT_FLAG_MAXCOUNT hit, we check atom, gateway - initiate turn_gateway 
		then
			
			if [ "$MY_STATUS" == "NORMAL" ]; # IM not the gateway
			then
				logline info "POWER_STATUS -> $POWER_STATUS, POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT, MY_STATUS -> $MY_STATUS"
			
				if [ "$ATOM_STATUS" == "DOWN" ]; # ATOM_IP is down, server down
				then
		###TBC	
					logline info "POWER_STATUS -> $POWER_STATUS, POWERCUT_FLAG_COUNT -> $POWERCUT_FLAG_COUNT, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
					if [ "$GATEWAY_STATUS" == "DOWN" ]; # NO one is using the gateway IP
					then
							#ideal position
							turn_self_gateway

					elif [ "$GATEWAY_STATUS" == "UP" ]; # unkown on gateway ip
					then

						#atom is down, Im not the gateway..
						#some one is .. 
						logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS,  GATEWAY_STATUS -> $GATEWAY_STATUS, :S"

					fi

		 		elif [ "$ATOM_STATUS" == "UP" ]; #ATOM_IP reachable, need to turn it off
		 		then	

		 			logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
				
					turn_atom_normal poweroff
				    	   
					ping_check $GATEWAY_IP
			                if [ "$STATUS" == "DOWN" ];
                			then
                        			GATEWAY_STATUS=DOWN
                			elif [ "$STATUS" == "UP" ];
                			then
                        			GATEWAY_STATUS=UP
                			fi
					
					if [ "$GATEWAY_STATUS" == "UP" ]; # 
		        		then
                                		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS,  GATEWAY_STATUS -> $GATEWAY_STATUS"
						#wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
	
					elif [ "$GATEWAY_STATUS" == "DOWN" ];
			 		then
			 			turn_self_gateway
					fi
			
				fi #end ATOM_IP reachable

			elif [ "$MY_STATUS" == "GATEWAY" ]; #Power is out, need to ensure atom is down
			then	
				logline debug "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS"
				if [ "$ATOM_STATUS" == "DOWN" ]; #  
				then
			
					logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"

		 		elif [ "$ATOM_STATUS" == "UP" ]; 
				then	

			 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
					turn_atom_normal poweroff
				fi	
			fi 

		fi # end if [[ $POWERCUT_FLAG_COUNT -eq $POWERCUT_FLAG_MAXCOUNT  ]]
#		elif [[ $POWERCUT_FLAG_COUNT -ne $POWERCUT_FLAG_MAXCOUNT ]]; #POWERCUT_FLAG_MAXCOUNT not hit, hence we just ensure someone is the gateway and continue looping
#		then
				
				
#		fi 
		
	fi #end elif GPIO

	sleep $LOOP_INTERVAL
done #end main loop



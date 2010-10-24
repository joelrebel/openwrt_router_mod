#!/bin/bash

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
LOG_LEVEL='0' 
#log levels are
# 0 - error logs only
# 1 - error + debug logs
# 2 - error + debug  + info logs
LOOP_INTERVAL=5 # in seconds
LOG_FILE='gateway_control.log'
MY_SECONDARY_IP='192.168.0.40'
ATOM_IP='192.168.0.110'
GATEWAY_IP='192.168.0.1'
MY_IP='192.168.0.4'
MY_STATUS='UNKOWN'
ATOM_STATUS='UNKOWN'
POWER_STATUS='UNKOWN'
GATEWAY_STATUS='UNKOWN'

#POWER_STATUS
#cat /proc/diag/button/ses  - < AOSS button 
# 0 = MAINS_ON
# 1 = MAINS_OFF


while [[ 1 ]];
do	
	check_mystatus #returns NORMAL|GATEWAY

	ping_check $GATEWAY_IP
	if [[ $? -eq 1 ]];
	then
		GATEWAY_STATUS=DOWN
	elif [[ $? -eq 0 ]];
	then
		GATEWAY_STATUS=UP
	fi
		
	ping_check $ATOM_IP
	if [[ $? -eq 1 ]];
	then
		ATOM_STATUS=DOWN
	elif [[ $? -eq 0 ]];
	then
		ATOM_STATUS=UP
	fi


	poll_gpio

	if [[ "$POWER_STATUS" -eq "ON" ]]; #GPIO indicates power is ON
	then	
		logline debug "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
		
		check_mystatus
		if [[ "$MYSTATUS" -eq "NORMAL"]]; # Router isnt the gateway
		then
			logline debug "check_mystatus returned MY_STATUS -> $MY_STATUS "
		
			if [[ "$ATOM_STATUS" -eq "DOWN" ]]; # ATOM_IP is down, server down
			then
			
				logline info "ping_check returned ATOM_IP -> UNREACHABLE"
				if [[ "$GATEWAY_STATUS" -eq "DOWN" ]]; # NO one is using the gateway IP
				then
					logline debug "ping_check returned GATEWAY_IP -> UNREACHABLE"
					logline info "Running boot ATOM server timer script"
					logline info "No gateway is up, changing my ip to gateway"
					#timer script runs here
					#turn_gateway called here

				elif [[ "$GATEWAY_STATUS" -eq "UP" ]]; # unkown on gateway ip
				then
					logline error "ping_check returned GATEWAY_IP -> REACHABLE"
					logline error "ATOM isnt up, neither am I the gateway - but someone is! Joel whats changed?!"
					#break out of this if fi fi fi, continue polling
				fi


		 	elif [[ "$ATOM_STATUS" -eq "UP" ]]; #ATOM_IP reachable, ensure atom is the gateway - 
			then	


		 		logline info "ping_check returned ATOM_IP -> REACHABLE"
				#kill timer scripts
				#
				if [[ "$GATEWAY_STATUS" -eq "UP" ]]; # 
		        	then
                                	logline error "ping_check returned GATEWAY_IP -> REACHABLE"
				 	#wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
				 	
					$TEMP=$(ssh $ATOM_IP -p2222 "ifconfig eth0" | awk -F ':' '/inet addr/{print $2}' | sed -e 's/Bcast//g' )	
				 	if [[ "$TEMP" -eq "$GATEWAY_IP" ]];
				 	then
				 	logline info "Atom is the gateway, continuing looping"
					#check if pppX is up, google is reachable..
				 else 
				 	logline error "Atom isnt the gateway, nor am I but someone is.. .. please check, continuing looping.."
				 fi
		        	
				elif [[ "$GATEWAY_STATUS" -eq "DOWN" ]];
			 	then
			 	
					#ssh to atomip
					# check enable gateway ip, 
					# start pppoe
				fi
			
			fi #end ATOM_IP reachable	
	
	elif [[ "$POWER_STATUS" -eq "OFF" ]]; #GPIO indicates power is OFF
	then
		logline debug "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
		check_mystatus
		if [[ $? -eq 0 ]]; # IM not the gateway
		then
			logline debug "check_mystatus returned MY_STATUS -> $MY_STATUS "
		
			if [[ "$ATOM_STATUS" -eq "DOWN" ]]; # ATOM_IP is down, server down
			then
			
				logline info "ping_check returned ATOM_IP -> UNREACHABLE"
				if [[ "$GATEWAY_STATUS" -eq "DOWN" ]]; # NO one is using the gateway IP
				then
						#turn gatway		

				elif [[ "$GATEWAY_STATUS" -eq "UP" ]]; # unkown on gateway ip
				then
						#atom is down, Im not the gateway..
						#some one is .. 
						logline error "Atom isnt the gateway, nor am I but someone is.. .. please check, continuing looping.."

				fi


		 	elif [[ "$ATOM_STATUS" -eq "UP" ]]; #ATOM_IP reachable, need to turn it off
		 	then	


		 		logline info "ping_check returned ATOM_IP -> UNREACHABLE"
				#kill timer scripts
				#
				
				if [[ "$GATEWAY_STATUS" -eq "UP" ]]; # 
		        	then
                                	logline error "ping_check returned GATEWAY_IP -> REACHABLE"
				 	#wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
				 
				 	$TEMP=$(ssh $ATOM_IP -p2222 "ifconfig eth0" | awk -F ':' '/inet addr/{print $2}' | sed -e 's/Bcast//g' )	
				 	if [[ "$TEMP" -eq "$GATEWAY_IP" ]];
				 	then
				 		logline info "Atom is the gateway, changing ip on atom.. "
						#run halt timer script..
						#continue looping
					 else 
				 		logline error "Atom isnt the gateway, nor am I but someone is.. .. please check, continuing looping.."
						#continue looping
				 	fi
				elif [[ "$GATEWAY_STATUS" -eq "DOWN" ]];
			 	then
			 	
					# ssh to atomip
					# enable gateway ip, 
					# start pppoe
					#stop pppoe on atom
				fi
			
			fi #end ATOM_IP reachable	

	fi #end elif GPIO


sleep $LOOP_INTERVAL

done



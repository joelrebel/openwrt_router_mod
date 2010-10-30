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
#LOG_LEVEL='2' 
# 0 - error logs only
# 1 - error + debug logs
# 2 - error + debug  + info logs
LOOP_INTERVAL=5 # in seconds
WOL_SENT_COUNT=0;
ATOM_MAC="00:1c:c0:d5:ed:60"

MY_IP='192.168.0.4'
MY_SECONDARY_IP='192.168.0.140'
MY_GATEWAY_INTF='br-lan' #brwlan

ATOM_IP='192.168.0.110'
ATOM_GATEWAY_INTF='eth0'

GATEWAY_IP='192.168.0.1'


MY_STATUS='UNKOWN'
ATOM_STATUS='UNKOWN'
POWER_STATUS='UNKOWN'
GATEWAY_STATUS='UNKOWN'

#cat /proc/diag/button/ses  - < AOSS button 
# 0 = MAINS_ON
# 1 = MAINS_OFF

POWERCUT_FLAG_COUNT=0;
POWERCUT_FLAG_MAXCOUNT=11; 
# $POWERCUT_FLAG_COUNT * LOOP_INTERVAL = number of seconds the script would wait to take action on the router..
# once the script hits maxcount, we run halt	

# function must be called with  log_line [debug|error] "some message here"
# Timestamp needs to be added for each logline
function logline 
{	
	if [[ $LOG_LEVEL -eq "0" ]];
	then
		if [ "$1" == "error" ];
		then
			echo "error: $2" 
		fi
	fi
	
	if [[ $LOG_LEVEL -eq "1" ]];
	then
		if   [ "$1" == "debug" ];
		then
			echo "debug: $2" 
			echo "error: $2" 
		fi
	fi
	
	if [[ $LOG_LEVEL -eq "2" ]];
	then
		if [ "$1" == "info" ] ;
		then	
			echo "info: $2" 
			echo "error: $2" 
			echo "debug: $2" 
		fi
	fi	
}

function powercut_flag_check 
{
	if [[ ! -f .powercut_flag ]];
	then
		touch .powercut_flag

	elif [[ -f .powercut_flag ]];
	then	
		if [[ $POWERCUT_FLAG_COUNT -le $POWERCUT_FLAG_MAXCOUNT ]];		
		then
			$POWERCUT_FLAG_COUNT=$(( $POWERCUT_FLAG_COUNT + 1 ))
			return $POWERCUT_FLAG_COUNT #max count not yet reached
	
		elif [[ $POWERCUT_FLAG_COUNT -eq $(( $POWERCUT_FLAG_MAXCOUNT+1 )) ]]; #12 * LOOP_INTERVAL = 60 secs/ 1min 
		then
			return 0 #max count reached
			
		fi

	fi
}

#ssh keys would be needed for server and router
function turn_atom_normal
{
	echo "->turn_atom_normal<-"
}

function turn_atom_gateway
{	
	echo "->turn_atom_gateway<-"
}

function turn_self_gateway 
{
	echo "->turn_self_gateway<-"
}

function turn_self_normal
{
	echo "->turn_self_normal<-"
}


function check_mystatus
{
	MY_CURRENT_IP=$(ifconfig $MY_GATEWAY_INTERFACE | awk -F ':' '/inet addr/{print $2}' | sed -e 's/Bcast//g')
	logline info  "MY_CURRENT_IP -> $MY_CURRENT_IP, MY_IP -> $MY_IP" 
	if [ "$MY_CURRENT_IP" ==  $MY_IP ];
	then
		MY_STATUS=NORMAL
		return 3

	elif [ "$MY_CURRENT_IP" == $GATEWAY_IP ];
	then
		MY_STATUS=GATEWAY
		return 2
	fi
}


function poll_gpio
{

 #POWER_STATUS=$(cat /proc/diag/button/ses)
 POWER_STATUS=$(cat /tmp/diag/button/ses)
 if [[ $POWER_STATUS -eq 0 ]];
 then
 	POWER_STATUS=ON
	return 0

 elif [[ $POWER_STATUS -eq 1 ]];
 then
 	POWER_STATUS=OFF
	return 1
 fi	
 
  	 
}

function ping_check
{
	#pull out mac addr, compare and set MAC to ATOM|ME|UNKNOWN	
	TO_PING=$1
	COUNT=0

	while [[ $COUNT -ne 5 ]]
	do	
		arping -c1 $TO_PING -w2 -I $INTF
		# returns 1 if sucess,
		# returns 0 if fail
		
		if [[ $? -eq 0 ]];
		then
	     		PING_COUNT=$(( PING_COUNT + 1 ))
		fi

		COUNT=$(( $COUNT + 1 ))	
		sleep 1
	done	

	if [[ $PING_COUNT -ge 3 ]];
	then
		return 0 #$1 reachable
	else
		return 1 #$1 unreachable
	fi	
}



while [[ 1 ]];
do	
	check_mystatus #returns NORMAL|GATEWAY
	logline debug "MY_STATUS-> $MY_STATUS"
	exit
	if [ "$MY_STATUS" == "NORMAL" ];
	then
		ping_check $GATEWAY_IP
		if [[ $? -eq 1 ]];
		then
			GATEWAY_STATUS=DOWN
		elif [[ $? -eq 0 ]];
		then
			GATEWAY_STATUS=UP
		fi
	elif [ "$MY_STATUS" == "GATEWAY" ];
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
	if [ "$POWER_STATUS" == "ON" ]; #GPIO indicates power is ON
	then	
		logline debug "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
		POWERCUT_FLAG_COUNT=0; # since power is present, resetting flag to 0	

		if [ "$MYSTATUS" == "NORMAL" ]; # Router isnt the gateway and power is present we need to ensure atom is gateway
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
					logline error "POWER_STATUS -> $POWER_STATUS, MYSTATUS -> $MYSTATUS, ATOM_STATUS -> $ATOM_STATUS - but GATEWAY_STATUS -> $GATEWAY_STATUS :S"
					#do nothing, 
					#continue in loop
				fi

			####end ATOM_STATUS DOWN
		 	elif [ "$ATOM_STATUS" == "UP" ]; #ATOM_IP reachable, ensure atom is the gateway - 
			then	


		 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS"
				if [ "$GATEWAY_STATUS" == "UP" ]; # 
		        	then
                                	logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS"
				 	#wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
				 	
					$TEMP=$(ssh $ATOM_IP -p2222 "ifconfig $ATOM_GATEWAY_INTF" | awk -F ':' '/inet addr/{print $2}' | sed -e 's/Bcast//g' )	
				 	if [ "$TEMP" == "$GATEWAY_IP" ];
				 	then
				 		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, ATOM is GATEWAY \0/"
					 else 
				 		logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, ATOM is NOT the GATEWAY :S"
						#do nothing,
						#continue looping
				 	fi
		        	
				elif [ "$GATEWAY_STATUS" == "DOWN" ];
			 	then
			 		
					logline error "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS, GATEWAY_STATUS -> $GATEWAY_STATUS, Turning atom into gateway .."
					turn_atom_gateway
				fi
			
			fi #end ATOM_STATUS UP
		
		elif [ "$MYSTATUS" == "GATEWAY" ]; #Power is present, router is the gateway - we need to check and turn atom into the gateway
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
			
			if [ "$MYSTATUS" == "NORMAL" ]; # IM not the gateway
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
					if [ "$GATEWAY_STATUS" == "UP" ]; # 
		        		then
                                		logline info "POWER_STATUS -> $POWER_STATUS, MY_STATUS -> $MY_STATUS, ATOM_STATUS -> $ATOM_STATUS,  GATEWAY_STATUS -> $GATEWAY_STATUS"
						#wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
	
					elif [ "$GATEWAY_STATUS" == "DOWN" ];
			 		then
			 			turn_self_gateway
					fi
			
				fi #end ATOM_IP reachable

			elif [ "$MYSTATUS" == "GATEWAY" ]; #Power is out, need to ensure atom is down
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



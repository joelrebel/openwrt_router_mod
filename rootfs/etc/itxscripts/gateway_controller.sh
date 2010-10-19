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

LOG_FILE='gateway_control.log'
MY_SECONDARY_IP='192.168.0.40'
ATOM_IP='192.168.0.110'
GATEWAY_IP='192.168.0.1'
MY_IP='192.168.0.4'
MY_STATUS='UNKOWN'
ATOM_STATUS='UNKOWN'
POWER_STATUS='UNKOWN'

#POWER_STATUS
#cat /proc/diag/button/ses  - < AOSS button 
# 0 = MAINS_ON
# 1 = MAINS_OFF

#GATEWAY_STATUS will be set in course of the script, the possible status types are
#0] NORMAL - router is router
#1] GATEWAY - router is the gateway
#2] NOONE    - Noone is the gateway
#3] MORPHTOGW - changing status to gateway
#4] MORPHTOROUTER - changing status to router
#5] UNKOWN - No values set - start of script 


poll_gpio
if [[ $? -eq 0 ]]; #GPIO indicates power is ON
then
	logline debug "poll_gpio returned POWER_STATUS -> $POWER_STATUS"
	check_mystatus
	if [[ $? -eq 0 ]]; # Router isnt the gateway
	then
		logline debug "check_mystatus returned MY_STATUS -> $MY_STATUS "
		ping_check $ATOM_IP
		if [[ $? -eq 1 ]]; # ATOM_IP is down, server down
		then
			logline info "ping_check returned ATOM_IP -> UNREACHABLE"
			ping_check $GATEWAY_IP
			if [[ $? -eq 0 ]]; # someone is using the gateway ip!
			then
				logline error "ping_check returned GATEWAY_IP -> REACHABLE"
				logline error "ATOM isnt up, neither am I the gateway - but someone is! Joel whats changed?!"
				#break out of this if fi fi fi, continue polling

			elif [[ $? -eq 1 ]]; # NO one is using the gateway IP
			then
				logline debug "ping_check returned GATEWAY_IP -> UNREACHABLE"
				logline info "Running boot ATOM server timer script"
				logline info "No gateway is up, changing my ip to gateway"
				#timer script runs here
				#turn_gateway called here

			fi
		 elif [[ $? -eq 0 ]]; #ATOM_IP reachable, 
		 then
		 	logline info "ping_check returned ATOM_IP -> REACHABLE"
			ping_check $GATEWAY_IP
			if [[ $? -eq 0 ]]; # 
		        then
                                 logline error "ping_check returned GATEWAY_IP -> REACHABLE"
				 #wrong to take for granted atom would be the gateway, could do better here - figure mac etc..
				 	
			


function logline # function must be called with  log_line [debug|error] "some message here"
		  # Timestamp needs to be added for each logline
{	
	if [[ $LOG_LEVEL -eq "0" ]];
	then
		if [[ $1 -eq "error" ]];
		then
			echo "error: $2" >> $LOG_FILE
		fi
	fi
	
	if [[ $LOG_LEVEL -eq "1" ]];
	then
		if   [[ $1 -eq "debug" ]];
		then
			echo "debug: $2" >>  $LOG_FILE
			echo "error: $2" >> $LOG_FILE
		fi
	fi
	
	if [[ $LOG_LEVEL -eq "2" ]];
	then
		if [[ $1 -eq "debug" ]] ;
		then	
			echo "info: $2" >>  $LOG_FILE
			echo "error: $2" >> $LOG_FILE
			echo "debug: $2" >> $LOG_FILE
		fi
	fi	
}

function check_mystatus
{

	MY_CURRENT_IP=$(ifconfig br-lan | awk -F ':' '/inet addr/{print $2}' | sed -e 's/Bcast//g')
	if [[ $MY_CURRENT_IP -eq $MY_IP ]];
	then
		MY_STATUS=NORMAL
		return 0

	elif [[ $MY_CURRENT_IP -eq $GATEWAY_IP ]];
	then
		MY_STATUS=GATEWAY
		return 2
	fi



}


function poll_gpio
{

 POWER_STATUS=$(cat /proc/diag/button/ses)
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
		arping -c1 $TO_PING -w2
		# returns 1 if sucess,
		# returns 0 if fail
		
		if[[ $? -eq 0 ]];
		do
	     		PING_COUNT=$(( PING_COUNT + 1 ))
		done

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

function turn_gateway 
{
	echo ">> Turning into gateway "
	;ifconfig etc etc

}


                  
function power_cut
{	
	check_status
	if [[ "$MY_STATUS" -eq "NORMAL" ]];
	then
		
		ping_check $ATOM_IP
		if [[ $? -eq 0 ]];
		then
			ssh $ATOM_IP -p2222 halt
			if [ $? -eq 0 ];
			then 
				echo ">> Halt ran on $ATOM_IP"
				
				while [[ `ping_check $ATOM_IP` -ne 1 ]]; #possible phail
				do	
					echo ">> Waiting for $ATOM_IP to halt.."
				done

				turn_gateway

			else
				echo ">> ssh failed to $ATOM_IP failed"
				echo ">> wtf, ssh not running or server hung - stop manually or give me a relay Ill turn it off ;)"
			fi
		else
		#atom is down, lets turn into gateway
			echo ">> Atom is down.."
			turn_gateway	

		fi	

	fi


	if [[ "$MY_STATUS" -eq "GATEWAY" ]];
	then

		 
		

	fi	
 
}                
                 
function power_up
{
  check_status

  ping_check $ATOM_IP
  if [[ $? -eq 1 ]];
  then
  	echo ">> $ATOM_IP down / Unreachable"
  else
  	
  fi
  	


}




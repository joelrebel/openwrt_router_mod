#!/bin/bash
#ned 
set -x

POWERCUT_FLAG_COUNT=0;
POWERCUT_FLAG_MAXCOUNT=11; # $POWERCUT_FLAG_COUNT * LOOP_INTERVAL = number of seconds the script would wait to take action on the router..
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

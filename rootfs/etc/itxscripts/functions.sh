
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
		return 3

	elif [[ $MY_CURRENT_IP -eq $GATEWAY_IP ]];
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
#	;ifconfig etc etc

}


                  
function power_cut
{	
	check_mystatus
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

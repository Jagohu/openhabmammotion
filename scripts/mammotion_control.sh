#!/bin/bash
OPENHABUSERPASS="username:password"								# OpenHAB username:password eg. root:mypassword
OPENHABIP="192.168.0.X"											# OpenHAB IP
OPENHABPORT="8080"												# OpenHAB Port (will be used as IP:Port - so here you only give the number
backup_datafile_path="/etc/openhab/scripts/mammotion_data"		# OpenHAB scripts folder - if different, you must also modify the path to this script in the mammotion.rules file
token_path="/etc/openhab/scripts/mammotion_token"				# OpenHAB scripts folder - this is the file the token is stored at - openHAB items are sometimes cutting it too short
mowerid_path="/etc/openhab/scripts/mammotion_mowerid"			# OpenHAB scripts folder - this is the file that stores the mower ID
log_path="/var/log/openhab/openhab.log"							# OpenHAB log path - this is used for error logging
CLIENT_ID="MY_CLIENT_ID_FROM_MAMMOTION"							# required to get the token - from your dashboard - my credentials at https://developer.mammotion.com/
CLIENT_SECRET="MY_CLIENT_SECRET_FROM_MAMMOTION"					# required to get the token - from your dashboard - my credentials at https://developer.mammotion.com/
MOWER_ID="default" 												# will be loaded from reading the file at $mowerid_path

if [ $1 != "START" && $1 != "STOP" && $1 != "PAUSE" && $1 != "RESUME" && $1 != "STOP" && $! != "RETURN" && !1 != "CANCEL_RETURN" ]; then
	echo "INVALID OPTION: $1"
	echo "POSSIBLE OPTIONS: START, STOP, PAUSE, RESUME, STOP, RETURN, CANCEL_RETURN"
	current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
	echo "$current_time  [ERROR] [Mammotion.HTTP.Script] - Start Task INVALID OPTION: $1 | Taskname: $2" >> $log_path		
	exit
fi
echo "OPTION: $1"
echo "Task name: $2"

# Load access token from OpenHAB
access_token=$(cat $token_path)

# Check if the token file already exist
if [ -f "$(find "$token_path" 2>/dev/null)" ]; then
	# If it does then load it
	access_token=$(cat $token_path)
else
	# If it does not then try to authenticate and get a token
	result=$(curl -si -X POST https://id.mammotion.com/oauth2/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&grant_type=client_credentials")
	msg=$(echo "$result" | grep -oP '"msg":"\K[^"]*')
	if [[ $msg != "Request success" ]]; then
		echo "INIT TOKEN REFRESH FAILED: " + result
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "FAILED" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_Active_Token_Expiry" -k --user $OPENHABUSERPASS 2>/dev/null
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "0" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_binding_status" -k --user $OPENHABUSERPASS 2>/dev/null
		current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
		echo "$current_time  [ERROR] [Mammotion.HTTP.Script] - StartTask INIT TOKEN REFRESH FAILED: $result" >> $log_path	
		exit
	else
		#take the values out
		echo "Token successfully retrieved"
		current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
		echo "$current_time  [WARN] [Mammotion.HTTP.Script] - StartTask  INIT TOKEN RETRIEVAL SUCCESSFUL." >> $log_path		
		access_token=$(echo "$result" | grep -oP '"access_token":"\K[^"]*')
		expires_in=$(echo "$result" | grep -oP '"expires_in":\K[0-9]*')
		echo $access_token > $token_path
		#Post expirt time to OPENHAB
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$expires_in" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_Active_Token_Expiry" -k --user $OPENHABUSERPASS 2>/dev/null
	fi
fi

if [ -f "$(find "$mowerid_path" 2>/dev/null)" ]; then	
	echo "Mower ID file found"
	MOWER_ID=$(cat $mowerid_path)
else
	# If there is no mowerid, then try to authenticate and get a token
	echo "No MowerID - trying to find it out from https://api-open.mammotion.com/v1/mowers"
	result=$(curl -X GET https://api-open.mammotion.com/v1/mowers -H "Authorization: Bearer ${access_token}")
	#echo "Result: $result" | tr "," "\n"

	clean=$(echo $result | sed 's/.*data:\[{//g; s/.*data\":\[//g; s/icon.*online/online/g; s/\,request.*//g; s/{//g; s/}//g; s/\]//g; s/\"//g') 

	# Check all items 1-10 and determine which is a mower -> in case of too many Mammotion devices it might not find it 
	# -> in that case use Postman -> GET https://api-open.mammotion.com/v1/mowers with Authorization - select Bearer Token and copy-paste your token (from the mowerid_path="/etc/openhab/scripts/mammotion_mowerid") as a value 
	# -> you should get your list of devices and you can create the file at mowerid_path="/etc/openhab/scripts/mammotion_mowerid" -> copy-paste the ID and you're good
	for i in {1..10}
	do
		# Extract the field from the raw text string cleanly
		extracted_item=$(echo "$clean" | cut -d "," -f$i)   
		# Only print if the field contains data
		if [ -n "$extracted_item" ]; then
			echo "[$i]$extracted_item"
			if [[ $extracted_item =~ "id" ]]; then
				if [[ $i <5 ]]; then
					id_first=$(echo $extracted_item | cut -d ":" -f2)
				else
					id_second=$(echo $extracted_item | cut -d ":" -f2)
				fi
			elif [[ $extracted_item =~ "model" ]]; then
				if [[ $i <5 ]]; then
					model_first=$(echo $extracted_item | cut -d ":" -f2)
				else
					model_second=$(echo $extracted_item | cut -d ":" -f2)
				fi		
			elif [[ $extracted_item =~ "online" ]]; then
				if [[ $i <5 ]]; then
					online_first=$(echo $extracted_item | cut -d ":" -f2)
				else
					online_second=$(echo $extracted_item | cut -d ":" -f2)
				fi
			fi
		fi	
	done
	#echo "ID1: $id_first"
	#echo "Model1: $model_first"
	#echo "Online1: $online_first"
	#echo "ID2: $id_second"
	#echo "Model2: $model_second"
	#echo "Online2: $online_second"


	current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
	if [[ $online_first==1 && $MOWER_ID=="default" ]]; then	
		if [[ $model_first =~ "YUKA" || $model_first =~ "LUBA" ]]; then
			MOWER_ID=$id_first
			echo $MOWER_ID > $mowerid_path
			echo "$current_time  [WARN] [Mammotion.HTTP.Script] - MOWER ID saved to $mowerid_path. ID: $MOWER_ID | Model: $model_first " >> $log_path
			echo "First is a mower and online. MOWER_ID SET: $MOWER_ID"
		else
			echo "First is not a mower: $model_first"
		fi
	else
		echo "First is not online or Mower ID is set"
	fi
	
	if [[ $nline_second == 1 && $MOWER_ID == "default" ]]; then
		if [[ $model_second =~ "YUKA" || $model_second =~ "LUBA" ]]; then
			MOWER_ID=$id_second
			echo $MOWER_ID > $mowerid_path
			echo "$current_time  [WARN] [Mammotion.HTTP.Script] - MOWER ID saved to $mowerid_path. ID: $MOWER_ID | Model: $model_second " >> $log_path
			echo "Second is a mower and online. MOWER_ID SET: $MOWER_ID"
		else
			echo "Second is not a mower: $model_second"
		fi	
	else
		echo "Second is not online or Mower ID is set"
	fi

	if [[ $online_first != 1 && $online_second != 1 && $MOWER_ID == "default" ]]; then
		echo "NONE OF THEM ARE ONLINE - DECIDING BASED ON MODEL"
		if [[ $model_first =~ "YUKA" || $model_first =~ "LUBA" ]]; then
			MOWER_ID=$id_first
			echo $MOWER_ID > $mowerid_path
			echo "$current_time  [WARN] [Mammotion.HTTP.Script] - MOWER ID saved to $mowerid_path. ID: $MOWER_ID | Model: $model_first " >> $log_path
		elif [[ $model_second =~ "YUKA" || $model_second =~ "LUBA" ]]; then
			MOWER_ID=$id_second
			echo $MOWER_ID > $mowerid_path
			echo "$current_time  [WARN] [Mammotion.HTTP.Script] - MOWER ID saved to $mowerid_path. ID: $MOWER_ID | Model: $model_second " >> $log_path
		else
			echo "ERROR - none of them are online and none of them are mowers"
			exit
		fi
	fi
fi



echo "Execute command"
	result=$(curl --location --request POST 'https://api-open.mammotion.com/v1/mower/action' \
  --header "Authorization: Bearer ${access_token}" \
  --header "Content-Type: application/json" \
  --data "{\"deviceId\": \"$MOWER_ID\",\"action\": \"$1\",\"params\": { \"taskName\": \"$2\" }}")
echo "Result: $result"
sleep 2;
/etc/openhab/scripts/mammotion_datarefresh.sh

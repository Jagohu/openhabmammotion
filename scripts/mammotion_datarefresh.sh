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

# Load access token from OpenHAB scripts folder - if already available
access_token=$(cat $token_path)

# Check if the token file already exist
if [ -f "$(find "$token_path" 2>/dev/null)" ]; then
	# If it does then load it
	access_token=$(cat $token_path)
else
	# If there is no token, then try to authenticate through the client id and secret and get a token
	result=$(curl -si -X POST https://id.mammotion.com/oauth2/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&grant_type=client_credentials")
	msg=$(echo "$result" | grep -oP '"msg":"\K[^"]*')
	if [[ $msg != "Request success" ]]; then
		echo "INIT TOKEN REFRESH FAILED: " + result
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "FAILED" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_Active_Token_Expiry" -k --user $OPENHABUSERPASS 2>/dev/null
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "0" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_binding_status" -k --user $OPENHABUSERPASS	2>/dev/null
		current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
		echo "$current_time  [ERROR] [Mammotion.HTTP.Script] - INIT TOKEN REFRESH FAILED: $result" >> $log_path	
		exit
	else
		#take the values out
		echo "Token successfully retrieved"
		current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
		echo "$current_time  [WARN] [Mammotion.HTTP.Script] - INIT TOKEN RETRIEVAL SUCCESSFUL." >> $log_path		
		access_token=$(echo "$result" | grep -oP '"access_token":"\K[^"]*')
		expires_in=$(echo "$result" | grep -oP '"expires_in":\K[0-9]*')
		echo $access_token > $token_path
		#Post expirt time to OPENHAB
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$expires_in" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_Active_Token_Expiry" -k --user $OPENHABUSERPASS 2>/dev/null
	fi
fi

if [ -f "$(find "$mowerid_path" 2>/dev/null)" ]; then	
	#echo "Mower ID file found"
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

# Preparations complete - we should have a Token and a Mower ID
# Let's take the data
result=$(curl -X GET https://api-open.mammotion.com/v1/mower/$MOWER_ID -H "Authorization: Bearer ${access_token}" 2>/dev/null)

# echo "Data retrieval raw result: $result" | tr "," "\n"

# Full result to determine whether it was successful or not
msg=$(echo "$result" | tr "," "\n" | grep '"msg"' | cut -d: -f2 | tr -d '"{}') #Did it succeed or not?
echo "Success: $msg"

if [[ $msg != "Request success" ]]; then
	# It can only be due to expired token (if no mowerid then we exited already) -> start initial token retrieval
	result=$(curl -si -X POST https://id.mammotion.com/oauth2/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&grant_type=client_credentials")
	# Full result to determine whether it was successful or not
	msg=$(echo "$result" | grep -oP '"msg":"\K[^"]*')
	sleep 2;
	if [[ $msg != "Request success" ]]; then
		# Refresh failed -> log it and mark it as failed in openhab items
		echo "TOKEN REFRESH FAILED: " + result
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "FAILED" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_Active_Token_Expiry" -k --user $OPENHABUSERPASS 2>/dev/null
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "0" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_binding_status" -k --user $OPENHABUSERPASS 2>/dev/null	
		current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
		echo "$current_time  [ERROR] [Mammotion.HTTP.Script] - TOKEN REFRESH FAILED: $result" >> $log_path
		exit
	else
		# Refresh successful
		echo "Token successfully retrieved"
		access_token=$(echo "$result" | grep -oP '"access_token":"\K[^"]*')
		expires_in=$(echo "$result" | grep -oP '"expires_in":\K[0-9]*')
		echo $access_token > $token_path
		# Post it to OPENHAB
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$expires_in" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_Active_Token_Expiry" -k --user $OPENHABUSERPASS 2>/dev/null
		# Second try to retrieve data
		result=$(curl -X GET https://api-open.mammotion.com/v1/mower/$MOWER_ID -H "Authorization: Bearer ${access_token}")
		curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "1" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_binding_status" -k --user $OPENHABUSERPASS 2>/dev/null
		current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")
		echo "$current_time  [WARN] [Mammotion.HTTP.Script] - TOKEN REFRESH SUCCESSFUL. New data: $result" >> $log_path
		echo $result > backup_datafile_path
	fi
else
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "1" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_binding_status" -k --user $OPENHABUSERPASS 2>/dev/null
fi

# This bit is only here if there was a second try for a token retrieval and succeeded
if [ -n "$(find "$backup_datafile_path" -mmin -1 2>/dev/null)" ]; then
	echo "Backup datafile exists at $backup_datafile_path"
	result=$(cat $backup_datafile_path)
	firmware=$(echo "$result" | tr "," "\n" | grep '"version"' | cut -d: -f2 | tr -d '"{}')
	online=$(echo "$result" | tr "," "\n" | grep '"online"' | cut -d: -f2 | tr -d '"{}')
	status=$(echo "$result" | tr "," "\n" | grep '"status"' | cut -d: -f2 | tr -d '"{}')
	batterylevel=$(echo "$result" | tr "," "\n" | grep '"batteryLevel"' | cut -d: -f2 | tr -d '"{}')
	chargestatus=$(echo "$result" | tr "," "\n" | grep '"chargeStatus"' | cut -d: -f2 | tr -d '"{}')
	usednetwork=$(echo "$result" | tr "," "\n" | grep '"usedNetwork"' | cut -d: -f3 | tr -d '"{}')
	wifirssi=$(echo "$result" | tr "," "\n" | grep '"wifiRssi"' | cut -d: -f2 | tr -d '"{}')
	cellularrssi=$(echo "$result" | tr "," "\n" | grep '"cellularRssi"' | cut -d: -f2 | tr -d '"{}')
	wifiavailable=$(echo "$result" | tr "," "\n" | grep '"wifiAvailable"' | cut -d: -f2 | tr -d '"{}')
	cellularavailable=$(echo "$result" | tr "," "\n" | grep '"cellularAvailable"' | cut -d: -f2 | tr -d '"{}')
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$online" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Online_Status" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$firmware" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Firmware" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$status" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Status" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$batterylevel" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Battery" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$batterylevel" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_ChargeStatus" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$usednetwork" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Active_Network" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$wifirssi" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_WiFi_RSSI" -k --user $OPENHABUSERPASS 2>/dev/null
	curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$cellularrssi" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Cellular_RSSI" -k --user $OPENHABUSERPASS  2>/dev/null
	echo "Deleting backup datafile"
	rm $backup_datafile_path
	exit
fi

# Normal routine - separate and post values to OpenHAB
firmware=$(echo "$result" | tr "," "\n" | grep '"version"' | cut -d: -f2 | tr -d '"{}')
online=$(echo "$result" | tr "," "\n" | grep '"online"' | cut -d: -f2 | tr -d '"{}')
status=$(echo "$result" | tr "," "\n" | grep '"status"' | cut -d: -f2 | tr -d '"{}')
batterylevel=$(echo "$result" | tr "," "\n" | grep '"batteryLevel"' | cut -d: -f2 | tr -d '"{}')
chargestatus=$(echo "$result" | tr "," "\n" | grep '"chargeStatus"' | cut -d: -f2 | tr -d '"{}')
usednetwork=$(echo "$result" | tr "," "\n" | grep '"usedNetwork"' | cut -d: -f3 | tr -d '"{}')
wifirssi=$(echo "$result" | tr "," "\n" | grep '"wifiRssi"' | cut -d: -f2 | tr -d '"{}')
cellularrssi=$(echo "$result" | tr "," "\n" | grep '"cellularRssi"' | cut -d: -f2 | tr -d '"{}')
wifiavailable=$(echo "$result" | tr "," "\n" | grep '"wifiAvailable"' | cut -d: -f2 | tr -d '"{}')
cellularavailable=$(echo "$result" | tr "," "\n" | grep '"cellularAvailable"' | cut -d: -f2 | tr -d '"{}')


curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$online" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Online_Status" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$firmware" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Firmware" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$status" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Status" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$batterylevel" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Battery" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$batterylevel" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_ChargeStatus" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$usednetwork" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Active_Network" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$wifirssi" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_WiFi_RSSI" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$cellularrssi" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mower_Cellular_RSSI" -k --user $OPENHABUSERPASS 2>/dev/null
curl -m 5 -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "1" "https://$OPENHABIP:$OPENHABPORT/rest/items/Mammotion_binding_status" -k --user $OPENHABUSERPASS 2>/dev/null

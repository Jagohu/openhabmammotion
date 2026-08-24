# openhabmammotion
Bash-HTTP binding for OpenHAB

1. Create a Mammotion Developer account
   Link: https://developer.mammotion.com/
   A) Sign in with your Mammotion credentials
   B) Click on My Credentials
   C) If you don't have one already then click +NEW CREDENTIAL to create one
   D) Note down client_id and client_secret (Note: you won't need a refresh until the Expiration time)

2. Create your OpenHAB items
  Mammotion.items
Group gMammotion "Mammotion"
String Mammotion_Active_Token_Expiry "Expiry Token [%s]" (gMammotion)
String Mammotion_binding_status "Mammotion binding Status [%s]" <network>    	(gMammotion)

// Operational parameters
Number    Mower_Online_Status   "Mower Network State [%d]"      <network>   	(gMammotion)
String    Mower_Firmware        "Mower Firmware Version [%s]"   <settings>  	(gMammotion)
String    Mower_Status          "Mower Operational Status [%s]" <motion>    	(gMammotion)
String    Mower_ChargeStatus    "Mower Charge Status [%s]" 		<motion>    	(gMammotion)
Number    Mower_Battery         "Mower Battery Level [%d %%]"   <battery>   	(gMammotion)
DateTime  Mower_updated			"Mower Last updated [%1$td.%1$tm.%1$tY %1$tT]"	(gMammotion)

// Network
String    Mower_Active_Network  "Active Connection Type [%s]"   <network>   	(gMammotion)
Number    Mower_WiFi_RSSI       "WiFi Signal Strength [%d dBm]" <signal>    	(gMammotion)
Number    Mower_Cellular_RSSI   "Cellular Signal [%d dBm]"      <signal>   		(gMammotion)

String Mower_Control 			"Send Mower Command [%s]" 		<movecontrol> 	(gMammotion)


4. 
5. 

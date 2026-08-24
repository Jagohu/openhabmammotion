# openhabmammotion
**Bash-HTTP solution for OpenHAB integration of Mammotion Yuka and Mammotion Luba lawnmowers**
 
I know that many people can do a much more professional job than me on this, but after waiting for more than a year there are no working bindings that would allow my Mammotion Yuka to be controller from my OpenHAB. Because of that, I decided to write this set of scripts, which is a dirty solution as it uses bash, but it should work.

If you just follow the instructions below, you should quite easily make it work.

Possible issues:

A) Permissions of executing a script inside the Openhab/scripts folder - but that's for you to sort out. As long as you modify the paths in the script and the rules file, technically you can put it anywhere.

B) Too many Mammotion devices (3 or more) might lead to the binding not finding the correct Mower ID or will only find the first one - you can use e.g/ Postman to figure out yours:

   -> make a request to GET https://api-open.mammotion.com/v1/mowers with Authorization - select Bearer Token and copy-paste your token (from the mowerid_path="/etc/openhab/scripts/mammotion_mowerid") as a value 
   
   -> you should get your list of devices and you can create the file at mowerid_path="/etc/openhab/scripts/mammotion_mowerid" -> copy-paste the ID and you're good

C) The default setting to retrieve data is:
   
   -every 5 minutes between 8-22 h, every 15 minutes befween 22-8 h
   
   -after every command

   -pressing manual refresh

This is done to make sure Mammotion doesn't lock you out from your account for abusing the API. Tweak the values at your own risk!

**What you get - on BasicUI**
<img width="1151" height="481" alt="image" src="https://github.com/user-attachments/assets/de4a0434-6e42-4e71-bf95-27cd62c8ccf2" />

Currently these are the items which are exposed and I managed to catch. The official documentation is not that great yet, and this was all a days' work only. I'm sure there is much more to it.

1. **Create a Mammotion Developer account (free)**

   Link: https://developer.mammotion.com/
   
   A) Sign in with your Mammotion credentials
   
   B) Click on My Credentials
   
   C) If you don't have one already then click +NEW CREDENTIAL to create one
   
   D) Note down **client_id** and **client_secret** (Note: you won't need a refresh until the Expiration time)

3. Copy the transformation maps to your openhab folder (e.g. /etc/openhab/transform/)
4. Copy the items to your openhab folder (e.g. /etc/openhab/items/)
5. Copy the script files to your openhab folder (e.g. /etc/openhab/scripts/)
6. Fill in the necessary fields on the top of BOTH of the .sh scripts with your implementation **BEFORE you go further**

      -Openhab IP
   
      -Openhab Username:Password
   
      -Client ID
   
      -Client Secret
   
      -modify paths if your openhab is NOT located under /etc/openhab
   
8. Insert the content of the sitemap file to your openhab sitemap (e.g. /etc/openhab/sitemaps/default.sitemap)
9. Copy the rules file to your openhab folder (e.g. /etc/openhab/rules/) - this will trigger the routine at the next 5 minute mark or upon pressing Manual refresh


**Description**

After copying the .rules file, the cron will trigger at the next 5 or 15 minutes and based on what you filled in (in both _mammotion_datarefresh.sh_ and _mammotion_control.sh_) headers will download the token and determine the mower id, followed by a data retrieval. At this moment you should see all Items go populated.

If you don't, then check your _openhab.log_ and _events.log_ for clues.



**[Google GEMINI Generated]**
**Risks of Unofficial API UseIf you connect your Luba or Yuka mower to a smart home hub using community libraries like PyMammotion:**

Account Bans: Mammotion’s Terms of Service strictly prohibit unauthorized third-party clients. They actively monitor traffic and have disabled user accounts for causing server overloads.
https://www.reddit.com/r/MammotionTechnology/comments/1szpdcx/further_update_on_recent_connectivity_issues/

Total App Freeze: Triggering a rate limit (HTTP Error 429) locks you out of the official Mammotion mobile app. You will lose all cloud control until the multi-hour cooldown window expires.
https://github.com/mikey0000/Mammotion-HA/issues/629

The Burst Trigger: Rate limits are usually tripped when smart platforms fire a quick burst of 10–20 concurrent configuration commands right after a system reboot or integration reload.
https://github.com/mikey0000/Mammotion-HA/issues/629


How to Prevent LockoutsIf you are currently running an automation setup via platforms like the Mammotion Home Assistant integration or openHAB, follow these community-tested safety measures:

Implement a Dummy Account: Create a secondary Mammotion account, share your mower to it via the main app, and log into your smart home system using the secondary account. If a lockout happens, your primary master account remains safe.
https://github.com/mikey0000/Mammotion-HA

Utilize Bluetooth Proxies: Whenever possible, communicate with the mower locally using a Bluetooth proxy or local MQTT options rather than querying Mammotion’s Aliyun cloud gateway. 
https://github.com/mikey0000/Mammotion-HA/issues/609

Stagger Polling Intervals: Increase your polling timers so status checks are spread far apart. Avoid aggressive data scraping while the robot is actively mowing.
https://community.home-assistant.io/t/home-connect-integration-rate-limit-of-1000-apicalls/327460

**Have fun!**

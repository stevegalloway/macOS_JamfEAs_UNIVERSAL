#!/bin/zsh --no-rcs

<<ABOUT_THIS_SCRIPT
============================================================================

Written by: Steve Galloway
- Senior System Engineer
- Swiss IT Security AG
- stephen.galloway@sits.ch

Created on: 20 May 2025 - 11:55

Modified on: 

Changes:


Purpose:


Instructions:
Run locally -> Run the script in Terminal, making sure to
provide it the appropriate permissions (chmod)
Run via Jamf -> Assign script to a policy and scope it to
the target computer(s) with a trigger and frequency of your choice

===========================================================================
ABOUT_THIS_SCRIPT

# ===== UNcomment the below command only if you need to debug the script =====
# set -x

# Let script exit if a command fails
set -o errexit

# Let script exit if an unused variable is used
set -o nounset

####################################################################################################
#
# VARIABLES START SETUP
#
####################################################################################################

loggedInUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# Variables for logging
SCRIPTNAME=$(basename "${0}")
SCRIPTDIR=$(dirname "${0}")
SCRIPT_VER="0.4"
LOGFILE="/Users/${loggedInUser}/Library/Logs/${SCRIPTNAME}.log"
TODAY=$(date +"%Y-%m-%d")

# Username of the account to be removed
userName="${4}"
password="${5}"

# Enter the JSS URL
url="${6}"

# Enter the API Client's ID and Secret
# Needed for the Jamf Pro API calls
client_id="${7}"
client_secret="${8}"

# Enter the username and password of API Ad-hoc account
# Needed for the Jamf Pro CLASSIC API calls

#JAMFUSER="${9}"
#JAMFPASS="${10}"

#######################***DO NOT MODIFY BEYOND HERE***#######################

# Base 64 Encryption - DO NOT Modify
#B64=$(printf "${JAMFUSER}:${JAMFPASS}" | iconv -t ISO-8859-1 | base64 -i -)

# Placeholder
token_expiration_epoch=""


####################################################################################################
#
# FUNCTIONS START SETUP
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# JAMF PRO API
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

getAccessToken() {
	response=$(curl --silent --location --request POST "${url}/api/oauth/token" \
		--header "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode "client_id=${client_id}" \
		--data-urlencode "grant_type=client_credentials" \
		--data-urlencode "client_secret=${client_secret}")
	access_token=$(echo "$response" | plutil -extract access_token raw -)
	token_expires_in=$(echo "$response" | plutil -extract expires_in raw -)
	token_expiration_epoch=$(($current_epoch + $token_expires_in - 1))
}

checkTokenExpiration() {
	current_epoch=$(date +%s)
	if [[ token_expiration_epoch -ge current_epoch ]]
	then
		echo "Token valid until the following epoch time: " "$token_expiration_epoch" > /dev/null
	else
		echo "No valid token available, getting new token" > /dev/null
		getAccessToken
	fi
}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${access_token}" $url/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		access_token=""
		token_expiration_epoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# 09:29:38 - 12 Apr 2024
#
# New Logging mechanism:
# Adds more context to each logged message
# The logging is triggerred by calling this function and takes as parameter the next command ($1)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function logme() {
	
	DATE=$(date +%Y-%m-%d\ %H:%M:%S)
	echo "$DATE | v$SCRIPT_VER | $SCRIPTNAME: $1" >> "$LOGFILE"
	
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# 09:34:59 - 12 Apr 2024
#
# Function to check if the log file exists.
# If it doesn't it will create a new one.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function check_if_log_exists () {
	
	if [[ ! -e "${LOGFILE}" ]]
		
	then
		
		echo "Log file not found. Creating a new one."
		touch "$LOGFILE" && echo "Log file successfully created at $LOGFILE". || echo "Could not create log file!"
		
	fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# 09:39:31 - 12 Apr 2024
#
# Function that removes the user home folder
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function remove_home_folder () {
	
	if [[ -d /Users/"${userName}" ]]
		
	then
		
		logme "Home folder found. Proceeding with its removal."
		echo "Home folder found. Proceeding with its removal."
        
		rm -rf /Users/"${userName}" && logme "Home folder successfully removed." || logme "Could not remove the Home folder."
		
	else
		
		logme "Home folder not found. Doing nothing."
		echo "Home folder not found. Doing nothing."
        
	fi
	
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# 09:40:05 - 12 Apr 2024
#
# Function that checks if the user account exists
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function check_if_user_account_exists_and_remove_it () {
	
	if [[ -n $(sudo dscl . list /Users | grep "$userName") ]]
		
	then
		
		# Confirms that it exist and removes it
		logme "$userName found. Proceeding with its removal."
        echo "$userName found. Proceeding with its removal."
		
		dscl . -delete /Users/"$userName" && logme "$userName successfully removed." || logme "Could not remove $userName."
		
	else
		
		logme "$userName not found. Exiting the script."
		echo "$userName not found. Exiting the script."
        
	fi
	
}

####################################################################################################
#
# START OF SCRIPT
#
####################################################################################################

# Make sure that the log file is present
check_if_log_exists

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Start logging.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Redirect all output both to stdout and log file
exec > >(tee -a "$LOGFILE")

echo ""
echo "======================================================================"
logme "[START OF SCRIPT]"
echo "======================================================================"

# Get  the Management ID by reading the configProfile assigned to computer
client_management_id=$(defaults read /Library/Managed\ Preferences/ch.las.ManagementID ManagementID)
#echo "CLIENT MANAGEMENT ID: $client_management_id"

# Get JamfPro API Token
checkTokenExpiration

# Get the LAPS Username and password based on the management ID
api_url_for_laps_accounts="/api/v2/local-admin-password/$client_management_id/accounts"

uie_username=$(curl -s -H "Authorization: Bearer $access_token" "$url$api_url_for_laps_accounts" | grep -B2 JMF | awk '/username/ {print $3}'| sed 's/.*"\(.*\)".*/\1/')
echo "UIE USERNAME: $uie_username"

if [[ "$?" -eq 0 ]]

then
    
	echo "LAPS Username to be used: $uie_username"
    logme "LAPS Username to be used: $uie_username"
    
else
    
	echo "Could not get the LAPS Username. Exiting"
    logme "Could not get the LAPS Username. Exiting"
    exit 3
    
fi

api_url_uie_laps_account_password="/api/v2/local-admin-password/$client_management_id/account/$uie_username/password"
uie_laps_password=$(curl -s -H "Authorization: Bearer $access_token" "$url$api_url_uie_laps_account_password" | awk '/password/ {print $3}'| sed 's/.*"\(.*\)".*/\1/')

if [[ "$?" -eq 0 ]]

then
    
	echo "Got the LAPS Password: $uie_laps_password"
    logme "Got the LAPS Password: $uie_laps_password"
    
else
    
	echo "Could not get the LAPS Password. Exiting"
    logme "Could not get the LAPS Password. Exiting"
    exit 4
    
fi


# Check secure token status
secure_token_status=$(/usr/sbin/sysadminctl -secureTokenStatus "$userName" 2>&1 | grep -o 'ENABLED\|DISABLED')

# If the secure token is enabled, disable it using the LAPS admin credentials
if [[ "$secure_token_status" = "ENABLED" ]]
	
then
	
	logme "The secure token for $userName is enabled. Attempting to disable it."
	echo "The secure token for $userName is enabled. Attempting to disable it."

	sysadminctl -secureTokenOff "$userName" -password "$password" -adminUser "$uie_username" -adminPassword "$uie_laps_password" 2>&1 # && logme "Secure token successfully disabled." || logme "Could not disable the secure token!"

	if [[ "$?" -eq 0 ]]
    
    then
    
    	echo "Secure token successfully disabled."
        logme "Secure token successfully disabled."
    
    else
    
		echo "Could not disable the secure token!"  
        logme "Could not disable the secure token!"
        
    fi
     
else
	
    logme "Secure token is disabled. Nothing to do here."
	echo "Secure token is disabled. Nothing to do here."
	
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Now that the secure token is gone, let's remove the account and home folder
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Ensure that the script runs as root, if not exit it.
if [[ "$(id -u)" -ne 0 ]]
	
then 
	
	logme "Please run this script as root." 
    echo "Please run this script as root."
	exit 6
	
else
	
	check_if_user_account_exists_and_remove_it
	remove_home_folder
	
fi

echo "======================================================================"
logme "[END OF SCRIPT]"
echo "======================================================================"
echo ""

exit 0

####################################################################################################
#
# END OF SCRIPT
#
####################################################################################################
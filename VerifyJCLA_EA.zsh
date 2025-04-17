#!/bin/zsh --no-rcs

loggedInUser=$(stat -f%Su /dev/console)

agent=$(launchctl list | grep com.jamf.connect | awk '{print $NF}')

if [[ $agent != "" ]]; then
	echo "<result>RUNNING</result>"
else
	echo "<result>NOT RUNNING</result>"
fi
#!/bin/zsh --no-rcs

# This script returns the Next Auto-Launch Date of App Auto Patch 3.0.0 to Jamf inventory. 
# Make sure to set the Extension Attribute Data Type to "Date".
# by Steve Galloway
# 04.12.2025

# Path to the App Auto Patch working folder:
AAP_folder="/Library/Management/AppAutoPatch"

# Path to the local property list file:
AAP_plist="${AAP_folder}/xyz.techitout.appAutoPatch" # No trailing ".plist"

# Report if the App Auto Patch preference file exists.
if [[ -f "${AAP_plist}.plist" ]]; then
	AAPNextAutoLaunch=$(defaults read "${AAP_plist}" NextAutoLaunch)
	[[ -n "${AAPNextAutoLaunch}" ]] && echo "<result>${AAPNextAutoLaunch}</result>"
	[[ -z "${AAPNextAutoLaunch}" ]] && echo "<result>No Next Auto-Launch</result>"
else
	echo "<result>No AAP preference file.</result>"
fi

exit 0
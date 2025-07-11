#!/bin/bash

loopsScript="/Library/Management/Loops/Loops.sh"

if [[ -e $loopsScript ]]; then
	echo "<result>INSTALLED</result>"
else
	echo "<result>MISSING</result>"
fi

exit 0
#!/bin/bash
VERSION="21.08.29"

#SETTINGS
DISCORD_WEBHOOK_URL=""
TEAMS_WEBHOOK_URL=""
FILEFOLDER=""

#GLOBAL VARIABLES
TESTINTERNET=1
CHANGESTATUSCOUNT=3
PINGCOUNT=3
URLLIST=0
URLFILE=0
CURRENTURL=0

#
# ACTIONS
# 0 - Show help
# 1 - Show extended help
# 11 - Run Test Mode
# 12 - Run File Mode

SCRIPTACTION=0

if [ "$#" -gt 0 ]; then
	while [ True ]; do
		if [ "$1" = "--skip-internet-test" -o "$1" = "-s" ]; then
			TESTINTERNET=0
			shift 1
		elif [ "$1" = "--skip-internet-test-quietly" -o "$1" = "-S" ]; then
			TESTINTERNET=-1
			shift 1
		elif [ "$1" = "--change-status-count" -o "$1" = "-c" ]; then
			CHANGESTATUSCOUNT=$2
			shift 2
		elif [ "$1" = "--change-ping-count" -o "$1" = "-p" ]; then
			PINGCOUNT=$2
			shift 2
		elif [ "$1" = "--test" -o "$1" = "-t" ]; then
			URLLIST=$2
			SCRIPTACTION=11
			shift 2
		elif [ "$1" = "--file" -o "$1" = "-f" ]; then
			URLFILE=$2
			SCRIPTACTION=12
			shift 2
		elif [ "$1" = "--help" -o "$1" = "-h" ]; then
			SCRIPTACTION=0
			shift 1
		elif [ "$1" = "--extended-help" -o "$1" = "-H" ]; then
			SCRIPTACTION=1
			shift 1
		else
			break
		fi
	done
fi

#Nice whitespace goes here
if [ "$SCRIPTACTION" -gt 11 ]; then
	echo ""
fi

OutputHelp () {

	local HELPHEADER='
Uptime Monitor
Version:'
	HELPHEADER="$HELPHEADER $VERSION"
	local HELPTEXT='
Author: Nathan Jackson

Options:
 -s             --skip-internet-test          Skip testing the internet connection
 -S             --skip-internet-test-quietly  Skip testing the internet connection quietly
 -c             --change-status-count         Set what count if required to change status
 -p             --change-ping-count           Set how many pings are sent
 -t <URLs>      --test <URLs>                 Test URLs (comma-separated)
 -f <file>      --file <file>                 Test URLs listed in file (newline-separated)
 -h             --help                        Basic help
 -H             --extended-help               Extended help information

Example accepted URLs:
	http://example.com
	https://example.com
	ping://example.com
'

	if [ "$SCRIPTACTION" == 1 ]; then
		local EXTENDEDHELP='
Information on using files for test URLs list
 - Leading and trailing whitespace is ignored (using xargs)
 - Using # as first non-whitespace character denotes comment lines
 - You cannot comment after a URL on the same line

This script has the following software dependencies
 - bash
 - echo
 - cat
 - cut
 - awk
 - xargs
 - ping
 - curl
 - date
 - md5sum
'
		HELPTEXT="$HELPTEXT$EXTENDEDHELP"
	fi

	echo "$HELPHEADER$HELPTEXT"
}

TestInternet () {
	local RESULT=0

	if [ "$TESTINTERNET" == 1 ]; then

		echo "Testing internet connection"
		ping -c $PINGCOUNT 8.8.8.8 > /dev/null
		local GSUCCESS=$?
		ping -c $PINGCOUNT 1.1.1.1 > /dev/null
		local CSUCCESS=$?

		if [ "$GSUCCESS" == 0 ] && [ "$CSUCCESS" == 0 ]; then
			RESULT=2
			echo "Successfully pinged both Google and CloudFlare DNS"
		elif [ "$GSUCCESS" == 0 ]; then
			RESULT=1
			echo "Ping to Google DNS succeeded by CloudFlare failed"
		elif [ "$CSUCCESS" == 0 ]; then
			RESULT=1
			echo "Ping to CloudFlare DNS succeeded by Google failed"
		else
			echo "Could not ping either Google or CloudFlare DNS"
		fi
	elif [ "$TESTINTERNET" == 0 ]; then
		echo "Skipping testing internet connection"
		RESULT=3
	else
		RESULT=4
	fi

	return $RESULT
}

CreateNewFile () {
	echo "x:0:0" > "$FILE"
}

LoadFileData () {
	local RESULT=$(<"$FILE")
	echo "$RESULT"
}

ValidateData () {
	local INPUT=$1
	local VALID=0

	#echo "File data: $INPUT"

	XCOMPONENT=$(echo $INPUT| cut -d':' -f 1)
	STATUSCOMPONENT=$(echo $INPUT| cut -d':' -f 2)
	COUNTCOMPONENT=$(echo $INPUT| cut -d':' -f 3)

	#If X Component is "x" then we can safely test the data components
	if [ "$XCOMPONENT" == "x" ]; then
		if [ "$STATUSCOMPONENT" -ge 0 ] && [ "$STATUSCOMPONENT" -le 3 ]; then
			if [ "$COUNTCOMPONENT" -ge 0 ] && [ "$COUNTCOMPONENT" -lt "$CHANGESTATUSCOUNT" ]; then
				VALID=1
			fi
		fi
	fi

	return $VALID
}

UpdateFileData() {
	local STATUS=$1
	local DATETIME=`date '+%y-%m-%d %H:%M'`

	if [ "$STATUSCOMPONENT" == 0 ]; then
		echo "Setting $CURRENTURL first status"
		STATUSCOMPONENT=$STATUS
		COUNTCOMPONENT=0
	elif [ "$STATUSCOMPONENT" == "$STATUS" ] && [ "$COUNTCOMPONENT" == 0 ]; then
		echo "Status for $CURRENTURL is consistent"
	elif [ "$STATUSCOMPONENT" == "$STATUS" ] && [ "$COUNTCOMPONENT" != 0 ]; then
		echo "Status for $CURRENTURL was inconsistent"
		COUNTCOMPONENT=0
	else
		((COUNTCOMPONENT++))

		if [ "$COUNTCOMPONENT" == "$CHANGESTATUSCOUNT" ]; then
			COUNTCOMPONENT=0
			local MESSAGE_CONTENT=""
			if [ "$STATUSCOMPONENT" == 1 ]; then
				echo "Status for $CURRENTURL is being changed to up"
				MESSAGE_CONTENT="[ $DATETIME ] Status for $CURRENTURL has changed to UP"
				STATUSCOMPONENT=2
			elif [ "$STATUSCOMPONENT" == 2 ]; then
				echo "Status for $CURRENTURL is being changed to down"
				MESSAGE_CONTENT="[ $DATETIME ] Status for $CURRENTURL has changed to DOWN"
				STATUSCOMPONENT=1
			fi

			if [ "$DISCORD_WEBHOOK_URL" != "" ]; then
				curl -H "Content-Type: application/json" -d "{\"content\": \"$MESSAGE_CONTENT\"}" "$DISCORD_WEBHOOK_URL"
			fi
			if [ "$TEAMS_WEBHOOK_URL" != "" ]; then
				curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${MESSAGE_CONTENT}\"}" "$TEAMS_WEBHOOK_URL"
			fi

		else
			echo "Status for $CURRENTURL is inconsistent"
		fi
	fi

	echo "x:$STATUSCOMPONENT:$COUNTCOMPONENT" > "$FILE"
}

TestURL () {
	local PROCEED=0
	local MD5=`echo -n "$CURRENTURL" | md5sum | awk '{print $1}'`
	local FILE="$FILEFOLDER/$TESTPROTOCOL-$CURRENTDOMAIN-$MD5.status"

	echo "Processing $CURRENTURL"
	#echo "File data location: $FILE"

	if [ -f "$FILE" ]; then
		local FILEDATA=$(LoadFileData)
		ValidateData "$FILEDATA"

		if [ "$?" == 1 ]; then
			PROCEED=1
			#echo "File data exists and is valid"
		else
			CreateNewFile

			FILEDATA=$(LoadFileData)
			ValidateData "$FILEDATA"

			if [ "$?" == 1 ]; then
				PROCEED=1
				echo "$FILE was invalid but was successfully reset"
			else
				echo "$FILE is invalid and couldn't be recreated"
			fi
		fi
	else
		CreateNewFile

		local FILEDATA=$(LoadFileData)
		ValidateData "$FILEDATA"

		if [ "$?" == 1 ]; then
			PROCEED=1
			echo "$FILE did not exist but was created"
		else
			echo "$FILE did not exist and couldn't be created"
		fi
	fi

	if [ "$PROCEED" == 1 ]; then

		#if [ "$STATUSCOMPONENT" == 1 ]; then
		#	echo "$CURRENTURL state: DOWN - $COUNTCOMPONENT"
		#elif [ "$STATUSCOMPONENT" == 2 ]; then
		#	echo "$CURRENTURL state: UP - $COUNTCOMPONENT"
		#fi

		#echo "Testing $CURRENTURL"
		#echo "Protocol is $TESTPROTOCOL"

		if [ "$TESTPROTOCOL" == "ping" ]; then
			ping -c $PINGCOUNT "$CURRENTDOMAIN" > /dev/null
			local PINGCODE=$?

			if [ "$PINGCODE" == 0 ]; then
				echo "$CURRENTURL pinged successfully"
				UpdateFileData 2
			else
				echo "$CURRENTURL could not be pinged with an exit code of $PINGCODE"
				UpdateFileData 1
			fi

		elif [ "$TESTPROTOCOL" == "http" -o "$TESTPROTOCOL" == "https" ]; then

			local HTTPCODE=$(curl -s -o /dev/null -w "%{http_code}" $CURRENTURL)
			local CURLCODE=$?

			if [ "$HTTPCODE" == 200 ] && [ "$CURLCODE" == 0 ]; then
				echo "$CURRENTURL test was success"
				UpdateFileData 2
			else
				echo "$CURRENTURL test failed with HTTP code of $HTTPCODE and curl exit code of $CURLCODE"
				UpdateFileData 1
			fi
		fi
	else
		echo "$CURRENTURL test cannot proceed due to file data issues"
	fi
}

ProcessURL () {
	#Janky but does the trick
	TESTPROTOCOL=$(echo $CURRENTURL| cut -d':' -f 1)
	CURRENTDOMAIN=$(echo $CURRENTURL| cut -d'/' -f 3)
	CURRENTDOMAIN=$(echo $CURRENTDOMAIN| cut -d':' -f 1)

	#TODO ADD SOME LOGIC TO MAKE SURE THE URL IS VALID ENOUGH
}

Main() {
	if [ "$SCRIPTACTION" -gt 10 ]; then
		TestInternet
		local INTERNETSTATUS=$?

		if [ "$INTERNETSTATUS" -gt 0 ]; then

			if [ "$SCRIPTACTION" = 11 ]; then

				local URLCOUNT="${URLLIST//[^,]}" #Strip out the delimiters
				URLCOUNT="${#URLCOUNT}" #Count the delimiters
				((URLCOUNT++)) #Adjust the count

				if [ "$URLCOUNT" -gt 1 ]; then
					for ((INDEX = 1 ; INDEX <= URLCOUNT ; INDEX++)); do
						CURRENTURL=$(echo $URLLIST| cut -d',' -f $INDEX | xargs)
						eval "$0 --skip-internet-test-quietly --test \"$CURRENTURL\" &"
					done
				else
					CURRENTURL=$(echo "$URLLIST" | xargs)
					ProcessURL
					TestURL
				fi

				#Wait for evals to complete
				wait

			elif [ "$SCRIPTACTION" = 12 ]; then

				#Set to separate based on newline
				IFS=$'\n'

				#Read each line in file
				for CURRENTURL in `cat "$URLFILE"`; do

					#Trim whitespace
					CURRENTURL=$(echo "$CURRENTURL" | xargs)

					#Skip blanks
					if [ "$CURRENTURL" != "" ]; then
						#Cut the first character
						local CHAR=`echo "$CURRENTURL" | cut -c 1`
						if [ "$CHAR" != "#" ]; then
							echo -n ""
							eval "$0 --skip-internet-test-quietly --test \"$CURRENTURL\" &"
						fi
					fi
				done

				#Wait for evals to complete
				wait

				#Some nice whitespace
				echo ""

			fi
		else
			echo "Cannot proceed due to internet test failing"
		fi
	else
		OutputHelp
	fi
}

Main

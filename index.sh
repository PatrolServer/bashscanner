#!/usr/bin/env bash

MY_HOME="https://demo.patrolserver.com"

. env.sh
. json.sh
. api.sh
. args.sh
. scanners/composer.sh
. scanners/dpkg.sh
. scanners/drupal.sh

VERSION="1.0.0"
EMAIL=""
PASSWORD=""
HOSTNAME=""
KEY=""
SECRET=""
CMD="false"
SERVER_ID=""
BUCKET="BashScanner"
LOCATE=`mktemp`

function Start {
	SetEnv
	EnvFile
	Args "$@"

	if [ "$CMD" == "false" ] 
	then
		echo "> Hi $USER,"
		echo "> PatrolServer.com at your service. "
		echo "> I'm starting..."
		echo ""
	fi

	DetermineHostname
	if [ "$KEY" == "" ] || [ "$SECRET" == "" ]
	then	
		Account
	fi

	DetermineServer
	Scan
	Output

	if [ "$CMD" == "false" ]
	then
		Cronjob
	fi

	echo "> Have a nice day!"
}

function Login {
	if [ "$CMD" == "false" ] && [ "$EMAIL" == "" ] && [ "$PASSWORD" == "" ]
	then
		for I in 1 2 3
		do
			echo -en "\tYour email: "
			read EMAIL
			echo -en "\tYour password: "
			read -s PASSWORD
			echo "";

			LOGIN_RET=(`ApiUserLogin $EMAIL $PASSWORD`)

			local LOGIN_CRITICAL=${LOGIN_RET[0]}
			local LOGIN_TYPE=${LOGIN_RET[1]}
			local LOGIN_AUTHED=${LOGIN_RET[2]}
			local LOGIN_ERRORS=${LOGIN_RET[3]}
			local LOGIN_USER=${LOGIN_RET[4]}

			if [ $LOGIN_AUTHED == "true" ]
			then
				return
			elif [ $LOGIN_CRITICAL == "true" ]
			then
				echo "> Your login was blocked for security issues, a mail was send to unblock yourself. After clicking on the link, you can try again." >&2
			elif [ $LOGIN_TYPE == '"to_much_tries"' ]
			then
				echo "> Your login was blocked for security issues, please try again in 10 min." >&2
				exit 77
			else
				echo "> Wrong email and/or password! Try again." >&2
			fi
		done
		echo "> Invalid login";

	else
		if [ "$EMAIL" == "" ]
		then
			echo "Specify login credentials" >&2
			exit 77
		fi

		if [ "$PASSWORD" == "" ]
		then
			echo "Specify login credentials" >&2
			exit 77
		fi

		LOGIN_RET=(`ApiUserLogin $EMAIL $PASSWORD`)

		local LOGIN_CRITICAL=${LOGIN_RET[0]}
		local LOGIN_TYPE=${LOGIN_RET[1]}
		local LOGIN_AUTHED=${LOGIN_RET[2]}
		local LOGIN_ERRORS=${LOGIN_RET[3]}
		local LOGIN_USER=${LOGIN_RET[4]}

		if [ $LOGIN_AUTHED == "true" ]
		then
			return
		elif [ $LOGIN_CRITICAL == "true" ]
		then
			echo "Your login was blocked for security issues (Unblock mail send)." >&2
			exit 77
		elif [ $LOGIN_TYPE == '"to_much_tries"' ]
		then
			echo "Your login was blocked for security issues (Unblock mail send)" >&2
			exit 77
		else
			echo "Login credentials incorrect" >&2
			exit 77
		fi
	fi

  	exit 77;
}

function Register {
	REGISTER_RET=(`ApiUserRegister $EMAIL $PASSWORD`)

	local REGISTER_AUTHED=${REGISTER_RET[0]}
	local REGISTER_ERRORS=${REGISTER_RET[1]}
	local REGISTER_USER=${REGISTER_RET[2]}

	if [ $REGISTER_AUTHED == "true" ]
	then
		echo "success"
		return
	else
		if [[ "$REGISTER_ERRORS" =~ "The email has already been taken" ]]
		then
			echo "email"
			return
		fi

  		echo "> Unexpected error occured." >&2
  		exit 77;
	fi
}

function TestHostname {
	OPEN_PORT_53=`echo "quit" | timeout 1 telnet 8.8.8.8 53 2> /dev/null |  grep "Escape character is"`
	if [[ "$OPEN_PORT_53" != "" ]]
	then
		EXTERNAL_IP=`dig +time=1 +tries=1 +retry=1 +short myip.opendns.com @resolver1.opendns.com`
		IP=`dig @8.8.8.8 +short $HOSTNAME`
	else
		EXTERNAL_IP=`wget -qO- icanhazip.com`
		IP=`host "$HOSTNAME" | cut -d' ' -f4`
	fi
}

function Hostname {

	if [[ "$HOSTNAME" == "" ]]
	then
		HOSTNAME=`hostname -f 2> /dev/null`
	fi

	if [[ "$HOSTNAME" != "" ]]
	then
		TestHostname
	fi
	
	if [[ "$CMD" != "false" ]] 
	then
		if [ "$IP" == "" ]
		then
			echo "Hostname not found (Please enter with command)" >&2
			exit 77;
		elif [[ $IP != $EXTERNAL_IP ]]
		then
			echo "Hostname doesn't resolve to external IP of this server" >&2
			exit 77;
		fi
	fi

	for I in 1 2 3
	do
		
		if [ "$IP" == "" ]
		then
			echo "> Could not determine your hostname."
			echo -en "\tPlease enter the hostname of this server: "
			read HOSTNAME
			echo "";
		elif [[ $IP != $EXTERNAL_IP ]]
		then
			echo "> Your hostname ($HOSTNAME) doesn't resolve to this IP."
			echo -en "\tPlease enter the hostname that resolved to this ip: "
			read HOSTNAME
			echo "";
		fi

		TestHostname
		
		if [[ "$IP" != "" ]] && [ "$IP" == "$EXTERNAL_IP" ]
		then 
			return;
		fi
	done

	echo "> Could not determine hostname"  >&2
  	exit 77;
}

function GetKeySecret {
	if [[ "$KEY" != "" ]] && [[ "$SECRET" != "" ]]
	then
		return
	fi

	# Get the first KEY/SECRET combo
	KEY_SECRET_RET=(`ApiKeySecret`)

	KEY=${KEY_SECRET_RET[0]}
	SECRET=${KEY_SECRET_RET[1]}

	# API access isn't created yet, so create.
	if [[ "$KEY" == "false" ]] || [[ "$SECRET" == "false" ]]
	then	
		ApiCreateKeySecret > /dev/null

		KEY_SECRET_RET=(`ApiKeySecret`)

		KEY=${KEY_SECRET_RET[0]}
		SECRET=${KEY_SECRET_RET[1]}
	fi

	if [ "$KEY" == "false" ]
	then
		echo "> Internal error, could not get key/secret combo" >&2
		exit 77
	fi

	if [ "$SECRET" == "false" ]
	then
		echo "> Internal error, could not get key/secret combo" >&2
		exit 77
	fi
}

function DetermineHostname {

	Hostname

	if [ "$EMAIL" == "" ] && [ "$PASSWORD" == "" ] && [ "$KEY" == "" ] && [ "$SECRET" == "" ]
	then
		# Check if the host is already in our DB
		# Please note! You can remove this check, but our policy doesn't change.
		# Only one free server per domain is allowed.
		# We actively check for these criteria
		SERVER_EXISTS_RET=(`ApiServerExists $HOSTNAME`)

		SERVER_EXISTS=${SERVER_EXISTS_RET[0]}
		SERVER_EXISTS_ERROR_TYPE=${SERVER_EXISTS_RET[1]}
		SERVER_EXISTS_ERRORS=${SERVER_EXISTS_RET[2]}
		
		if [ "$SERVER_EXISTS_ERROR_TYPE" == "false" ]
		then
			return

		# There is already an host from this user.
		elif [ "$SERVER_EXISTS_ERROR_TYPE" == "1" ]
		then
			echo "> An account was already created for this host or a subdomain of this host. Please login into your patrolserver.com account or add the key/secret when calling this command." >&2
			Login
			GetKeySecret

		# Hostname could not be found.
		elif [ "$SERVER_EXISTS_ERROR_TYPE" == "2" ]
		then
			echo "> Your hostname ($HOSTNAME) doesn't resolve to this IP ($IP)." >&2
	  		exit 77;
	  	# Undefined error occured.
		else
	  		echo "> Unexpected error occured." >&2
	  		exit 77;
		fi
	fi	
}

function Account {

	if [[ "$EMAIL" != "" ]] && [[ "$PASSWORD" != "" ]]
	then
		Login
		GetKeySecret
		return;
	fi
	
	if [[ "$CMD" != "false" ]] 
	then
		YN="n"
	else
		echo "> You can use this tool 5 times without account." 
	
		YN="..."
		while [[ $YN != "n" ]] && [[ $YN != "y" ]]; do
			read -p "> Do you want to create an account (y/n)? " YN
	 	done
	 fi

 	if [ $YN == "n" ]
 	then
		# Create account when no account exists.
		EMAIL="tmp-`Random`@$HOSTNAME"
		PASSWORD=`Random`

		REGISTER_RET=`Register $EMAIL $PASSWORD`
		if [ "$REGISTER_RET" != "success" ]
		then
			echo "> Internal error, could not create temporary account"
			exit 77
		fi

		GetKeySecret

	else
		for I in 1 2 3
		do
		
			# Ask what account should be created.
			echo -en "\tYour email: "
			read EMAIL
			echo -en "\tNew password: "
			read -s PASSWORD
			echo ""
			echo -en "\tRetype your password: "
			read -s PASSWORD2
			echo "";

			REGISTER_RET=""
			if [ "$PASSWORD" == "$PASSWORD2" ] && [ ${#PASSWORD} -ge 7 ]
			then
				REGISTER_RET=`Register $EMAIL $PASSWORD`
				if [ "$REGISTER_RET" == "success" ]
				then
					GetKeySecret
					return
				fi
			fi

			if [ ${#PASSWORD} -le 6 ]
			then 
				echo "> Password should minimal contain 6 characters" >&2
			fi

			if [ "$PASSWORD" != "$PASSWORD2" ]
			then
				echo "> The password confirmation does not match" >&2
			fi

			if [ "$REGISTER_RET" == "email" ]
			then
				echo "> Account already exists with this account. Use command with email and password parameters." >&2
				exit 77
			fi


		done

		echo "> Account could not be created." >&2
		exit 77
	fi
}

function DetermineServer {
	SERVERS_RET=(`ApiServers $KEY $SECRET`)
	SERVERS_ERRORS=${SERVERS_RET[0]}
	SERVERS=${SERVERS_RET[1]}

	HAS_SERVER=`echo $SERVERS | json | grep -P '^\[[0-9]*,"name"\]\t"'$HOSTNAME'"'`

	# Check if the server has already been created
	if [ "$HAS_SERVER" == "" ]
	then

		SERVER_CREATE_RET=(`ApiServerCreate $KEY $SECRET $HOSTNAME`)
		SERVER_CREATE_ERRORS=${SERVER_CREATE_RET[0]}

		if [[ "$SERVER_CREATE_ERRORS" =~ "You exceeded the maximum allowed server slots" ]]
		then
			echo "> You exceeded the maximum allowed servers on your account, please login onto http://patrolserver.com and upgrade your account";
			exit 77;
		fi

		SERVERS_RET=(`ApiServers $KEY $SECRET`)
		SERVERS_ERRORS=${SERVERS_RET[0]}
		SERVERS=${SERVERS_RET[1]}

		HAS_SERVER=`echo $SERVERS | json | grep -P '^\[[0-9]*,"name"\]\t"'$HOSTNAME'"' -o`
	fi
	
	if [ "$HAS_SERVER" == "" ]
	then
		echo "> Internal error, could not create the server online" >&2
		exit 77
	fi

	SERVER_ARRAY_ID=`echo $HAS_SERVER | grep -P '^\[[0-9]*' -o | grep -P '[0-9]*' -o`
	SERVER_ID=`echo $SERVERS | json | grep "^\[$SERVER_ARRAY_ID,\"id\"\]" | cut -f2-`
	SERVER_VERIFIED=`echo $SERVERS | json | grep "^\[$SERVER_ARRAY_ID,\"verified\"\]" | cut -f2-`

	# Check if the server has already been verified
	if [ "$SERVER_VERIFIED" == "false" ]
	then
		SERVER_TOKEN_RET=(`ApiServerToken $HOSTNAME`)
		SERVER_TOKEN_ERRORS=${SERVER_TOKEN_RET[0]}
		SERVER_TOKEN=${SERVER_TOKEN_RET[1]}

		SERVER_VERIFY_RET=(`ApiVerifyServer $KEY $SECRET $SERVER_ID $SERVER_TOKEN`)
		SERVER_TOKEN_ERRORS=${SERVER_VERIFY_RET[0]}
	fi	
}

function Scan {
	if [[ "$CMD" == "false" ]] 
	then
		echo "> Searching for packages, can take some time..."
	fi

	SOFTWARE=`mktemp`
	
	# Update db
	updatedb -o "$LOCATE" -U / --require-visibility 0 2> /dev/null

	# Do all scanners
	ComposerSoftware
	DpkgSoftware
	DrupalSoftware

	if [[ "$CMD" == "false" ]] 
	then
	 	echo "> Scanning for newest releases and exploits, can take serveral minutes..."
	 	echo "> Take a coffee brake ;) "
	fi

 	SOFTWARE_PUST_RET=(`ApiServerPush $KEY $SECRET $SERVER_ID $BUCKET $SOFTWARE`)
 	SOFTWARE_PUST_ERRORS=${SOFTWARE_PUST_RET[0]}

 	if [ "$SOFTWARE_PUST_ERRORS" != "false" ]
 	then
 		echo "> Could not upload software data, please give our support team a call with the following details" >&2
 		echo $SOFTWARE_PUST_ERRORS >&2
 		exit 77
 	fi

 	SERVER_SCAN_RET=(`ApiServerScan $KEY $SECRET $SERVER_ID`)
 	SERVER_SCAN_ERRORS=${SERVER_SCAN_RET[0]}

 	if [ "$SERVER_SCAN_ERRORS" != "false" ]
 	then
 		echo "> Could not send scan command, please give our support team a call with the following details" >&2
 		echo $SERVER_SCAN_ERRORS >&2
 		exit 77
 	fi

 	SERVER_SCANNING="true"
 	while [ "$SERVER_SCANNING" == "true" ] ; do
	 	SERVER_SCANNING_RET=(`ApiServerIsScanning $KEY $SECRET $SERVER_ID`)
	 	SERVER_SCANNING_ERRORS=${SERVER_SCANNING_RET[0]}
		SERVER_SCANNING=${SERVER_SCANNING_RET[1]}

		if [[ "$CMD" == "false" ]] 
		then
			echo -n "."
		fi

		sleep 5
	done

	if [[ "$CMD" == "false" ]] 
	then
		echo "";
	fi
}

function Output {
	if [[ "$CMD" == "false" ]] 
	then
		echo "> Software versions has been retrieved (Solutions for the exploits can be seen on our web interface):"
	fi

	SOFTWARE_RET=(`ApiSoftware $KEY $SECRET $SERVER_ID`)
	SOFTWARE_ERRORS=${SOFTWARE_RET[0]}
	SOFTWARE_JSON=${SOFTWARE_RET[1]}

	SOFTWARE=`echo $SOFTWARE_JSON | json | grep -P "^\[[0-9]{1,}\]" | cut -f2-`
	if [ "$SOFTWARE" == "" ]
	then
		echo -e "\tStrangely, No packages were found..."
	fi 
	for LINE in $SOFTWARE; do
		LINE=`echo $LINE | json`

		ID=`echo "$LINE" | grep '^\["id"\] | cut -f2-'`
		NAME=`echo "$LINE" | grep '^\["name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		VERSION=`echo "$LINE" | grep '^\["version"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		VERSIONS=`echo "$LINE" | grep '^\["versions"\]' | cut -f2-`
		NEW_VERSION=`echo "$LINE" | grep '^\["newest_bugfix_release"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		SUPPORTED=`echo "$LINE" | grep '^\["supported"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		EXPLOITS=`echo "$LINE" | grep '^\["exploits"\]' | cut -f2- | json | grep '^\[[0-9]*,"risk"\]' | cut -f2-`

		if [ "$VERSIONS" != "" ]
		then
			VERSION=`echo $VERSIONS | json | grep '^\[0]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
			VERSION=`echo "<=$VERSION"`
		fi

		echo -ne "\t$NAME: "

		# Print current version
		if [ "$VERSION" == "" ]
		then
			echo -n "version not detected"
		elif [ "$SUPPORTED" == "yes" ]
		then
			echo -ne "\e[0;32m"
			echo -n $VERSION
			echo -ne "\e[0m"
		elif [[ "$NEW_VERSION" != "" ]]
	    then
			echo -ne "\e[0;33m"
			echo -n $VERSION
			echo -ne "\e[0m"
			echo -n ", update to "
			echo -ne "\e[0;32m"
			echo -n $NEW_VERSION
			echo -ne "\e[0m"
		else
			echo -ne "\e[0;31m"
			echo -n $VERSION
			echo -ne "\e[0m"
			echo -n ", not supported anymore"
		fi

		# Check exploits
		COUNT_EXPLOITS=0
		for EXPLOIT in $EXPLOITS; do
			IS_BIGGER=`echo "$EXPLOIT" | grep "^[5-9]"`
			if [[ "$IS_BIGGER" != "" ]]
			then
				COUNT_EXPLOITS=$((COUNT_EXPLOITS+1)) 
			fi
		done

		if [ "$COUNT_EXPLOITS" != "0" ]
		then
			echo -ne "\e[0;31m"
			echo -n " ($COUNT_EXPLOITS exploits)"
			echo -ne "\e[0m"
		fi

		echo ""
	done
}

function Cronjob {

	# User has already a cronjob defined
	HAS_CRONTAB=`crontab -l 2> /dev/null | grep "patrolserver"`
	if [ "$HAS_CRONTAB" != "" ]
	then
		return
	fi

	if [[ "$CMD" != "false" ]] 
	then
		return
	fi

	# Check if user want a cronjob
	YN="..."
	while [[ $YN != "n" ]] && [[ $YN != "y" ]]; do
		read -p "> It is advisable to check your server daily, should we set a cronjob (y/n)? " YN
 	done

	if [ $YN == "n" ]
	then
		if [[ "$EMAIL" == tmp\-* ]]
		then
			ApiUserRemove $KEY $SECRET
		fi

	else

		if [[ "$EMAIL" == tmp\-* ]]
		then
			echo -n "> What is your email address to send reports to? "
			read REAL_EMAIL
			echo ""

			CHANGE_EMAIL_RET=(`ApiUserChange $KEY $SECRET $REAL_EMAIL`)
			CHANGE_EMAIL_ERRORS=${CHANGE_EMAIL_RET[0]}
			CHANGE_EMAIL_SUCCESS=${CHANGE_EMAIL_RET[1]}

			if [ "$CHANGE_EMAIL_SUCCESS" == "false" ]
			then
			    if [[ $CHANGE_EMAIL_ERRORS =~ "The email has already been taken." ]] 
			    then
			        echo "> There is already an account with this emailadress, use this tool with email and password parameters." >&2
				    exit 77
			    fi
			    
				echo "> Internal error when changing username" >&2
				exit 77
			fi
		fi

		mkdir ~/.patrolserver 2> /dev/null
	    echo -e "HOSTNAME=$HOSTNAME\nKEY=$KEY\nSECRET=$SECRET" > ~/.patrolserver/env
	    cat $LOCATE > ~/.patrolserver/locate.db
	    wget -O ~/.patrolserver/patrolserver "https://raw.githubusercontent.com/PatrolServer/bashScanner/master/patrolserver" 2&>1 /dev/null
	    chmod +x ~/.patrolserver/patrolserver

	    # Set cronjob
	    CRON_TMP=`mktemp`
		crontab -l 2> /dev/null > $CRON_TMP
		CRON_HOUR=$[ RANDOM % 24 ]
		CRON_MINUTE=$[ RANDOM % 60 ]
		echo "$CRON_MINUTE $CRON_HOUR * * * $HOME/.patrolserver/patrolserver --cmd --key=$KEY --secret=$SECRET --hostname=$HOSTNAME" >> $CRON_TMP
		crontab $CRON_TMP

	    echo "> cronjob was set."

	    if [[ "$EMAIL" == tmp\-* ]]
		then
			echo "> Your login on patrolserver.com:"
			echo -e "\tlogin: $REAL_EMAIL"
			echo -e "\tpassword: $PASSWORD"
		fi

		echo "> A environment file was created on ~/.patrolserver, so you don't have to call it anymore with the key and secret"
	fi
}

Start "$@"

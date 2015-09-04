#!/usr/bin/env bash

COOKIES=`mktemp`
POSTFILE=`mktemp`

function ApiUserRegister {
	local EMAIL=`Urlencode $1`
	local PASSWORD=`Urlencode $2`

	local OUTPUT=`wget -t2 -T2 --keep-session-cookies --save-cookies $COOKIES -qO- "${MY_HOME}/api/user/register" --post-data "email=$EMAIL&password=$PASSWORD&password_confirmation=$PASSWORD"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (1)" >&2
		exit 77
	fi

	local AUTHED=`echo "$OUTPUT" | json | grep '^\["authed"\]' | cut -f2-`
	local ERRORS=`echo "$OUTPUT" | json | grep '^\["errors",[0-9]\]' | cut -f2-`
	local USER=`echo "$OUTPUT" | json | grep '^\["user"\]' | cut -f2-`

	echo ${AUTHED:-false}
	echo ${ERRORS:-false}
	echo ${USER:-false}
}

function ApiUserLogin {
	local EMAIL=`Urlencode $1`
	local PASSWORD=`Urlencode $2`

	local OUTPUT=`wget -t2 -T4 --keep-session-cookies --save-cookies $COOKIES -qO- "${MY_HOME}/api/user/login" --post-data "email=$EMAIL&password=$PASSWORD"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (2)" >&2
		exit 77
	fi

	local AUTHED=`echo "$OUTPUT" | json | grep '^\["authed"\]' | cut -f2-`
	local ERRORS=`echo "$OUTPUT" | json | grep '^\["errors",[0-9]\]' | cut -f2-`
	local USER=`echo "$OUTPUT" | json | grep '^\["user"\]' | cut -f2-`
	local CRITICAL=`echo "$OUTPUT" | json | grep '^\["critical"\]' | cut -f2-`
	local TYPE=`echo "$OUTPUT" | json | grep '^\["type"\]' | cut -f2-`

	echo ${CRITICAL:-false}
	echo ${TYPE:-false}
	echo ${AUTHED:-false}
	echo ${ERRORS:-false}
	echo ${USER:-false}
}

function ApiServerExists {
	local HOST=`Urlencode $1`

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/api/server/exists?host=$HOST"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (3)" >&2
		exit 77
	fi

	local ERRORS=`echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-`
	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-  | sed -e 's/^"//'  -e 's/"$//'`
	local EXISTS=`echo "$OUTPUT" | json | grep '^\["exists"\]' | cut -f2-`

	echo ${EXISTS:-false}
	echo ${ERROR:-false}
	echo ${ERRORS:-false}
}

function ApiServerCreate {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local HOSTNAME=`Urlencode $3`
	
	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET" --post-data "domain=$HOSTNAME"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (4)" >&2
		exit 77
	fi

	local ID=`echo "$OUTPUT" | json | grep '^\["data","id"\]' | cut -f2-`
	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
	echo ${ID:-false}
}	

function ApiServerToken {
	local HOSTNAME=`Urlencode $1`
	
	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/request_verification_token?domain=$HOSTNAME"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (5)" >&2
		exit 77
	fi

	local TOKEN=`echo "$OUTPUT" | json | grep '^\["data","token"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
	echo ${TOKEN:-false}
}	

function ApiVerifyServer {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local SERVER_ID=`Urlencode $3`
	local TOKEN=`Urlencode $4`
	
	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/verify?key=$KEY&secret=$SECRET" --post-data "token=$TOKEN"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (6)" >&2
		exit 77
	fi

	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
}	
	
function ApiServerPush {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local SERVER_ID=`Urlencode $3`
	local BUCKET=`Urlencode $4`
	local EXPIRE="129600"

	echo -n "expire=$EXPIRE&software=" > $POSTFILE
	cat $SOFTWARE | sort | uniq | awk 'BEGIN { RS="\n"; FS="\t"; print "["; prevLocation="---"; prevName="---"; prevVersion="---"; prevParent="---";} 
		{ 
			if($1 == prevLocation){ $1=""; } else { prevLocation = $1; $1 = "\"l\":\""$1"\"," }; 
			if($2 == prevParent){ $2=""; } else { prevParent = $2; $2 = "\"p\":\""$2"\"," }; 
			if($3 == prevName){ $3=""; } else { prevName = $3; $3 = "\"n\":\""$3"\"," }; 
			if($4 == prevVersion){ $4=""; } else { prevVersion = $4; $4 = "\"v\":\""$4"\"," }; 
			line = $1$2$3$4; 
			line = substr(line, 0, length(line)-1)
			print "{"line"},"; 
		} 
		END { print "{}]"; }' >> $POSTFILE

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/software_bucket/$BUCKET?key=$KEY&secret=$SECRET&scope=silent" --post-file $POSTFILE`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (7)" >&2
		exit 77
	fi

	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
}

function ApiKeySecret {

	local OUTPUT=`wget -t2 -T2 --load-cookies $COOKIES -qO- "${MY_HOME}/api/user/api_credentials"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (8)" >&2
		exit 77
	fi

	local KEY=`echo "$OUTPUT" | json | grep '^\[0,"key"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	local SECRET=`echo "$OUTPUT" | json | grep '^\[0,"secret"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`

	echo ${KEY:-false}
	echo ${SECRET:-false}
}

function ApiCreateKeySecret {
	local OUTPUT=`wget -t2 -T2 --load-cookies $COOKIES -qO- "${MY_HOME}/api/user/api_credentials" --post-data "not=used"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (9)" >&2
		exit 77
	fi
}

function ApiServers {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (10)" >&2
		exit 77
	fi

	local SERVERS=`echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-`
	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
	echo ${SERVERS:-false}
}

function ApiSoftware {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local SERVER_ID=`Urlencode $3`

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/software?key=$KEY&secret=$SECRET&scope=exploits"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (11)" >&2
		exit 77
	fi

	local SOFTWARE=`echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-`
	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
	echo ${SOFTWARE:-false}
}

function ApiServerScan {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local SERVER_ID=`Urlencode $3`

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/scan?key=$KEY&secret=$SECRET"  --post-data "not=used"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (12)" >&2
		exit 77
	fi

	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
}

function ApiServerIsScanning {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local SERVER_ID=`Urlencode $3`

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/isScanning?key=$KEY&secret=$SECRET"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (13	)" >&2
		exit 77
	fi

	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`
	local SCANNING=`echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-`

	echo ${ERROR:-false}
	echo ${SCANNING:-false}
}

function ApiUserChange {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`
	local EMAIL=`Urlencode $3`

	local OUTPUT=`wget -t2 -T2 -qO- "${MY_HOME}/extern/api/user/update?key=$KEY&secret=$SECRET" --post-data "email=$EMAIL"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (13	)" >&2
		exit 77
	fi

	local ERRORS=`echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-`
	local SUCCESS=`echo "$OUTPUT" | json | grep '^\["success"\]' | cut -f2-`

	echo ${ERRORS:-false}
	echo ${SUCCESS:-false}
}

function Urlencode {
	local STRING="${1}"
	local STRLEN=${#STRING}
	local ENCODED=""

	for (( pos=0 ; pos<STRLEN ; pos++ )); do
		c=${STRING:$pos:1}
		case "$c" in
			[-_.~a-zA-Z0-9] ) o="${c}" ;;
			* )               printf -v o '%%%02x' "'$c"
		esac
		ENCODED+="${o}"
	done

	echo ${ENCODED:-false}
}

function Jsonspecialchars {
	echo $1 | sed "s/'/\\\\\'/g"
}
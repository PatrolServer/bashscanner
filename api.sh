#!/usr/bin/env bash

COOKIES=$(mktemp)
POSTFILE=$(mktemp)

function ApiUserRegister {
	local EMAIL
	local PASSWORD
	local OUTPUT
	local ERROR
	local USER
	local KEY
	local SECRET

	EMAIL=$(Urlencode "$1")
	PASSWORD=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/users" --post-data "email=$EMAIL&password=$PASSWORD&password_confirmation=$PASSWORD")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (1)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)
	USER=$(echo "$OUTPUT" | json | grep '^\["data","user"\]' | cut -f2-)
	KEY=$(echo "$OUTPUT" | json | grep '^\["data","api_credentials","key"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	SECRET=$(echo "$OUTPUT" | json | grep '^\["data","api_credentials","secret"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')

	echo "${ERROR:-false}"
	echo "${USER:-false}"
	echo "${KEY:-false}"
	echo "${SECRET:-false}"
}

function ApiUserLogin {
	local EMAIL
	local PASSWORD
	local OUTPUT
	local ERROR
	local USER
	local KEY
	local SECRET

	EMAIL=$(Urlencode "$1")
	PASSWORD=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/api/user/request_api_credentials" --post-data "email=$EMAIL&password=$PASSWORD")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (2)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error","code"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	USER=$(echo "$OUTPUT" | json | grep '^\["user"\]' | cut -f2-)
	KEY=$(echo "$OUTPUT" | json | grep '^\["api_credentials","key"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	SECRET=$(echo "$OUTPUT" | json | grep '^\["api_credentials","secret"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')

	echo "${ERROR:-false}"
	echo "${USER:-false}"
	echo "${KEY:-false}"
	echo "${SECRET:-false}"
}

function ApiServerExists {
	local HOST
	local OUTPUT
	local ERROR
	local EXISTS

	HOST=$(Urlencode "$1")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/serverExists?host=$HOST")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (3)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error","code"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	EXISTS=$(echo "$OUTPUT" | json | grep '^\["exists"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${EXISTS:-false}"
}

function ApiServerCreate {
	local KEY
	local SECRET
	local HOSTNAME
	local OUTPUT
	local ID
	local ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	HOSTNAME=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET" --post-data "domain=$HOSTNAME")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (4)" >&2
		exit 77
	fi

	ID=$(echo "$OUTPUT" | json | grep '^\["data","id"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${ID:-false}"
}

function ApiServerToken {
	local HOSTNAME
	local OUTPUT
	local TOKEN
	local ERROR

	HOSTNAME=$(Urlencode "$1")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/request_verification_token?domain=$HOSTNAME")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (5)" >&2
		exit 77
	fi

	TOKEN=$(echo "$OUTPUT" | json | grep '^\["data","token"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${TOKEN:-false}"
}

function ApiVerifyServer {
	local KEY
	local SECRET
	local SERVER_ID
	local TOKEN
	local OUTPUT
	local ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")
	TOKEN=$(Urlencode "$4")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/verify?key=$KEY&secret=$SECRET" --post-data "token=$TOKEN")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (6)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
}

function ApiServerPush {
	local KEY
	local SECRET
	local SERVER_ID
	local BUCKET
	local EXPIRE
	local OUTPUT
	local ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")
	BUCKET=$(Urlencode "$4")
	EXPIRE="129600"

	echo -n "expire=$EXPIRE&software=" > "$POSTFILE"

	SOFTWARE=$(sort < "$SOFTWARE" | uniq | awk 'BEGIN { RS="\n"; FS="\t"; print "["; prevLocation="---"; prevName="---"; prevVersion="---"; prevParent="---";}
		{
			if($1 == prevLocation){ $1=""; } else { prevLocation = $1; $1 = "\"l\":\""$1"\"," };
			if($2 == prevParent){ $2=""; } else { prevParent = $2; $2 = "\"p\":\""$2"\"," };
			if($3 == prevName){ $3=""; } else { prevName = $3; $3 = "\"n\":\""$3"\"," };
			if($4 == prevVersion){ $4=""; } else { prevVersion = $4; $4 = "\"v\":\""$4"\"," };
			line = $1$2$3$4;
			print "{"line"},";
		}
		END { print "{}]"; }' | sed 's/,},/},/' | tr -d '\n')
	SOFTWARE=$(Urlencode "$SOFTWARE")

	echo "$SOFTWARE" >> "$POSTFILE"

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/buckets/$BUCKET?key=$KEY&secret=$SECRET&scope=silent" --post-file $POSTFILE)

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (7)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
}

function ApiServers {
	local KEY
	local SECRET
	local OUTPUT
	local SERVERS
	local ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (10)" >&2
		exit 77
	fi

	SERVERS=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${SERVERS:-false}"
}

function ApiSoftware {
	local KEY
	local SECRET
	local SERVER_ID
	local OUTPUT
	local SOFTWARE
	local ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/software?key=$KEY&secret=$SECRET&scope=exploits")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (11)" >&2
		exit 77
	fi

	SOFTWARE=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${SOFTWARE:-false}"
}

function ApiServerScan {
	local KEY
	local SECRET
	local SERVER_ID
	local OUTPUT
	local ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/scan?key=$KEY&secret=$SECRET"  --post-data "not=used")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (12)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
}

function ApiServerIsScanning {
	local KEY
	local SECRET
	local SERVER_ID
	local OUTPUT
	local ERROR
	local SCANNING

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/isScanning?key=$KEY&secret=$SECRET")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (13)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)
	SCANNING=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${SCANNING:-false}"
}

function ApiUserChange {
	local KEY
	local SECRET
	local EMAIL
	local OUTPUT
	local ERROR
	local USER

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	EMAIL=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/user?key=$KEY&secret=$SECRET" --post-data "email=$EMAIL")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (14)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error","code"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	USER=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${USER:-false}"
}

function ApiUserRemove {
	local KEY
	local SECRET
	local OUTPUT

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 --header="X-PS-Bash: 1" -qO- "${MY_HOME}/extern/api/user/delete?key=$KEY&secret=$SECRET" --post-data "not=used")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (15)" >&2
		exit 77
	fi

	#ERRORS=$(echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-)
	#SUCCESS=$(echo "$OUTPUT" | json | grep '^\["success"\]' | cut -f2-)

	#echo "${ERRORS:-false}"
	#echo "${SUCCESS:-false}"
}

URLENCODE_SED=$(mktemp)
cat > $URLENCODE_SED <<- EOF
s:%:%25:g
s: :%20:g
s:<:%3C:g
s:>:%3E:g
s:#:%23:g
s:{:%7B:g
s:}:%7D:g
s:|:%7C:g
s:\^:%5E:g
s:~:%7E:g
s:\[:%5B:g
s:\]:%5D:g
s:\`:%60:g
s:;:%3B:g
s:/:%2F:g
s:?:%3F:g
s^:^%3A^g
s:@:%40:g
s:=:%3D:g
s:&:%26:g
s:\!:%21:g
s:\*:%2A:g
s:\+:%2B:g
EOF

function Urlencode {
	local STRING
        local ENCODED

	STRING="${1}"
        ENCODED=$(echo "$STRING" | sed -f $URLENCODE_SED)

        echo "$ENCODED"
}

function Jsonspecialchars {
	echo "$1" | sed "s/'/\\\\\'/g"
}

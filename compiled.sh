#!/usr/bin/env bash

MY_HOME="https://demo.patrolserver.com"

#!/usr/bin/env bash

function SetEnv {
	# IFS for return function contents in newlines.
	OLDIFS=$IFS
	IFS=$'\n'

	# Set 77 error code as exit any subshell level.
	set -E
	trap '[ "$?" -ne 77 ] || exit 77' ERR
}

function ResetEnv {
	IFS=$OLDIFS
}

function Exit {
	exit 77;
}

function Random {
	cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}
#!/usr/bin/env bash

json() {

  ResetEnv

  throw () {
    echo "$*" >&2
    exit 1
  }

  BRIEF=0
  LEAFONLY=0
  PRUNE=0
  NORMALIZE_SOLIDUS=0

  usage() {
    echo
    echo "Usage: JSON.sh [-b] [-l] [-p] [-s] [-h]"
    echo
    echo "-p - Prune empty. Exclude fields with empty values."
    echo "-l - Leaf only. Only show leaf nodes, which stops data duplication."
    echo "-b - Brief. Combines 'Leaf only' and 'Prune empty' options."
    echo "-s - Remove escaping of the solidus symbol (stright slash)."
    echo "-h - This help text."
    echo
  }

  parse_options() {
    set -- "$@"
    local ARGN=$#
    while [ "$ARGN" -ne 0 ]
    do
      case $1 in
        -h) usage
            exit 0
        ;;
        -b) BRIEF=1
            LEAFONLY=1
            PRUNE=1
        ;;
        -l) LEAFONLY=1
        ;;
        -p) PRUNE=1
        ;;
        -s) NORMALIZE_SOLIDUS=1
        ;;
        ?*) echo "ERROR: Unknown option."
            usage
            exit 0
        ;;
      esac
      shift 1
      ARGN=$((ARGN-1))
    done
  }

  awk_egrep () {
    local pattern_string=$1

    gawk '{
      while ($0) {
        start=match($0, pattern);
        token=substr($0, start, RLENGTH);
        print token;
        $0=substr($0, start+RLENGTH);
      }
    }' pattern="$pattern_string"
  }

  tokenize () {
    local GREP
    local ESCAPE
    local CHAR

    if echo "test string" | egrep -ao --color=never "test" &>/dev/null
    then
      GREP='egrep -ao --color=never'
    else
      GREP='egrep -ao'
    fi

    if echo "test string" | egrep -o "test" &>/dev/null
    then
      ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
      CHAR='[^[:cntrl:]"\\]'
    else
      GREP=awk_egrep
      ESCAPE='(\\\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
      CHAR='[^[:cntrl:]"\\\\]'
    fi

    local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
    local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
    local KEYWORD='null|false|true'
    local SPACE='[[:space:]]+'

    $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | egrep -v "^$SPACE$"
  }

  parse_array () {
    local index=0
    local ary=''
    read -r token
    case "$token" in
      ']') ;;
      *)
        while :
        do
          parse_value "$1" "$index"
          index=$((index+1))
          ary="$ary""$value" 
          read -r token
          case "$token" in
            ']') break ;;
            ',') ary="$ary," ;;
            *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
          esac
          read -r token
        done
        ;;
    esac
    [ "$BRIEF" -eq 0 ] && value=$(printf '[%s]' "$ary") || value=
    :
  }

  parse_object () {
    local key
    local obj=''
    read -r token
    case "$token" in
      '}') ;;
      *)
        while :
        do
          case "$token" in
            '"'*'"') key=$token ;;
            *) throw "EXPECTED string GOT ${token:-EOF}" ;;
          esac
          read -r token
          case "$token" in
            ':') ;;
            *) throw "EXPECTED : GOT ${token:-EOF}" ;;
          esac
          read -r token
          parse_value "$1" "$key"
          obj="$obj$key:$value"        
          read -r token
          case "$token" in
            '}') break ;;
            ',') obj="$obj," ;;
            *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
          esac
          read -r token
        done
      ;;
    esac
    [ "$BRIEF" -eq 0 ] && value=$(printf '{%s}' "$obj") || value=
    :
  }

  parse_value () {
    local jpath="${1:+$1,}$2" isleaf=0 isempty=0 print=0
    case "$token" in
      '{') parse_object "$jpath" ;;
      '[') parse_array  "$jpath" ;;
      # At this point, the only valid single-character tokens are digits.
      ''|[!0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
      *) value=$token
         # if asked, replace solidus ("\/") in json strings with normalized value: "/"
         [ "$NORMALIZE_SOLIDUS" -eq 1 ] && value=${value//\\\//\/}
         isleaf=1
         [ "$value" = '""' ] && isempty=1
         ;;
    esac
    [ "$value" = '' ] && return
    [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 0 ] && print=1
    [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && [ $PRUNE -eq 0 ] && print=1
    [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 1 ] && [ "$isempty" -eq 0 ] && print=1
    [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && \
      [ $PRUNE -eq 1 ] && [ $isempty -eq 0 ] && print=1
    [ "$print" -eq 1 ] && printf "[%s]\t%s\n" "$jpath" "$value"
    :
  }

  parse () {
    read -r token
    parse_value
    read -r token
    case "$token" in
      '') ;;
      *) throw "EXPECTED EOF GOT $token" ;;
    esac
  }

  parse_options "$@"
  tokenize | parse

  SetEnv
}
#!/usr/bin/env bash

COOKIES=`mktemp`
POSTFILE=`mktemp`

function ApiUserRegister {
	local EMAIL=`Urlencode $1`
	local PASSWORD=`Urlencode $2`

	local OUTPUT=`wget -t2 -T6 --keep-session-cookies --save-cookies $COOKIES -qO- "${MY_HOME}/api/user/register" --post-data "email=$EMAIL&password=$PASSWORD&password_confirmation=$PASSWORD"`

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

	local OUTPUT=`wget -t2 -T6 --keep-session-cookies --save-cookies $COOKIES -qO- "${MY_HOME}/api/user/login" --post-data "email=$EMAIL&password=$PASSWORD"`

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

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/api/server/exists?host=$HOST"`

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
	
	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET" --post-data "domain=$HOSTNAME"`

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
	
	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/request_verification_token?domain=$HOSTNAME"`

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
	
	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/verify?key=$KEY&secret=$SECRET" --post-data "token=$TOKEN"`

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

	SOFTWARE=`cat $SOFTWARE | sort | uniq | awk 'BEGIN { RS="\n"; FS="\t"; print "["; prevLocation="---"; prevName="---"; prevVersion="---"; prevParent="---";} 
		{ 
			if($1 == prevLocation){ $1=""; } else { prevLocation = $1; $1 = "\"l\":\""$1"\"," }; 
			if($2 == prevParent){ $2=""; } else { prevParent = $2; $2 = "\"p\":\""$2"\"," }; 
			if($3 == prevName){ $3=""; } else { prevName = $3; $3 = "\"n\":\""$3"\"," }; 
			if($4 == prevVersion){ $4=""; } else { prevVersion = $4; $4 = "\"v\":\""$4"\"," }; 
			line = $1$2$3$4; 
			print "{"line"},"; 
		} 
		END { print "{}]"; }' | sed 's/,},/},/' | tr -d '\n'`
	SOFTWARE=`Urlencode "$SOFTWARE"`

	echo "$SOFTWARE" >> $POSTFILE


	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/software_bucket/$BUCKET?key=$KEY&secret=$SECRET&scope=silent" --post-file $POSTFILE`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (7)" >&2
		exit 77
	fi

	local ERROR=`echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-`

	echo ${ERROR:-false}
}

function ApiKeySecret {

	local OUTPUT=`wget -t2 -T6 --load-cookies $COOKIES -qO- "${MY_HOME}/api/user/api_credentials"`

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
	local OUTPUT=`wget -t2 -T6 --load-cookies $COOKIES -qO- "${MY_HOME}/api/user/api_credentials" --post-data "not=used"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (9)" >&2
		exit 77
	fi
}

function ApiServers {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET"`

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

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/software?key=$KEY&secret=$SECRET&scope=exploits"`

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

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/scan?key=$KEY&secret=$SECRET"  --post-data "not=used"`

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

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/isScanning?key=$KEY&secret=$SECRET"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (13)" >&2
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

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/user/update?key=$KEY&secret=$SECRET" --post-data "email=$EMAIL"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (14)" >&2
		exit 77
	fi

	local ERRORS=`echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-`
	local SUCCESS=`echo "$OUTPUT" | json | grep '^\["success"\]' | cut -f2-`

	echo ${ERRORS:-false}
	echo ${SUCCESS:-false}
}

function ApiUserRemove {
	local KEY=`Urlencode $1`
	local SECRET=`Urlencode $2`

	local OUTPUT=`wget -t2 -T6 -qO- "${MY_HOME}/extern/api/user/delete?key=$KEY&secret=$SECRET" --post-data "not=used"`

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (15)" >&2
		exit 77
	fi

	#local ERRORS=`echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-`
	#local SUCCESS=`echo "$OUTPUT" | json | grep '^\["success"\]' | cut -f2-`

	#echo ${ERRORS:-false}
	#echo ${SUCCESS:-false}
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
#!/usr/bin/env bash

function EnvFile {
    if [ -f ~/.patrolserver/env ];
    then
        source ~/.patrolserver/env
        LOCATE="$HOME/.patrolserver/locate.db"
    fi
}

function Args {

    optspec=":e:p:n:k:s:ci:b:hv-:"
    while getopts "$optspec" optchar; do
        case "${optchar}" in
            -)
                case "${OPTARG}" in
                    version)
                        echo "PatrolServer BashScanner $VERSION" >&2
                        exit
                        ;;
                    email)
                        EMAIL="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    email=*)
                        EMAIL=${OPTARG#*=}
                        ;;
                    password)
                        PASSWORD="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    password=*)
                        PASSWORD=${OPTARG#*=}
                        ;;
                    hostname)
                        HOSTNAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    hostname=*)
                        HOSTNAME=${OPTARG#*=}
                        ;;
                    key)
                        KEY="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    key=*)
                        KEY=${OPTARG#*=}
                        ;;
                    secret)
                        SECRET="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    secret=*)
                        SECRET=${OPTARG#*=}
                        ;;
                    cmd)
                        CMD="true"
                        ;;
                    cmd=*)
                        CMD=${OPTARG#*=}
                        ;;
                    server_id)
                        SERVER_ID="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    server_id=*)
                        SERVER_ID=${OPTARG#*=}
                        ;;
                    bucket)
                        BUCKET="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    bucket=*)
                        BUCKET=${OPTARG#*=}
                        ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                        ;;
                esac;;
            h)
                echo "usage: $0 [-v] [--key=<value>] [--secret=<value>] [--hostname=<value>] [--cmd]" >&2
                exit 2
                ;;
            v)
                echo "PatrolServer BashScanner $VERSION" >&2
                exit
                ;;
            e)
                EMAIL=${OPTARG}
                ;;
            p)
                PASSWORD=${OPTARG}
                ;;
            n)
                HOSTNAME=${OPTARG}
                ;;
            k)
                KEY=${OPTARG}
                ;;
            s)
                SECRET=${OPTARG}
                ;;
            c)
                CMD="true"
                ;;
            i)
                SERVER_ID=${OPTARG}
                ;;
            b)
                BUCKET=${OPTARG}
                ;;
            *)
                if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                    echo "Non-option argument: '-${OPTARG}'" >&2
                fi
                ;;
        esac
    done
}
#!/usr/bin/env bash

function ComposerSoftware {
    local FILES=`locate --database=$LOCATE "composer.lock" 2> /dev/null`
 	for FILE in $FILES; do
		local DIR=`dirname $FILE`
		local JSON="$DIR/composer.json"

		local PARENT="Undefined"
		if [ -f $JSON ]
		then
			PARENT=`cat $JSON | json | grep '^\["name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		fi

 		echo -e "$FILE\t\t$PARENT\t" >> $SOFTWARE

 		local JSON_DATA=`cat $FILE | json`
 		local NAMES=`echo "$JSON_DATA" | grep -E '^\["packages",[0-9]{1,},"name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
 		local VERSIONS=`echo "$JSON_DATA" | grep -E '^\["packages",[0-9]{1,},"version"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		local COMPSERSOFTWARE=`paste <(echo "$NAMES") <(echo "$VERSIONS")`
		for LINE in $COMPSERSOFTWARE; do
	   		NAME=`echo $LINE | cut -f1`
			VERSION=`echo $LINE | cut -f2`

			NAME=`Jsonspecialchars $NAME`
			VERSION=`Jsonspecialchars $VERSION`

			echo -e "$FILE\t$PARENT\t$NAME\t$VERSION" >> $SOFTWARE
		done
    done
}
 #!/usr/bin/env bash

function DpkgSoftware {
   	local SUBSOFTWARE=`dpkg -l | grep '^i' | grep -v "lib" | tr -s ' ' | sed 's/ /\t/g'| cut -f2,3`

   	for LINE in $SUBSOFTWARE; do
   		NAME=`echo $LINE | cut -f1`
		VERSION=`echo $LINE | cut -f2`

		NAME=`Jsonspecialchars $NAME`
		VERSION=`Jsonspecialchars $VERSION`

		echo -e "/\t\t$NAME\t$VERSION" >> $SOFTWARE
	done
}
#!/usr/bin/env bash

function DrupalSoftware {
	ALL_MODULES=`locate --database=$LOCATE "*.info" 2> /dev/null`
    FILES=`locate --database=$LOCATE "drupal.js" 2> /dev/null`
	for FILE in $FILES; do

		# Get root path
		local DIR=`dirname $FILE`
		local DIR=`cd "$DIR/../"; pwd`
		local VERSION_FILE="${DIR}/includes/bootstrap.inc"

		local VERSION=""
		if [ -f $VERSION_FILE ]
		then
			local VERSION=`cat "$VERSION_FILE" | grep "define('VERSION', '[0-9]*\.[0-9]*')" | grep -o "[0-9]*\.[0-9]*" 2> /dev/null` 
		fi

		if [ "$VERSION" == "" ]
		then
			local VERSION_FILE="${DIR}/modules/php/php.info"
			if [ -f $VERSION_FILE ]
			then
				local VERSION=`cat "$VERSION_FILE" | grep "version = \"[0-9]*\.[0-9]*\"" | grep -o "[0-9]*\.[0-9]*"` 
			fi
		fi

		echo -e "$DIR\t\tdrupal\t$VERSION" >> $SOFTWARE

		# Get modules
		MODULES=`echo "$ALL_MODULES" | grep "^$DIR/sites/all"`
		for MODULE in $MODULES; do
			local VERSION=`grep "version = ['\"]*[0-9a-z\.\-]*['\"]*" "$MODULE" | grep -o "[0-9][0-9a-z\.\-]*"`
			local NAME=`basename $MODULE` 
			local NAME=${NAME%.*}

			echo -e "$DIR\tdrupal\tdrupal/$NAME\t$VERSION" >> $SOFTWARE
		done
		
    done
}

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
	if [[ "$OPEN_PORT_53" != "" ]] && `command -v dig >/dev/null 2>&1`
	then
		EXTERNAL_IP=`dig +time=1 +tries=1 +retry=1 +short myip.opendns.com @resolver1.opendns.com | tail -n1`
		IP=`dig @8.8.8.8 +short $HOSTNAME | tail -n1`
	else
		EXTERNAL_IP=`wget -qO- ipv4.icanhazip.com`
		IP=`host "$HOSTNAME" | grep -v 'alias' | grep -v 'mail' | cut -d' ' -f4 | head -n1`
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
	 	echo "> Take a coffee break ;) "
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

	CORE_SOFTWARE=`echo "$SOFTWARE" | grep '"parent":null' | grep '"location":"\\\/"'`
	OutputBlock "$SOFTWARE" "$CORE_SOFTWARE"

	CORE_SOFTWARE=`echo "$SOFTWARE" | grep "\"parent\":null" | grep -v '"location":"\\\/"'`
	OutputBlock "$SOFTWARE" "$CORE_SOFTWARE"
}

function OutputBlock {
	SOFTWARE="$1"
	BLOCK_SOFTWARE="$2"

	PREV_LOCATION="---"
	for LINE in $BLOCK_SOFTWARE; do

		LINE=`echo "$LINE" | json`
		CANONICAL_NAME=`echo "$LINE" | grep '^\["canonical_name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		CANONICAL_NAME_GREP=`echo "$CANONICAL_NAME" | sed -e 's/[]\/$*.^|[]/\\\&/g'`
		LOCATION=`echo "$LINE" | grep '^\["location"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		LOCATION_GREP=`echo "$LOCATION" | sed -e 's/[]\/$*.^|[]/\\\&/g'`

		# Print out the location when it has changed
		if [[ "$PREV_LOCATION" != "$LOCATION" ]] && [[ "$LOCATION" != '\/' ]]
		then
			echo "";
			echo -ne "\e[0;90m"
			echo -n $LOCATION
			echo -e "\e[0m"
			echo "";

			PREV_LOCATION="$LOCATION"
		fi

		OutputLine "$LINE"

		# Print submodules
		for LINE in `echo "$SOFTWARE" | grep '"parent":"'$CANONICAL_NAME_GREP'"' | grep "location\":\"$LOCATION_GREP"`; do
			LINE=`echo "$LINE" | json`
			
			echo -en "\t"
			OutputLine "$LINE"
		done
	done
}

function OutputLine {
	LINE="$1"

	NAME=`echo "$LINE" | grep '^\["name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	VERSION=`echo "$LINE" | grep '^\["version"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	VERSIONS=`echo "$LINE" | grep '^\["versions"\]' | cut -f2-`
	NEW_VERSION=`echo "$LINE" | grep '^\["newest_bugfix_release"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	SUPPORTED=`echo "$LINE" | grep '^\["supported"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	EXPLOITS=`echo "$LINE" | grep '^\["exploits"\]' | cut -f2- | json | grep '^\[[0-9]*,"risk"\]' | cut -f2-`
	PARENT=`echo "$LINE" | grep '^\["parent"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	LOCATION=`echo "$LINE" | grep '^\["location"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`

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
		if [ "$IS_BIGGER" == "1" ]
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

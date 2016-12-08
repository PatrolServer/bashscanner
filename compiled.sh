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
	tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "${1:-32}" | head -n 1
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
                    cron)
                        CRON="true"
                        ;;
                    cron=*)
                        CRON=${OPTARG#*=}
                        ;;
                    target)
                        MY_HOME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    target=*)
                        MY_HOME=${OPTARG#*=}
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
            t)
                MY_HOME=${OPTARG}
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

 		local JSON_DATA=`cat $FILE | json -bn`
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
   	if `command -v dpkg >/dev/null 2>&1`
	then
		local SUBSOFTWARE=`dpkg -l 2> /dev/null | grep '^i' | grep -v "lib" | tr -s ' ' | sed 's/ /\t/g'| cut -f2,3`

	   	for LINE in $SUBSOFTWARE; do
	   		NAME=`echo $LINE | cut -f1`
			VERSION=`echo $LINE | cut -f2`

			NAME=`Jsonspecialchars $NAME`
			VERSION=`Jsonspecialchars $VERSION`

			echo -e "/\t\t$NAME\t$VERSION" >> $SOFTWARE
		done
	fi
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
#!/usr/bin/env bash

function NpmSoftware {

	POTENTIAL=`locate --database=$LOCATE --regex "node_modules$" | grep -v "node_modules.*node_modules" | grep -v "\.npm" 2> /dev/null`
        for DIR in $POTENTIAL; do

        		if command -v npm >/dev/null 2>&1
        		then
	                VERSION=`npm -v`
	                echo -e "$DIR\t\tnpm\t$VERSION" >> $SOFTWARE
	            fi

                for MODULE in $DIR/*/package.json; do
                		if [[ "$MODULE" != "$DIR/*/package.json" ]]
                		then
	                        JSON=`cat $MODULE | json`
	                        NAME=`echo "$JSON" | grep '\[\"name\"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
	                        VERSION=`echo "$JSON" | grep '\[\"version\"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`

	                        echo -e "$DIR\tnpm\tnpm/$NAME\t$VERSION" >> $SOFTWARE
	                    fi
                done
    done
    
}
#!/usr/bin/env bash

function WordpressSoftware {
	FILES=`locate --database=$LOCATE "wp-settings.php" 2> /dev/null`
    for FILE in $FILES; do

        # Get root path
        DIR=$(dirname $FILE)
        VERSION_FILE="${DIR}/wp-includes/version.php"

        VERSION=""
        if [ -f $VERSION_FILE ]
        then
            VERSION=$(cat "$VERSION_FILE" | grep "\$wp_version = '[0-9]*\.[0-9]*\.[0-9]*'" | grep -o "[0-9]*\.[0-9]*\.[0-9]*" 2> /dev/null)
        fi

        echo -e "$DIR\t\twordpress\t$VERSION" >> $SOFTWARE

        # Get modules
        MODULES=$(find "$DIR/wp-content/plugins" -mindepth 2 -maxdepth 2 -type f | grep "\.php$" | xargs grep "Plugin Name:" -l)
        for MODULE in $MODULES; do
            VERSION=$(grep "Version: ['\"]*[0-9a-z\.\-]*['\"]*" "$MODULE" 2> /dev/null | grep -o "[0-9][0-9a-z\.\-]*")
            NAME=$(dirname $MODULE | xargs basename)
            echo -e "$DIR\twordpress\twordpress:$NAME\t$VERSION" >> $SOFTWARE
        done

        MODULES=$(find "$DIR/wp-content/plugins" -maxdepth 1 -type f | grep "\.php$" | xargs grep "Plugin Name:" -l)
        for MODULE in $MODULES; do
            VERSION=$(grep "Version: ['\"]*[0-9a-z\.\-]*['\"]*" "$MODULE" 2> /dev/null | grep -o "[0-9][0-9a-z\.\-]*")
            NAME=$(basename $MODULE)
            NAME="${NAME%.*}"
            echo -e "$DIR\twordpress\twordpress:$NAME\t$VERSION" >> $SOFTWARE
        done
    done
}
#!/usr/bin/env bash

function PhpmyadminSoftware {
    FILES=`locate --database=$LOCATE "phpmyadmin.css.php" 2> /dev/null`
	for FILE in $FILES; do
	
		# Get root path
		local DIR=`dirname $FILE`
		local VERSION_FILE="${DIR}/libraries/Config.php"

		local VERSION=""
		if [ -f $VERSION_FILE ]
		then
			local VERSION=`cat "$VERSION_FILE" | grep "\\$this->set('PMA_VERSION', '[0-9.]*')" | grep -o "[0-9.]*" 2> /dev/null` 
		fi

		if [ "$VERSION" == "" ]
		then
			local VERSION_FILE="${DIR}/libraries/Config.class.php"
			if [ -f $VERSION_FILE ]
			then
			    local VERSION=`cat "$VERSION_FILE" | grep "\\$this->set('PMA_VERSION', '[0-9.]*')" | grep -o "[0-9.]*" 2> /dev/null` 
			fi
		fi

		echo -e "$DIR\t\tphpmyadmin\t$VERSION" >> $SOFTWARE
		
    done
}
#!/usr/bin/env bash

function JoomlaSoftware {
    FILES=`locate --database=$LOCATE "authentication/joomla/joomla.xml" | sort | uniq 2> /dev/null`
	for FILE in $FILES; do

		# Get root path
		local DIR=`dirname $FILE`
		local DIR=`cd "$DIR/../../../"; pwd`
		local VERSION_FILE="${DIR}/libraries/cms/version/version.php"

		local VERSION=""
		if [ -f $VERSION_FILE ]
		then

			local VERSION_BRANCH=`cat "$VERSION_FILE" | grep "RELEASE = '[0-9.]*';" | grep -o "[0-9.]*" 2> /dev/null` 
			local VERSION_SECURITY=`cat "$VERSION_FILE" | grep "DEV_LEVEL = '[0-9]*';" | grep -o "[0-9.]*" 2> /dev/null`
			
			if [[ "$VERSION_BRANCH" != "" && "$VERSION_SECURITY" != "" ]]
			then
    			local VERSION="$VERSION_BRANCH.$VERSION_SECURITY" 
            fi
		fi

		echo -e "$DIR\t\tjoomla\t$VERSION" >> $SOFTWARE
		
    done
}
#!/usr/bin/env bash

function MagentoSoftware {
    FILES=`locate --database=$LOCATE "app/Mage.php" 2> /dev/null`
	for FILE in $FILES; do

		# Get root path
		local DIR=`dirname $FILE`
		local DIR=`cd "$DIR/../"; pwd`
		local VERSION_FILE="${DIR}/app/Mage.php"

		local VERSION=""
		if [ -f $VERSION_FILE ]
		then

			local VERSION_MAJOR=`cat "$VERSION_FILE" | grep "'major' *=> '[0-9.]*'" | grep -o "[0-9.]*" 2> /dev/null` 
			local VERSION_MINOR=`cat "$VERSION_FILE" | grep "'minor' *=> '[0-9]*'" | grep -o "[0-9.]*" 2> /dev/null`
			local VERSION_REVISION=`cat "$VERSION_FILE" | grep "'revision' *=> '[0-9]*'" | grep -o "[0-9.]*" 2> /dev/null`
			local VERSION_PATCH=`cat "$VERSION_FILE" | grep "'patch' *=> '[0-9]*'" | grep -o "[0-9.]*" 2> /dev/null`
			
			echo $VERSION_MAJOR
			
			if [[ "$VERSION_MAJOR" != "" && "$VERSION_MINOR" != "" && "$VERSION_REVISION" != "" && "$VERSION_PATCH" != "" ]]
			then
    			local VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_REVISION.$VERSION_PATCH" 
            fi
		fi

		echo -e "$DIR\t\tmagentoCommerce\t$VERSION" >> $SOFTWARE
		
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
LOCATE=$(mktemp)
CRON="ask"

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

	if [ "$CMD" == "false" ]
	then
		if [[ "$CRON" == "ask" ]]
		then
			Output
		fi

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
			read -r EMAIL
			echo -en "\tYour password: "
			read -rs PASSWORD
			echo "";

			LOGIN_RET=($(ApiUserLogin "$EMAIL" "$PASSWORD"))

			local LOGIN_ERROR=${LOGIN_RET[0]}
			local LOGIN_USER=${LOGIN_RET[1]}
			local LOGIN_KEY=${LOGIN_RET[2]}
			local LOGIN_SECRET=${LOGIN_RET[3]}

			if [ "$LOGIN_ERROR" == "false" ]
			then
				StoreKeySecret "$LOGIN_KEY" "$LOGIN_SECRET"
				return
			elif [ "$LOGIN_ERROR" == "too_many_failed_attempts" ]
			then
				echo "> Your login was blocked for security issues, please try again in 10 min." >&2
				exit 77
			elif [ "$LOGIN_ERROR" == "different_country" ]
			then
				echo "> Your login is temporarily blocked for security measurements. Check your email for further instructions." >&2
				exit 77
			else
				echo "> Wrong email and/or password! Try again." >&2
			fi
		done
		echo "> Invalid login";

	else
		if [ "$EMAIL" == "" ]
		then
			echo "Specify login credentials." >&2
			exit 77
		fi

		if [ "$PASSWORD" == "" ]
		then
			echo "Specify login credentials." >&2
			exit 77
		fi

		LOGIN_RET=($(ApiUserLogin "$EMAIL" "$PASSWORD"))

		local LOGIN_ERROR=${LOGIN_RET[0]}
		local LOGIN_USER=${LOGIN_RET[1]}
		local LOGIN_KEY=${LOGIN_RET[2]}
		local LOGIN_SECRET=${LOGIN_RET[3]}

		if [ "$LOGIN_ERROR" == "false" ]
		then
			StoreKeySecret "$LOGIN_KEY" "$LOGIN_SECRET"
			return
		elif [ "$LOGIN_ERROR" == "too_many_failed_attempts" ]
		then
			echo "> Your login was blocked for security issues, please try again in 10 min." >&2
			exit 77
		elif [ "$LOGIN_ERROR" == "different_country" ]
		then
			echo "> Your login is temporarily blocked for security measurements. Check your email for further instructions." >&2
			exit 77
		else
			echo "> Invalid login credentials." >&2
			exit 77
		fi
	fi

	exit 77;
}

function StoreKeySecret {
	KEY="$1"
	SECRET="$2"

	if [ "$KEY" == "false" ]
	then
		echo "> Internal error, could not get key/secret combo." >&2
		exit 77
	fi

	if [ "$SECRET" == "false" ]
	then
		echo "> Internal error, could not get key/secret combo." >&2
		exit 77
	fi
}

function Register {
	REGISTER_RET=($(ApiUserRegister "$EMAIL" "$PASSWORD"))

	local REGISTER_ERROR=${REGISTER_RET[0]}
	local REGISTER_USER=${REGISTER_RET[1]}
	local REGISTER_KEY=${REGISTER_RET[2]}
	local REGISTER_SECRET=${REGISTER_RET[3]}

	if [ "$REGISTER_ERROR" == "false" ]
	then
		echo "success"
		echo "${REGISTER_KEY:-false}"
		echo "${REGISTER_SECRET:-false}"
		return
	else
		if [[ "$REGISTER_ERROR" =~ "The email has already been taken" ]]
		then
			echo "email"
			return
		fi

		echo "> Unexpected error occured." >&2
		exit 77;
	fi
}

function TestHostname {
	OPEN_PORT_53=$(echo "quit" | timeout 1 telnet 8.8.8.8 53 2> /dev/null |  grep "Escape character is")
	if [[ "$OPEN_PORT_53" != "" ]] && command -v dig >/dev/null 2>&1
	then
		EXTERNAL_IP=$(dig +time=1 +tries=1 +retry=1 +short myip.opendns.com @resolver1.opendns.com | tail -n1)
		IP=$(dig @8.8.8.8 +short $HOSTNAME | tail -n1)
	else

		if ! command -v host >/dev/null 2>&1 && command -v yum >/dev/null 2>&1
		then
			echo "This script needs the bind utils package, please install: yum install bind-utils"
			exit 77
		fi

		EXTERNAL_IP=$(wget -qO- ipv4.icanhazip.com)
		IP=$(host "$HOSTNAME" | grep -v 'alias' | grep -v 'mail' | cut -d' ' -f4 | head -n1)
	fi
}

function Hostname {

	if [[ "$HOSTNAME" == "" ]]
	then
		HOSTNAME=$(hostname -f 2> /dev/null)
	fi

	if [[ "$HOSTNAME" != "" ]]
	then
		TestHostname
	fi

	if [[ "$CMD" != "false" ]]
	then
		if [ "$IP" == "" ]
		then
			echo "Hostname not found. (Please enter with command)" >&2
			exit 77;
		elif [[ "$IP" != "$EXTERNAL_IP" ]]
		then
			echo "Hostname doesn't resolve to external IP of this server." >&2
			exit 77;
		fi
	fi

	for I in 1 2 3
	do

		if [ "$IP" == "" ]
		then
			echo "> Could not determine your hostname."
			echo -en "\tPlease enter the hostname of this server: "
			read -r HOSTNAME
			echo "";
		elif [[ "$IP" != "$EXTERNAL_IP" ]]
		then
			echo "> Your hostname ($HOSTNAME) doesn't resolve to this IP."
			echo -en "\tPlease enter the hostname that resolved to this ip: "
			read -r HOSTNAME
			echo "";
		fi

		TestHostname

		if [[ "$IP" != "" ]] && [ "$IP" == "$EXTERNAL_IP" ]
		then
			return;
		fi
	done

	echo "> Could not determine hostname."  >&2
	exit 77;
}

function DetermineHostname {

	Hostname

	if [ "$EMAIL" == "" ] && [ "$PASSWORD" == "" ] && [ "$KEY" == "" ] && [ "$SECRET" == "" ]
	then
		# Check if the host is already in our DB
		# Please note! You can remove this check, but our policy doesn't change.
		# Only one free server per domain is allowed.
		# We actively check for these criteria
		SERVER_EXISTS_RET=($(ApiServerExists "$HOSTNAME"))

		SERVER_EXISTS_ERROR=${SERVER_EXISTS_RET[0]}
		SERVER_EXISTS=${SERVER_EXISTS_RET[1]}

		if [ "$SERVER_EXISTS_ERROR" == "false" ]
		then
			return

		# There is already an host from this user.
		elif [ "$SERVER_EXISTS_ERROR" == "15" ]
		then
			echo "> An account was already created for this host or a subdomain of this host. Please login into your patrolserver.com account or add the key/secret when calling this command." >&2
			Login

		# Hostname could not be found.
		elif [ "$SERVER_EXISTS_ERROR" == "83" ]
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
		return;
	fi

	if [[ "$CMD" != "false" ]]
	then
		YN="n"
	else
		echo "> You can use this tool 5 times without account."

		YN="..."
		while [[ "$YN" != "n" ]] && [[ $YN != "y" ]]; do
			read -rp "> Do you want to create an account (y/n)? " YN
		done
	 fi

	if [ "$YN" == "n" ]
	then
		# Create account when no account exists.
		EMAIL="tmp-$(Random)@$HOSTNAME"
		PASSWORD=$(Random)

		REGISTER_RET=($(Register "$EMAIL" "$PASSWORD"))

		REGISTER_RET_STATUS=${REGISTER_RET[0]}

		if [ "$REGISTER_RET_STATUS" != "success" ]
		then
			echo "> Internal error, could not create temporary account"
			exit 77
		else
			REGISTER_RET_KEY=${REGISTER_RET[1]}
			REGISTER_RET_SECRET=${REGISTER_RET[2]}
			StoreKeySecret "$REGISTER_RET_KEY" "$REGISTER_RET_SECRET"
		fi

	else
		for I in 1 2 3
		do
			# Ask what account should be created.
			echo -en "\tYour email: "
			read -r EMAIL
			echo -en "\tNew password: "
			read -rs PASSWORD
			echo ""
			echo -en "\tRetype your password: "
			read -rs PASSWORD2
			echo "";

			REGISTER_RET_STATUS=""
			if [ "$PASSWORD" == "$PASSWORD2" ] && [ ${#PASSWORD} -ge 7 ]
			then
				REGISTER_RET=($(Register "$EMAIL" "$PASSWORD"))

				REGISTER_RET_STATUS=${REGISTER_RET[0]}

				if [ "$REGISTER_RET_STATUS" == "success" ]
				then
					REGISTER_RET_KEY=${REGISTER_RET[1]}
					REGISTER_RET_SECRET=${REGISTER_RET[2]}
					StoreKeySecret "$REGISTER_RET_KEY" "$REGISTER_RET_SECRET"
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
	SERVERS_RET=($(ApiServers "$KEY" "$SECRET"))
	SERVERS_ERRORS=${SERVERS_RET[0]}
	SERVERS=${SERVERS_RET[1]}

	HAS_SERVER=$(echo "$SERVERS" | json | grep -P '^\[[0-9]*,"name"\]\t"'"$HOSTNAME"'"')

	# Check if the server has already been created
	if [ "$HAS_SERVER" == "" ]
	then

		SERVER_CREATE_RET=($(ApiServerCreate "$KEY" "$SECRET" "$HOSTNAME"))
		SERVER_CREATE_ERRORS=${SERVER_CREATE_RET[0]}

		if [[ "$SERVER_CREATE_ERRORS" =~ "You exceeded the maximum allowed server slots" ]]
		then
			echo "> You exceeded the maximum allowed servers on your account, please login onto http://patrolserver.com and upgrade your account";
			exit 77;
		fi

		SERVERS_RET=($(ApiServers "$KEY" "$SECRET"))
		SERVERS_ERRORS=${SERVERS_RET[0]}
		SERVERS=${SERVERS_RET[1]}

		HAS_SERVER=$(echo "$SERVERS" | json | grep -P '^\[[0-9]*,"name"\]\t"'"$HOSTNAME"'"' -o)
	fi

	if [ "$HAS_SERVER" == "" ]
	then
		echo "> Internal error, could not create the server online" >&2
		exit 77
	fi

	SERVER_ARRAY_ID=$(echo "$HAS_SERVER" | grep -P '^\[[0-9]+' -o | grep -P '[0-9]+' -o)
	SERVER_ID=$(echo "$SERVERS" | json | grep "^\[$SERVER_ARRAY_ID,\"id\"\]" | cut -f2-)
	SERVER_VERIFIED=$(echo "$SERVERS" | json | grep "^\[$SERVER_ARRAY_ID,\"verified\"\]" | cut -f2-)

	# Check if the server has already been verified
	if [ "$SERVER_VERIFIED" == "false" ]
	then
		SERVER_TOKEN_RET=($(ApiServerToken "$HOSTNAME"))
		SERVER_TOKEN_ERRORS=${SERVER_TOKEN_RET[0]}
		SERVER_TOKEN=${SERVER_TOKEN_RET[1]}

		SERVER_VERIFY_RET=($(ApiVerifyServer "$KEY" "$SECRET" "$SERVER_ID" "$SERVER_TOKEN"))
		SERVER_TOKEN_ERRORS=${SERVER_VERIFY_RET[0]}
	fi
}

function Scan {
	if [[ "$CMD" == "false" ]]
	then
		echo "> Searching for packages, can take some time..."
	fi

	SOFTWARE=$(mktemp)

	# Update db
	if ! command -v updatedb >/dev/null 2>&1 && command -v yum >/dev/null 2>&1
	then
		echo "This script needs the mlocate package, please install: yum install mlocate"
		exit 77
	fi
	updatedb -o "$LOCATE" -U / --require-visibility 0 2> /dev/null

	# Do all scanners
	ComposerSoftware
	DpkgSoftware
	DrupalSoftware
	NpmSoftware
	WordpressSoftware
	PhpmyadminSoftware
	JoomlaSoftware
	MagentoSoftware

	if [[ "$CMD" == "false" ]]
	then
		echo "> Scanning for newest releases and exploits, can take serveral minutes..."
		echo "> Take a coffee break ;) "
	fi

	SOFTWARE_PUST_RET=($(ApiServerPush "$KEY" "$SECRET" "$SERVER_ID" "$BUCKET" "$SOFTWARE"))
	SOFTWARE_PUST_ERRORS=${SOFTWARE_PUST_RET[0]}

	if [ "$SOFTWARE_PUST_ERRORS" != "false" ]
	then
		echo "> Could not upload software data, please give our support team a call with the following details" >&2
		echo "$SOFTWARE_PUST_ERRORS" >&2
		exit 77
	fi

	SERVER_SCAN_RET=($(ApiServerScan "$KEY" "$SECRET" "$SERVER_ID"))
	SERVER_SCAN_ERRORS=${SERVER_SCAN_RET[0]}

	if [ "$SERVER_SCAN_ERRORS" != "false" ]
	then
		echo "> Could not send scan command, please give our support team a call with the following details" >&2
		echo "$SERVER_SCAN_ERRORS" >&2
		exit 77
	fi

	SERVER_SCANNING="true"
	while [ "$SERVER_SCANNING" == "true" ] ; do
		SERVER_SCANNING_RET=($(ApiServerIsScanning "$KEY" "$SECRET" "$SERVER_ID"))
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

	SOFTWARE_RET=($(ApiSoftware "$KEY" "$SECRET" "$SERVER_ID"))
	SOFTWARE_ERRORS=${SOFTWARE_RET[0]}
	SOFTWARE_JSON=${SOFTWARE_RET[1]}

	SOFTWARE=$(echo "$SOFTWARE_JSON" | json | grep -P "^\[[0-9]{1,}\]" | cut -f2-)
	if [ "$SOFTWARE" == "" ]
	then
		echo -e "\tStrangely, No packages were found..."
	fi

	CORE_SOFTWARE=$(echo "$SOFTWARE" | grep '"parent":null' | grep '"location":"\\\/"')
	OutputBlock "$SOFTWARE" "$CORE_SOFTWARE"

	CORE_SOFTWARE=$(echo "$SOFTWARE" | grep "\"parent\":null" | grep -v '"location":"\\\/"')
	OutputBlock "$SOFTWARE" "$CORE_SOFTWARE"
}

function OutputBlock {
	SOFTWARE="$1"
	BLOCK_SOFTWARE="$2"

	PREV_LOCATION="---"
	for LINE in $BLOCK_SOFTWARE; do

		LINE=$(echo "$LINE" | json)
		CANONICAL_NAME=$(echo "$LINE" | grep '^\["canonical_name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
		CANONICAL_NAME_GREP=$(echo "$CANONICAL_NAME" | sed -e 's/[]\/$*.^|[]/\\&/g')
		LOCATION=$(echo "$LINE" | grep '^\["location"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
		LOCATION_GREP=$(echo "$LOCATION" | sed -e 's/[]\/$*.^|[]/\\&/g')

		# Print out the location when it has changed
		if [[ "$PREV_LOCATION" != "$LOCATION" ]] && [[ "$LOCATION" != '\/' ]]
		then
			echo "";
			echo -ne "\e[0;90m"
			echo -n "$LOCATION"
			echo -e "\e[0m"
			echo "";

			PREV_LOCATION="$LOCATION"
		fi

		OutputLine "$LINE"

		# Print submodules
		for LINE in $(echo "$SOFTWARE" | grep '"parent":"'"$CANONICAL_NAME_GREP"'"' | grep "location\":\"$LOCATION_GREP"); do
			LINE=$(echo "$LINE" | json)

			echo -en "\t"
			OutputLine "$LINE"
		done
	done
}

function OutputLine {
	LINE="$1"

	NAME=$(echo "$LINE" | grep '^\["name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	VERSION=$(echo "$LINE" | grep '^\["version"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	VERSIONS=$(echo "$LINE" | grep '^\["versions"\]' | cut -f2-)
	NEW_VERSION=$(echo "$LINE" | grep '^\["newest_bugfix_release"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	SUPPORTED=$(echo "$LINE" | grep '^\["supported"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	EXPLOITS=$(echo "$LINE" | grep '^\["exploits"\]' | cut -f2- | json | grep '^\[[0-9]*,"risk"\]' | cut -f2-)
	LOCATION=$(echo "$LINE" | grep '^\["location"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')

	if [ "$VERSIONS" != "" ]
	then
		VERSION=$(echo "$VERSIONS" | json | grep '^\[0]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
		VERSION="<=$VERSION"
	fi

	echo -ne "\t$NAME: "

	# Print current version
	if [ "$VERSION" == "" ]
	then
		echo -n "version not detected"
	elif [ "$SUPPORTED" == "yes" ]
	then
		echo -ne "\e[0;32m"
		echo -n "$VERSION"
		echo -ne "\e[0m"
	elif [[ "$NEW_VERSION" != "" ]]
	then
		echo -ne "\e[0;33m"
		echo -n "$VERSION"
		echo -ne "\e[0m"
		echo -n ", update to "
		echo -ne "\e[0;32m"
		echo -n "$NEW_VERSION"
		echo -ne "\e[0m"
	else
		echo -ne "\e[0;31m"
		echo -n "$VERSION"
		echo -ne "\e[0m"
		echo -n ", not supported anymore"
	fi

	# Check exploits
	COUNT_EXPLOITS=0
	for EXPLOIT in $EXPLOITS; do
		IS_BIGGER=$(echo "$EXPLOIT" | grep "^[5-9]")
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
	HAS_CRONTAB=$(crontab -l 2> /dev/null | grep "patrolserver")
	if [ "$HAS_CRONTAB" != "" ]
	then
		return
	fi

	if [[ "$CMD" != "false" ]]
	then
		return
	fi

	if [[ "$CRON" != "ask" ]] && [[ "$CRON" != "true" ]]
	then
		return
	fi

	# Check if user want a cronjob
	YN="..."
	if [[ "$CRON" == "true" ]]
	then
		YN="y"
	fi
	while [[ "$YN" != "n" ]] && [[ $YN != "y" ]]; do
		read -rp "> It is advisable to check your server daily, should we set a cronjob (y/n)? " YN
	done

	if [ "$YN" == "n" ]
	then
		if [[ "$EMAIL" == tmp\-* ]]
		then
			ApiUserRemove "$KEY" "$SECRET"
		fi

	else

		if [[ "$EMAIL" == tmp\-* ]]
		then
			echo -n "> What is your email address to send reports to? "
			read -r REAL_EMAIL
			echo ""

			CHANGE_EMAIL_RET=($(ApiUserChange "$KEY" "$SECRET" "$REAL_EMAIL"))
			CHANGE_EMAIL_ERROR=${CHANGE_EMAIL_RET[0]}
			CHANGE_EMAIL_USER=${CHANGE_EMAIL_RET[1]}

			if [ "$CHANGE_EMAIL_ERROR" != "false" ]
			then
				if [[ "$CHANGE_EMAIL_ERROR" == "82" ]]
				then
					echo "> There is already an account with this email address, use this tool with email and password parameters." >&2
					exit 77
				fi

				echo "> Internal error when changing username" >&2
				exit 77
			fi
		fi

		mkdir ~/.patrolserver 2> /dev/null
		echo -e "HOSTNAME=$HOSTNAME\nKEY=$KEY\nSECRET=$SECRET" > ~/.patrolserver/env
		cat "$LOCATE" > ~/.patrolserver/locate.db
		wget -O ~/.patrolserver/patrolserver "https://raw.githubusercontent.com/PatrolServer/bashScanner/master/patrolserver" 2&>1 /dev/null
		chmod +x ~/.patrolserver/patrolserver

		# Set cronjob
		CRON_TMP=$(mktemp)
		crontab -l 2> /dev/null > "$CRON_TMP"
		CRON_HOUR=$((RANDOM % 24))
		CRON_MINUTE=$((RANDOM % 60))
		echo "$CRON_MINUTE $CRON_HOUR * * * /bin/bash $HOME/.patrolserver/patrolserver --cmd --key=\"$KEY\" --secret=\"$SECRET\" --hostname=\"$HOSTNAME\" > /dev/null" >> $CRON_TMP
		crontab "$CRON_TMP"

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

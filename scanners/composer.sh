#!/usr/bin/env bash

function ComposerSoftware {
    local FILES=`find / -name "composer.lock" -xdev 2> /dev/null`
	for FILE in $FILES; do
		local DIR=`dirname $FILE`
		local JSON="$DIR/composer.json"

		local PARENT="Undefined"
		if [ -f $JSON ]
		then
			PARENT=`cat $JSON | json | grep '^\["name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		fi

		echo -e "$FILE\t$PARENT\t\t"

		local NAMES=`cat $FILE | json | grep -E '^\["packages",[0-9]{1,},"name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		local VERSIONS=`cat $FILE | json | grep -E '^\["packages",[0-9]{1,},"version"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		local SOFTWARE=`paste <(echo "$NAMES") <(echo "$VERSIONS")`
		for LINE in $SOFTWARE; do
	   		NAME=`echo $LINE | cut -f1`
			VERSION=`echo $LINE | cut -f2`

			NAME=`Jsonspecialchars $NAME`
			VERSION=`Jsonspecialchars $VERSION`

			echo -e "$FILE\t$NAME\t$VERSION\t$PARENT"
		done
    done
}
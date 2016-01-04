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
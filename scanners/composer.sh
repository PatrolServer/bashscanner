#!/usr/bin/env bash

function ComposerSoftware {
    FILES=`find / -name "composer.lock" -xdev 2> /dev/null`
	for FILE in $FILES; do
		NAMES=`cat $FILE | json | grep -E '^\["packages",[0-9]{1,},"name"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		VERSIONS=`cat $FILE | json | grep -E '^\["packages",[0-9]{1,},"version"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//'`
		SOFTWARE=`paste <(echo "$NAMES") <(echo "$VERSIONS")`

		for LINE in $SOFTWARE; do
	   		NAME=`echo $LINE | cut -f1`
			VERSION=`echo $LINE | cut -f2`

			NAME=`Jsonspecialchars $NAME`
			VERSION=`Jsonspecialchars $VERSION`

			echo -e "$FILE\t$NAME\t$VERSION"
		done
    done
}
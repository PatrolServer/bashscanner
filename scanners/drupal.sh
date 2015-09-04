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
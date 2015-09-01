#!/usr/bin/env bash

function DrupalSoftware {
    FILES=`find / -name "drupal.js" -xdev 2> /dev/null`
	for FILE in $FILES; do

		# Get root path
		local DIR=`dirname $FILE`
		local DIR=`cd "$DIR/../"; pwd`
		local VERSION=`cat "${DIR}/includes/bootstrap.inc" | grep "define('VERSION', '[0-9]*\.[0-9]*')" | grep -o "[0-9]*\.[0-9]*"` 

		if [ "$VERSION" == "" ]
		then
			local VERSION=`cat "${DIR}/modules/php/php.info" | grep "version = \"[0-9]*\.[0-9]*\"" | grep -o "[0-9]*\.[0-9]*"` 
		fi

		echo -e "$DIR\tdrupal\t$VERSION"

		# Get modules
		MODULES=`find "$DIR/sites/all" -name "*.info" -xdev 2> /dev/null`
		for MODULE in $MODULES; do
			local VERSION=`cat "$MODULE" | grep "version = ['\"]*[0-9a-z\.\-]*['\"]*" | grep -o "[0-9][0-9a-z\.\-]*"`
			local NAME=`basename $MODULE` 
			local NAME=${NAME%.*}

			echo -e "$DIR\tdrupal/$NAME\t$VERSION"
		done
		
    done
}
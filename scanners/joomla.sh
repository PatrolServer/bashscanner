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

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

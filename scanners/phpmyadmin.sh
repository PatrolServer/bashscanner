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

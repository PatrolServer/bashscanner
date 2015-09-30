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
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
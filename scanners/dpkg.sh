 #!/usr/bin/env bash

function DpkgSoftware {
   	if `command -v dpkg >/dev/null 2>&1`
	then
		local SUBSOFTWARE=`dpkg -l 2> /dev/null | grep '^i' | grep -v "lib" | tr -s ' ' | sed 's/ /\t/g'| cut -f2,3`

	   	for LINE in $SUBSOFTWARE; do
	   		NAME=`echo $LINE | cut -f1`
			VERSION=`echo $LINE | cut -f2`

			NAME=`Jsonspecialchars $NAME`
			VERSION=`Jsonspecialchars $VERSION`

			echo -e "/\t\t$NAME\t$VERSION" >> $SOFTWARE
		done
	fi
}
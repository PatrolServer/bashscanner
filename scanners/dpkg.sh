 #!/usr/bin/env bash

function DpkgSoftware {
   	local SOFTWARE=`dpkg -l | grep '^i' | tr -s ' ' | sed 's/ /\t/g'| cut -f2,3`

   	for LINE in $SOFTWARE; do
   		NAME=`echo $LINE | cut -f1`
		VERSION=`echo $LINE | cut -f2`

		NAME=`Jsonspecialchars $NAME`
		VERSION=`Jsonspecialchars $VERSION`

		echo -e "/\t$NAME\t$VERSION"
	done
}
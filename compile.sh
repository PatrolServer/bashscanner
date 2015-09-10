#!/usr/bin/env bash

. env.sh

SetEnv

COMPILED=$(cat index.sh)
INCLUDES=$(grep "^\. " < index.sh)

for INCLUDE in $INCLUDES; do
	FILE=$(echo "$INCLUDE" | cut -d ' ' -f2)
	FILE_CONTENTS=$(cat "$FILE")
	COMPILED="${COMPILED/$INCLUDE/$FILE_CONTENTS}"
done

echo "$COMPILED" > compiled.sh
openssl dgst -sha256 -sign 	private.key -out compiled.sign compiled.sh 

ResetEnv
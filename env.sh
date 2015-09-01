#!/usr/bin/env bash

function SetEnv {
	# IFS for return function contents in newlines.
	OLDIFS=$IFS
	IFS=$'\n'

	# Set 77 error code as exit any subshell level.
	set -E
	trap '[ "$?" -ne 77 ] || exit 77' ERR
}

function ResetEnv {
	IFS=$OLDIFS
}

function Exit {
	exit 77;
}

function Random {
	cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}
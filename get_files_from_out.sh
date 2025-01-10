#!/bin/bash

set -e
set -o pipefail
set -u

SUPPORTED_TAGS="(FILE_BASE64)" # in form of (TAG1)|(TAG2)...

OUTDIR=${OUTDIR:-"out_files"}

TAG_IN_PROCESS=""
OUTFILE=""

get_start_tag()
{
	set +o pipefail # grep fails if can't find anything, which is expected
	echo "$1" | grep -oP "^<($SUPPORTED_TAGS)>" | sed "s~<~~" | sed "s~>~~"
	set -o pipefail
}

get_end_tag()
{
	set +o pipefail # grep fails if can't find anything, which is expected
	echo "$1" | grep -oP "^</($SUPPORTED_TAGS)>" | sed "s~</~~" | sed "s~>~~"
	set -o pipefail
}

process_generic_line()
{
	local line="$1"
	case "$TAG_IN_PROCESS" in
		"FILE_BASE64")
			if [[ ! -w "$OUTFILE" ]]
			then
				echo "ERROR: can't write into file $OUTFILE"
			else
				echo "$line" | base64 -d >> $OUTFILE	
			fi
			;;
		"")
			echo "$line"
	esac
}

tags_startup()
{
	local line="$1"
	case "$TAG_IN_PROCESS" in
		"FILE_BASE64")
			OUTFILE="${OUTDIR}/$(echo "$line" | awk '{ print $2 }')"
			mkdir -p "$(dirname "$OUTFILE")"
			truncate -s 0 "$OUTFILE"
			;;
		"")
			echo "FATAL! startup called when TAG_IN_PROGRESS not filled"
			exit 1
			;;
	esac
}

tags_finish()
{
	local line="$1"
	# by far nothing
}

while read -r line
do
	MAYBE_START_TAG="$(get_start_tag "$line")"
	MAYBE_END_TAG="$(get_end_tag "$line")"
	if [[ ! -z "$MAYBE_START_TAG" ]]
	then
		if [[ ! -z "$TAG_IN_PROCESS" ]]
		then
			echo "FATAL! start of $MAYBE_START_TAG met before ending of $TAG_IN_PROCESS"
			exit 1
		fi
		TAG_IN_PROCESS="$MAYBE_START_TAG"

		tags_startup "$line"
		
		continue
	elif [[ ! -z "$MAYBE_END_TAG" ]]
	then
		if [[ ! "$TAG_IN_PROCESS" == "$MAYBE_END_TAG" ]]
		then
			echo "FATAL! end of $MAYBE_END_TAG met before ending of $TAG_IN_PROCESS"
			exit 1
		fi

		tags_finish "$line"

		TAG_IN_PROCESS=""
		continue
	fi
	process_generic_line "$line"	
done
if [[ ! -z "$TAG_IN_PROCESS" ]]
then
	echo "FATAL! Input ended, but $TAG_IN_PROCESS still not closed!"
	exit 1
fi
exit 0

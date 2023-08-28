#!/bin/bash

if [[ $# -ne 2 ]]
then
	echo "usage: $0 <dir a> <dir b>"
	exit 1
fi

if [[ ! -d $1 ]] || [[ ! -d $2 ]]
then
	echo "usage: $0 <dir a> <dir b>"
fi

DIR_A=$1
DIR_B=$2

DIFF_CMD="diff -ruN"

for file in $(find $DIR_A -regextype awk -regex '(.*\.)([ch]$|[ch]pp$|[ch]xx$|in)')
do
	file=${file:2}
	if [[! -f $DIR_B$file ]]
	then
		continue
	fi
	$DIFF_CMD $DIR_A$file $DIR_B$file
done

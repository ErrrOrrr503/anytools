#!/bin/bash

set -o errexit
set -o pipefail
set -u

if [[ $# -ne 1 ]]
then
    echo "Usage: $0 <filename>"
    exit 1
fi

target_file=$(realpath -m "$1")
echo "target file: $target_file"

function get_parent_dir()
{
    local target_file="$1"
    local parent_dir="$(dirname "$target_file")"
    while [[ ! -d "$parent_dir" ]]
    do
        parent_dir=$(dirname "$parent_dir")
    done
    if [[ ! -d "$parent_dir" ]]
    then
        echo "Critical: parent_dir must always exist, check the code!" 1>&2
        exit 1
    fi
    echo "$parent_dir"
}

new_parent_dir=$(get_parent_dir "$target_file")

_fifo=""
_inotify_pid=""

function launch_inotifywait()
{
    local parent_dir="$1"
    if [[ -z "$_fifo" ]]
    then
        _fifo="$(mktemp -u)"
    fi
    if [[ ! -p "$_fifo" ]]
    then
        mkfifo "$_fifo"
    fi
    inotifywait -q -m -r -e create,moved_to --format "%w%f" "$parent_dir" > "$_fifo" &
    _inotify_pid=$!
}

function stop_inotifywait()
{
    if [[ -z "$_inotify_pid" ]]
    then
        return
    fi
    if [[ -z "$_fifo" ]]
    then
        echo "Critical: _fifo not set, but inotifywait launched!?" 1>&2
        exit 1
    fi
    kill "$_inotify_pid" >/dev/null 2&>1
    rm -f "$_fifo"
}

trap 'stop_inotifywait' EXIT

while true
do
    parent_dir="$new_parent_dir"
    stop_inotifywait
    launch_inotifywait "$parent_dir"
    echo "New parent dir: $parent_dir"

    while read -r created
    do
        if [ "$created" = "$target_file" ]
        then
            exit 0
        fi
        new_parent_dir=$(get_parent_dir "$target_file")
        echo "$new_parent_dir"
        if [[ ! "$parent_dir" = "$new_parent_dir" ]]
        then
            break
        fi 
    done < "$_fifo"
done

exit 1

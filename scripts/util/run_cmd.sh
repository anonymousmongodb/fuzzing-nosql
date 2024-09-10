#!/usr/bin/env bash


### https://stackoverflow.com/questions/9954794/execute-a-shell-function-with-timeout
function run_cmd {
    cmd="$1"; timeout="$2";
    grep -qP '^\d+$' <<< $timeout || timeout=10

    (
        eval "$cmd" &
        child=$!
        trap -- "" SIGTERM
        (
                sleep $timeout
                kill $child 2> /dev/null
        ) &
        wait $child
    )
}
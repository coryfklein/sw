#!/usr/bin/env bash
set -e

# Usage:
# sw
#  - start a stopwatch from 0, save start time
# sw [-r|--resume]
#  - start a stopwatch from the last saved start time (or current time if no last saved start time exists)
#  - "-r" stands for --resume

function finish {
  tput cnorm # Restore cursor
  exit 0
}

trap finish EXIT

# Use GNU date if possible as it's most likely to have nanoseconds available.
if hash gdate 2>/dev/null; then
    GNU_DATE=gdate
elif date --version 2> /dev/null | grep 'GNU coreutils' >/dev/null; then
    GNU_DATE=date
fi

function datef {
    if [[ -z "$GNU_DATE" ]]; then
        date "$@"
    else
        $GNU_DATE "$@"
    fi
}

# Display nanoseconsd only if supported
if datef +%N | grep -q N 2>/dev/null; then
    DATE_FORMAT="+%H:%M:%S"
else
    DATE_FORMAT="+%H:%M:%S.%N"
    NANOS_SUPPORTED=true
fi

tput civis # hide cursor

# If -r is passed, use saved start time from ~/.sw
if [[ "$1" == "-r" || "$1" == "--resume" ]]; then
    if [[ ! -f $HOME/.sw ]]; then
        datef +%s > $HOME/.sw
    fi
    START_TIME=$(cat $HOME/.sw)
else
    START_TIME=$(datef +%s)
    echo -n $START_TIME > $HOME/.sw
fi

# GNU date accepts the input date differently than BSD
if [[ -z "$GNU_DATE" ]]; then
    DATE_INPUT="-v-${START_TIME}S"
else
    DATE_INPUT="--date now-${START_TIME}sec"
fi

while [ true ]; do
    STOPWATCH=$(TZ=UTC datef $DATE_INPUT $DATE_FORMAT | ( [[ "$NANOS_SUPPORTED" ]] && sed 's/.\{7\}$//' || cat ) )
    printf "\r\e%s" $STOPWATCH
    sleep 0.03
done

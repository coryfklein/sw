#!/usr/bin/env bash

function finish {
  tput cnorm # Restore cursor
  exit 0
}

trap finish EXIT

START_SECONDS_SINCE_EPOCH=$(gdate +%s.%N | sed 's/.\{7\}$//')

tput civis # hide cursor

while [ true ]; do
    CURRENT_SECONDS=$(gdate +%s.%N | sed 's/.\{7\}$//')
    ELAPSED_SECONDS=$(echo "$CURRENT_SECONDS - $START_SECONDS_SINCE_EPOCH" | bc)
    DIGITS_BEFORE_DOT=$(echo "$ELAPSED_SECONDS" | sed 's/\..*$//')
    TOTAL_SECONDS_EVEN=${DIGITS_BEFORE_DOT:-0}
    SECONDS_IN_MINUTE=$(echo "$TOTAL_SECONDS_EVEN % 60" | bc)
    MINUTES=$(echo "$TOTAL_SECONDS_EVEN / 60" | bc)
    ELAPSED_CENTIS=$(echo $ELAPSED_SECONDS | sed 's/.*\.//')
    printf "\r\e[K%02d:%02d:%s" "${MINUTES}" "${SECONDS_IN_MINUTE}" "${ELAPSED_CENTIS}"
    sleep 0.01
done


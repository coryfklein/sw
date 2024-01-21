#!/usr/bin/env bash
set -e

VERSION=1.0.2

function echo_err {
  echo "$@" 1>&2
}

if [[ ${BASH_VERSINFO[0]} -lt 5 ]]; then
  echo_err \
"Error: your Bash is too old ($BASH_VERSION); this program requires at least 
Bash 5.0."
  exit 1
fi

function show_version {
  echo "sw $VERSION"
  echo ""
  echo "Licensed under the MIT license. Written by Cory Klein and others."
}

function show_usage {
  echo_fn=$1
  $echo_fn "Usage: sw [OPTION]..."
  $echo_fn "Display a continously updated stopwatch.

   -f   If possible, use the specified FIGlet font to render the
        stopwatch; FIGlet must be in PATH
   -r   If possible, use the timestamp in \$HOME/.sw as an initial time
        instead of the current time
   -h   Print this help and exit
   -v   Print version information and exit
"
}

show_version=
show_usage=
resume=

while getopts ":vhrf:" opt
do
    case "${opt}" in
        v) show_version=y;;
        h) show_usage=y;;
        f) ;;
        r) ;;
        ?) echo_err "sw: invalid option \"-$OPTARG\".";
           show_usage echo_err
           exit 1;;
    esac
done

if [[ $show_version = y ]]; then
  show_version
  exit 0
fi
if [[ $show_usage = y ]]; then
  show_usage echo
  exit 0
fi

OPTIND=1

while getopts ":vhrf:" opt
do
    case "${opt}" in
        f) STOPWATCH_FONT="$OPTARG";;
        r) resume=y;;
    esac
done

RENDER_CMD=(cat)
PADDING_TOP=
PADDING_LEFT=

if [[ -n "$STOPWATCH_FONT" ]]; then
  if ! command -v figlet &>/dev/null; then
    echo_err \
"WARNING: stopwatch font '$STOPWATCH_FONT' will not be used because FIGlet 
was not found in PATH."
  else
    if ! figlet -f "$STOPWATCH_FONT" "" >/dev/null; then
      echo_err \
"WARNING: stopwatch font '$STOPWATCH_FONT' will not be used because FIGlet 
reported an error"
    else
      RENDER_CMD=(figlet -f "$STOPWATCH_FONT")
      PADDING_TOP="\n"
      PADDING_LEFT=" "
    fi
  fi
fi

# Implements a signed subtraction for positive numbers A and B with equal
# number of digits after the decimal separator separator. The result is placed
# in _subtract_result and DOESN'T have a decimal separator (a multiplication
# by 10eN is implied). This function exists because it's unknown whether all
# Bash implementations could deal with EPOCH timestamps of microsecond
# precision.
function _subtract() {
  sign=
  difference=0
  borrow=0
  multiplier=1

  _subtract_result=0

  minuend=$1
  subtrahend=$2

  # Check if the the result is negative because the subtrahend is larger
  # (has more digits before the decimal separator and one of them is >0).

  for ((ii = ${#subtrahend} - ${#minuend} - 1; ii >= 0; ii--)); do
    if [[ ${subtrahend:ii:1} -ne 0 ]]; then
      minuend=$2
      subtrahend=$1
      sign=-
      break
    fi
  done

  # Loop over the digits right to left and subtract ignoring the decimal
  # separator.

  length=${#minuend}
  length=$((length--))

  for ((ii = -1; ii >= -length; ii--)); do
    dm=${minuend:ii:1}

    if [[ "$dm" = "." ]]; then
      continue
    fi

    if [[ $borrow -eq 1 ]]; then
      dm=$((dm-1))
      borrow=0
    fi
    if [[ $ii -lt ${#subtrahend} ]]; then
      ds=${subtrahend:ii:1}
    else
      ds=0
    fi
    if [[ $dm -lt $ds ]]; then
      borrow=1
      dm=$((dm+10))
    fi
    difference=$((difference + (dm - ds) * multiplier))
    multiplier=$((multiplier * 10))
  done

  # If we needed to borrow for the last digit the result is actually negative
  # subtract anew.

  if [[ $borrow -eq 1 ]]; then
    _subtract $2 $1
    sign=-
  fi

  _subtract_result=${sign}${difference}
}

stty_status=$(stty -a | grep -oh '\b-\?echo\b' || echo -n "echo")

function finish {
  # Restore the cursor and terminal echoing.
  tput cnorm
  stty $stty_status
  [ -e /proc/$$/fd/3 ] && exec 3<&-
  exit 0
}

trap finish EXIT

# Hide the cursor.
tput civis

# Disable echoing of characters inputted by the user (like return etc.) that
# could affect the vizualization.
stty -echo

# Open a file descriptor to a process that never generates any input. This
# is used to hack a sleep-like logic using read because read doesn't create
# a new process.
exec 3<> <(:) 2>/dev/null || {
  fifo=$(mktemp -u)
  mkfifo -m 700 "$fifo"
  exec 3<>"$fifo"
  rm "$fifo"
}

# Initialize the timestamp as close to the main loop as possible.

start_time=$EPOCHREALTIME
if [[ "$resume" == "y" ]]; then
  if [[ ! -f "$HOME/.sw" ]]; then
    echo "$start_time" > "$HOME/.sw"
  else
    prev_time=$(cat "$HOME/.sw")
    if [[ ! "$prev_time" =~ ^[1-9][0-9]*\.[0-9]{6}$ ]]; then
      echo_err \
"WARNING: Will not use timestamp from file \"$HOME/.sw\" because it's of
invalid form."
    else
      _subtract $start_time $prev_time
      if [[ $_subtract_result -lt 0 ]]; then
        echo_err \
"WARNING: Will not use timestamp from file \"$HOME/.sw\" because it refers to
the future."
      else
        start_time=$prev_time
      fi
    fi
  fi
else
  echo "$start_time" > "$HOME/.sw"
fi

echo -ne "$PADDING_TOP"

while true; do
  _subtract $EPOCHREALTIME $start_time
  ms=$((_subtract_result / 1000))
  printf "%02d:%02d:%02d.%03d\n\n" \
        $(((ms / (1000 * 60 * 60)) % 60)) \
        $(((ms / (1000 * 60)) % 60)) \
        $(((ms / 1000) %60)) \
        $((ms % 1000))
  read -t 0.05 -u 3 || true
done | stdbuf -oL "${RENDER_CMD[@]}" | {
  reset=0
  lines=0
  while IFS='' read line; do
    if [[ -z "$line" ]]; then
      reset=1
    else
      if [[ $reset -eq 1 ]]; then
        printf "\033[%dA" $lines
        reset=0
        lines=0
      fi
      echo "${PADDING_LEFT}${line}"
      lines=$((lines + 1))
    fi
  done
}


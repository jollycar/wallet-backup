#!/usr/bin/env bash
set -o errtrace

### CONFIGURATION #######################
#Location of encrypted backup with rdedup
encrypted_repository="~/wallets/repo"
encrypted_repository_zip="~/wallets/"
timeout_seconds=30

### DO NOT EDIT BELOW ###################
### UNLESS YOU KNOW WHAT YOU'RE DOING ###
#########################################

### CONSTANTS ###
version="0.2.0"

### GLOBAL FUNCTIONS ###
install_dir=$( cd "$( dirname "$(readlink -f "$0")" )" && pwd )
script_filename="`basename $0`"

trap_user() {
  echo " Exit by user..."
  exit 1
}

trap_error() {
  local error_code="$?"
  if [ $error_code -eq 1 ]; then
    exit 1
  fi
}

### TRAPS ###
trap "trap_user" SIGINT SIGTERM
trap 'trap_error' ERR

### LOCAL FUNCTIONS ###
info() {
  echo "This program will backup your cryptocurrency wallet(s)"
}

init_repository() {
  if [ -d $encrypted_repository ]; then
    echo "ERROR: Encrypted repository already exists at location $encrypted_repository"
    exit 1
  fi
  if confirm_yes "Create an encrypted repository at location $encrypted_repository? [y/N] "; then
    try_cmd "rdedup -d $encrypted_repository init"
    echo "SUCCESS: Created encrypted repository at location $encrypted_repository."
    echo "REMEMBER THIS PASSWORD OR YOU MAY LOSE YOUR COINS!"
  else
    echo "Doing nothing. Exiting..."
    exit 0
	fi
}

usage() {
  echo "Usage: ./$script_filename <subcommand> [<wallet>]"
  echo
  echo "Supported wallets are:"
  echo "$(wallets_supported)"
  echo
  echo "Available subcommands are:"
  echo "init: Create an encrypted repository"
	for function in $(functions_supported)
	do
    echo "$function: `./$script_filename $function info`"
	done
}

wallets_supported() {
  declare -a WALLET_ARRAY
  local files=$install_dir/wallets/*
  for file in $files
	do
    local wallet=$( echo "$file" | sed -e "s/.*wallets\/\(.*\).conf$/\1/" )
    WALLET_ARRAY=("${WALLET_ARRAY[@]}" "$wallet")
    echo -n "$wallet "
	done
  echo
}

functions_supported() {
  declare -a FUNCTIONS_ARRAY
  local files=$install_dir/functions/*
  for file in $files
	do
    local function=$( echo "$file" | sed -e "s/.*functions\/\(.*\)$/\1/" )
    FUNCTIONS_ARRAY=("${FUNCTIONS_ARRAY[@]}" "$function")
    echo -n "$function "
	done
  echo
}

valid_cmd() {
  "$@" &>/dev/null
  local status=$?
  if [ $status -ne 0 ]; then
    usage
    exit 1
  fi
  return $status
}

try_cmd() {
	eval $1
    if [ $? -ne 0 ]; then
      exit 1
    fi
  return $?
}

file_exist() {
  if [ ! -f $1 ]; then
    echo "ERROR: File $1 not found!"
    exit 1
  fi
}

read_config() {
  file_exist "$1"
  while read line; do
    export "$line"
  done <$1
}

confirm_yes() {
  read -r -p "$1" response
  case $response in
    [yY]) 
      return 0;
      ;;
    *)
      return 1;
      ;;
  esac
}

countdown() {
  for i in {100..1}; do
    printf "1:$i\n";
    current=`echo "scale=0;$i * $timeout_seconds / 100" | bc`
    printf "1:#Canceling backup in $current seconds...\n";
    sleep $interval;
  done
}

close_gracefully() {
  local pid=`pgrep -x $1 -o`
  if [ -z "$pid" ]; then
    echo "$1 is not running"
  else
    interval=`echo "scale=4;$timeout_seconds/100" | bc`
    countdown | yad --multi-progress --title="Make a choice" --text="$1 is currently running (PID: $pid), but needs to close to make a backup.\n Please Make a choice: " --text-align=center --bar="":NORM --button=I\ will\ close\ $1\ myself\ or\ ask\ me\ in\ $timeout_seconds\ seconds:101 --button=Close\ it\ now:102 --button=Cancel\:103 backup --timeout=$timeout_seconds
    answer=$?
    if [ "$answer" == "101" ]; then
      echo "User will close. Now going to wait for $timeout_seconds seconds"
      anywait $pid
      local is_running=$?
      if [ "$is_running" -gt 0 ]; then
        close_gracefully $1
      fi    
    elif [ "$answer" == "102" ]; then
      kill -15 $pid
      while kill -0 "$pid"; do
        sleep 0.5
        let counter=counter+1
        if [ $counter -gt $timeout_seconds ]; then
          echo "Waited more than $timeout_seconds seconds for $pname (PID: $1) to close"
          notify-send "Backup failed"
          return 1
        fi
        local try_pid=`pgrep -x $1`
        if [ -z "$try_pid" ]; then
          echo "Closed $1 (PID: $pid)"
          return
        fi
      done
      sleep 1
    elif [ "$answer" == "103" ]; then
      echo "Clicked canel button. Canceled backup..."
      exit 1
    elif [ "$answer" == "70" ]; then
      echo "Timed out. Canceled backup..."
      exit 1
    fi
  fi
}

anywait() {
  counter=0
  for pid in "$@"; do
    local pname="`ps --pid $1 -o comm h`"
    if [ -z "$pname" ]; then
      echo "$pname is not running"
      return 0
    else
      echo "Waiting... Giving user time to quit $pname (PID: $1)"
      while kill -0 "$1"; do
        sleep 1
        let counter=counter+1
        if [ $counter -gt $timeout_seconds ]; then
          echo "waited more than $timeout_seconds seconds for $pname (PID: $1) to close"
          return 64
        fi
        local try_pname="`ps --pid $1 -o comm h`"
        if [ -z "$try_pname" ]; then
          echo "User successfuly closed $pname (PID: $1)"
          return
        fi
      done
      return 0
    fi
  done
}

## MAIN ###
main() {
  if [ "$#" -lt 1 ]; then
    info
    usage
    exit 1
  fi
  local subcommand="$1"; shift
  case $subcommand in
    "init")
      init_repository
      exit 0
      ;;
    "-h"|"--help")
      usage
      exit 0
      ;;
    "-v"|"--version")
      ./$script_filename version show
      exit 0
      ;;
    esac
    
  export WORKINGDIR=$(dirname "$(echo "$0" | sed -e 's,\\,/,g')")
  if [ ! -e "$WORKINGDIR/functions/$subcommand" ]; then
    usage
    exit 1
  fi

  . "$WORKINGDIR/functions/$subcommand"
  valid_cmd type "cmd_$subcommand"
  cmd_$subcommand "$@"
}

main "$@"

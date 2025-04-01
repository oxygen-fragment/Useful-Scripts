#!/bin/bash

# Helper: print usage
usage() {
  echo "Usage:"
  echo "  $0 [path] <date in YYYY-MM-DD or YYYYMMDD format>"
  echo "Examples:"
  echo "  $0 2021-11-16               # searches in script directory"
  echo "  $0 /mnt/user/ 2021-11-16    # searches in specified path"
  exit 1
}

# Parse input
if [[ $# -eq 1 ]]; then
  search_dir="$(dirname "$0")"
  input_date="$1"
elif [[ $# -eq 2 ]]; then
  search_dir="$1"
  input_date="$2"
else
  usage
fi

# Parse date parts
if [[ "$input_date" =~ ^[0-9]{8}$ ]]; then
  yyyy=${input_date:0:4}
  mm=${input_date:4:2}
  dd=${input_date:6:2}
elif [[ "$input_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  IFS='-' read -r yyyy mm dd <<< "$input_date"
else
  echo "Invalid date format. Use YYYY-MM-DD or YYYYMMDD."
  exit 1
fi

# Validate date using date command
month_short=$(date -d "$yyyy-$mm-$dd" +%b 2>/dev/null)
month_long=$(date -d "$yyyy-$mm-$dd" +%B 2>/dev/null)

if [[ -z "$month_short" ]]; then
  echo "Invalid date. Please check your input."
  exit 1
fi

# Perform the find
echo "Searching in: $search_dir"
echo "Looking for files matching variations of: $yyyy-$mm-$dd"
find "$search_dir" -type f \( \
  -iname "*$yyyy$mm$dd*" -o \
  -iname "*$yyyy-$mm-$dd*" -o \
  -iname "*$dd-$mm-$yyyy*" -o \
  -iname "*$dd_$mm_$yyyy*" -o \
  -iname "*$yyyy.$mm.$dd*" -o \
  -iname "*$dd.$mm.$yyyy*" -o \
  -iname "*$yyyy $mm $dd*" -o \
  -iname "*$month_short*$dd*$yyyy*" -o \
  -iname "*$month_long*$dd*$yyyy*" \
\)

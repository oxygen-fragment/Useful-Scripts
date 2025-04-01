#!/bin/bash

# Check for input
if [ -z "$1" ]; then
  echo "Usage: $0 <date in YYYY-MM-DD or YYYYMMDD format>"
  exit 1
fi

input_date="$1"

# Try to parse the date
if [[ "$input_date" =~ ^[0-9]{8}$ ]]; then
  # Input is in YYYYMMDD format
  yyyy=${input_date:0:4}
  mm=${input_date:4:2}
  dd=${input_date:6:2}
else
  # Input is in YYYY-MM-DD or something close
  IFS='-' read -r yyyy mm dd <<< "$input_date"
fi

# Validate basic numbers
if [[ -z "$yyyy" || -z "$mm" || -z "$dd" ]]; then
  echo "Invalid date format. Use YYYY-MM-DD or YYYYMMDD."
  exit 1
fi

# Get month names
month_short=$(date -d "$yyyy-$mm-$dd" +%b 2>/dev/null)
month_long=$(date -d "$yyyy-$mm-$dd" +%B 2>/dev/null)

if [ -z "$month_short" ]; then
  echo "Invalid date provided."
  exit 1
fi

# Generate find command
find . -type f \( \
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

#!/bin/bash

# argument is to be one string that is to be saved to the
# log for the current year

curr_year=$(date +%Y)

dir_name=./library/logs/$curr_year
file_name=$dir_name/log_$curr_year

if [ ! -d  $dir_name ]; then mkdir -p $dir_name; fi

echo -e "$1" >> $file_name

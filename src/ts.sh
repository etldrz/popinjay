#!/bin/bash

cd library/books

t=$(ls)

for filepath in $t; do
    fields=()
    while read line; do
	line_split=($( echo $line | tr "~" "\n" ))
	fields+=("${line_split[*]:1}")
    done < "$filepath"
    if [ "${fields[5]}" = "n/a" ]; then
	fields[5]=""
    fi
    
    printf "%b" \
	   "title              ~ ${fields[0]}\n" \
	   "author             ~ ${fields[1]}\n" \
	   "isbn10/13          ~ ${fields[2]}\n" \
	   "read?              ~ ${fields[3]}\n" \
	   "owned?             ~ ${fields[4]}\n" \
	   "comments           ~ ${fields[5]}\n" \
	   "initial_entry_time ~ ${fields[6]}\n" \
	   "edit_time          ~ ${fields[7]}\n" > "$filepath"
    echo $filepath
done
    

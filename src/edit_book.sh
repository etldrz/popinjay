#!/bin/bash

# absolute path used for logging information
directory_path="$HOME/git/popinjay"
# containing all book data
library="$directory_path/library"
# where all actual book data are stored
all_books="$library/books"
# a set of symbolic links for all books owned is stored here
owned_books="$library/owned"
# a set of symbolic links for all books read is stored here
read_books="$library/read"
# reading data write path
reading_data="$library/reading_data"
# to be cleaned out in regular intervals
trash="$library/trash"

# The deliminator used to seperate fields from values in each book file.
# Chosen because it is not commonly used in language.
bookfile_delim="~"

# args: input_string filepath

# each book file is organized as
#
# title:BOOK_TITLE
# author:BOOK_AUTHOR
# isbn10/13:ISBN
# read?:HAS_BEEN_READ
# owned?:IS_OWNED
# comments:BOOK_COMMENTS
# edit_time:MOST_RECENT_EDIT_TIME
# initial_entry_time:TIME_OF_ENTRY

# retrieves the necessary data
fields=()
while read line; do
    line_split=($( echo $line | tr "$bookfile_delim" "\n" ))
    fields+=("${line_split[*]:1}")
done < $2

# when made true, then the data is re-entered and the old file
# overwritten.
edited=false

# when made true, corresponding symlinks to the designated files
# for ownership and reading will be made
read_status_changed=false
owned_status_changed=false

while true; do
    # displays the prompt as '(popinjay > BOOK) '.
    # gets the book name from the fields instead of filename to
    # allow for updates.
    bookname="${fields[0]// /_},${fields[1]// /_}"
    filepath="$all_books/${bookname}.txt"
    read -e -p "($1 > ${bookname}) " input

    # allows for editing of the fields for each book. also
    # includes a help and delete command. each field can be
    # edited by just typing the field name within this sub-process
    # and altering the text that appears.
    case $input in
    	'exit'|'back')
    	    break
    	    ;;
    	'title')
    	    read -e -i "${fields[0]}" new_title
    	    if [ "$new_title" = "${fields[0]}" ]; then
    		continue
    	    fi
    	    fields[0]="$new_title"
    	    edited=true
    	    ;;
    	'author')
    	    read -e -i "${fields[1]}" new_author
    	    if [ "$new_author" = "${fields[1]}" ]; then
    		continue
    	    fi
    	    fields[1]="$new_author"
    	    edited=true
    	    ;;
    	'isbn10/13'|'isbn')
    	    read -e -i "${fields[2]}" new_isbn
    	    if [ "$new_isbn" = "${fields[2]}" ]; then
    		continue
    	    fi
    	    fields[2]="$new_isbn"
    	    edited=true
    	    ;;
    	'read?'|'read')
    	    echo "The current status of the book is" \
    		 "read?=${fields[3]}"
    	    select bool in "true" "false"; do
    		break
    	    done
    	    
    	    if [ $bool = "${fields[3]}" ]; then continue; fi

    	    read_status_changed=true

    	    fields[3]=$bool
    	    edited=true
    	    ;;
    	'owned?'|'owned')
    	    echo "The current status of the book is" \
    		 "owned?=${fields[4]}"
    	    select bool in "true" "false"; do
    		break
    	    done

    	    if [ "$bool" = "${fields[4]}" ]; then continue; fi

    	    owned_status_changed=true

    	    fields[4]="$bool"
    	    edited=true
    	    ;;
    	'comments'|'comment')
    	    read -e -i "${fields[5]}" new_comments
    	    if [ "$new_comments" = "${fields[5]}" ]; then
    		continue
    	    fi
    	    fields[5]="$new_comments"
    	    edited=true
    	    ;;
    	'help'|'h')
    	    echo "Here is the book metadata as it currently " \
    		 "stands. Call any non-time field to edit it. " \
    		 "Call delete to remove the book from the library."
    	    echo
    	    printf "%b" \
    		   "title              $bookfile_delim ${fields[0]}\n" \
    		   "author             $bookfile_delim ${fields[1]}\n" \
    		   "isbn10/13          $bookfile_delim ${fields[2]}\n" \
    		   "read?              $bookfile_delim ${fields[3]}\n" \
    		   "owned?             $bookfile_delim ${fields[4]}\n" \
    		   "comments           $bookfile_delim ${fields[5]}\n" \
    		   "initial_entry_time $bookfile_delim ${fields[6]}\n" \
    		   "edit_time          $bookfile_delim $(date)\n\n"
    	    echo "Exit from this subspace via 'back'/'exit'."
    	    continue
    	    ;;
    	'delete')
    	    # removes all files found in order to also get symbolic links
    	    found=$(find $library -name "*${bookname}*" -not -path "${trash}/*")
    	    for file in ${found[*]}; do
    		mv "$file" "$trash/$(basename -- "$file")"
    	    done
    	    break
    	    ;;
    	*)
    	    echo "Not a viable request"
    	    continue
    	    ;;
    esac
done

# if theres been a change of information, then the filepath is
# written to
if [ $edited = true ]; then
    printf "%b" \
    	   "title              $bookfile_delim ${fields[0]}\n" \
    	   "author             $bookfile_delim ${fields[1]}\n" \
    	   "isbn10/13          $bookfile_delim ${fields[2]}\n" \
    	   "read?              $bookfile_delim ${fields[3]}\n" \
    	   "owned?             $bookfile_delim ${fields[4]}\n" \
    	   "comments           $bookfile_delim ${fields[5]}\n" \
    	   "initial_entry_time $bookfile_delim ${fields[6]}\n" \
    	   "edit_time          $bookfile_delim $(date)\n" > "$filepath"
    echo "$bookname has been edited successfully"
fi

# if the original path passed to this sub-process does not match
# the current one, the original is removed.
if [ ! "$2" = "$filepath" ]; then
    original_name=$(basename -- "$2")
    original_name="${original_name%.*}"

    # gets each symlink of the old name and replaces it with a symlink to the
    # new file name
    found=$(find $library -name "*${original_name}" -not -path "${all_books}/*")
    for curr in $found; do
    	curr_full_dir=$(dirname "$curr")
    	ln -s "$filepath" "$curr_full_dir/$bookname"
    	unlink "$curr"
    done

    # removes the old file from library/books
    mv "$2" "$trash/$(basename -- "$2")"
fi

# if the value of read? is changed, then add or remove the appropriate
# symlink as needed
if [ $read_status_changed = true ] && [ "${fields[3]}" = "true" ]; then
    ln -s "$filepath" "$read_books/$bookname"
elif [ $read_status_changed = true ] && [ "$fields[3]" = "false" ]; then
    for file in $(find "$reading_data" -name "$bookname"); do
    	rm "$file" 
    done
fi

# if the value of owned? is changed, then add or remove the appropriate
# symlink as needed
if [ $owned_status_changed = true ] && [ "${fields[4]}" = "true" ]; then
    ln -s "$filepath" "$owned_books/$bookname"
elif [ $owned_status_changed = true ] && [ "${fields[4]}" = "false" ]; then
    rm -f "$owned_books/$bookname"
fi

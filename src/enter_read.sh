#!/bin/bash

# absolute path used for logging information
directory_path="$HOME/git/popinjay"
# path to scripts
src="$directory_path/src"
PATH="$PATH:$src"
# containing all book data
library="$directory_path/library"
# where all actual book data are stored
all_books="$library/books"
# a set of symbolic links for all books read is stored here
read_books="$library/read"
# reading data write path
reading_data="$library/reading_data"

# The deliminator used to seperate fields from values in each book file.
# Chosen because it is not commonly used in language.
bookfile_delim="~"

# takes information about a book which has been read
# and stores it in a file built for the year/month
# of entry.
while true; do
    read -p "Is it already in the system? If unsure, it is \
better to assume yes and search for it. " yn
    case $yn in
    	[Yy]*)
    	    in_system=true
    	    break
    	    ;;
    	[Nn]*)
    	    in_system=false
    	    break
    	    ;;
    	*)
    	    echo "Please answer y or n."
    	    ;;
    esac
done

# prompt options tacked onto the two relevant options for the find/select
# combination used in the below loop: no results, at least one result 
again="Search again"
new="Create a new entry"
to_main="Back to main"

# this loop will repeat until an appropriate book file is given in some manner.
# The user also has the option to return to the main aspect of popinjay via the select
name_given=false
while ! $name_given; do
    if [ $in_system = true ]; then
    	read -p "Enter search query (case sensitive): " query

    	query="*${query// /_}*"
    	found=($(find "$all_books" -maxdepth 1 -name "$query"))
    	if [ ${#found[*]} = 0 ]; then
    	    echo "The query '${query}' didn't turn up any results."
    	    select opt in "$again" "$new" "$to_main"; do
    		if [ "$opt" = "$again" ]; then
    		    # breaks out of select and goes to the top of the loop
    		    break
    		elif [ "$opt" = "$new" ]; then
    		    # breaks out of the select and triggers the else of the
    		    # parent loop
    		    in_system=false
    		    break
    		elif [ "$opt" = "$to_main" ]; then
    		    # returns to the main popinjay loop
    		    return
    		fi
    	    done
    	else
    	    declare -A title_author
    	    for filepath in ${found[*]}; do
    		fields=()
    		while read line; do
    		    line_split=($( echo $line | tr "$bookfile_delim" "\n" ))
    		    fields+=("${line_split[*]:1}")
    		done < "$filepath"
    		curr="${fields[0]}, by ${fields[1]}"
    		title_author["$curr"]="$filepath"
    	    done
    	    select opt in "${!title_author[@]}" "$again" "$new" "$to_main"; do
    		if [ "$opt" = "$again" ]; then
    		    break
    		elif [ "$opt" = "$new" ]; then
    		    in_system=false
    		    break
    		elif [ "$opt" = "$to_main" ]; then
    		    return;
    		else
    		    filepath="${title_author[$opt]}"
    		    name_given=true
    		    break
    		fi
    	    done
    	fi
    else
    	enter_owned.sh true
    	# gets the most recently edited file
    	filepath="$all_books/$(ls -t $all_books | head -n1)"
    	name_given=true
    fi
done

fields=()
while read line; do
    line_split=($( echo $line | tr "$bookfile_delim" "\n" ))
    fields+=("${line_split[*]:1}")
done < "$filepath"

filename=$(basename -- "$filepath")
filename="${filename%.*}"

if [ ! "${fields[3]}" = "true" ] && [ $in_system = true ]; then
    fields[3]="true"
    printf "%b" \
    	   "title              $bookfile_delim ${fields[0]}\n" \
    	   "author             $bookfile_delim ${fields[1]}\n" \
    	   "isbn10/13          $bookfile_delim ${fields[2]}\n" \
    	   "read?              $bookfile_delim ${fields[3]}\n" \
    	   "owned?             $bookfile_delim ${fields[4]}\n" \
    	   "comments           $bookfile_delim ${fields[5]}\n" \
    	   "initial_entry_time $bookfile_delim ${fields[6]}\n" \
    	   "edit_time          $bookfile_delim $(date)\n" > "$filepath"

    all_read_symlink="$read_books/$filename"
    ln -s "$filepath" "$all_read_symlink"

    echo "The book's status has been updated to 'read?=true'"
fi

year=$(date +%Y)
month=$(date +%b)
yeardir="$reading_data/$year"
monthdir="$yeardir/$month"

if [ ! -d $yeardir ]; then
    mkdir $yeardir
    echo
    echo "You have just logged your first book for ${year}. "\
    	 "The appropriate directory has been created."
fi

if [ ! -d $monthdir ]; then
    mkdir $monthdir
    echo
    echo "You have just logged your first book for $(date +%B). "\
    	 "The appropriate directory has been created."
fi

time_read_symlink="$monthdir/$filename"
# ensuring that multiple entries of the same book can be logged
# per month
while [ -f $time_read_symlink ]; do
    time_read_symlink+=_another
done

ln -s "$filepath" "$time_read_symlink"

echo "$filename has been successfully logged for $year/$month"

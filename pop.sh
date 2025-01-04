#!/bin/bash

# absolute path used for logging information
directory_path=~/git/popinjay

# called when a single book is being edited, a subshell of popinjay
edit_book() {
    # args: input_string filepath library_path

    # each book file is organized as
    #
    # title:BOOK_TITLE
    # author:BOOK_AUTHOR
    # isbn10/13:ISBN
    # read?:HAS_BEEN_READ
    # edition:BOOK_EDITION
    # edit_time:MOST_RECENT_EDIT_TIME
    # initial_entry_time:TIME_OF_ENTRY

    # retrieves the necessary data
    fields=()
    while read line; do
	line_split=($( echo $line | tr ":" "\n" ))
	fields+=("${line_split[*]:1}")
    done < $2
	
    # when made true, then the data is re-entered and the old file overwritten
    edited=false

    while true; do
	# displays the prompt as '(popinjay > BOOK) '
	filename="${fields[0]// /_},${fields[1]// /_}"
	filepath="${3}${filename}.txt"
	read -e -p "($input_string > $filename) " input

	# allows for editing of the fields for each book. also includes a help and delete command.
	# each field can be edited by just typing the field name within this sub-process
	# and altering the text that appears.
	case $input in
	    'exit'|'back')
		break
		;;
	    'title')
		read -e -i "${fields[0]}" new_title
		if [[ "$new_title" == "${fields[0]}" ]]; then
		    continue
		fi
		fields[0]="$new_title"
		edited=true
		;;
	    'author')
		read -e -i "${fields[1]}" new_author
		if [[ "$new_author" == "${fields[1]}" ]]; then
		    continue
		fi
		fields[1]="$new_author"
		edited=true
		;;
	    'isbn10/13'|'isbn')
		read -e -i "${fields[2]}" new_isbn
		if [[ "$new_isbn" == "${fields[2]}" ]]; then
		    continue
		fi
		fields[2]="$new_isbn"
		edited=true
		;;
	    'read?'|'read')
		read -e -i "${fields[3]}" new_read?
		if [[ "$new_read?" == "${fields[3]}" ]]; then
		    continue
		fi
		fields[3]="$new_read?"
		edited=true
		;;
	    'edition')
		read -e -i "${fields[4]}" new_edition
		if [[ "$new_edition" == "${fields[4]}" ]]; then
		    continue
		fi
		fields[4]="$new_edition"
		edited=true
		;;
	    'help'|'h')
		echo "Here is the book metadata as it currently stands. Call any non-time field to edit it. " \
		     "Call delete to remove the book from the library."
		echo
		printf "%b" \
		       "title             : ${fields[0]}\n" \
		       "author            : ${fields[1]}\n" \
		       "isbn10/13         : ${fields[2]}\n" \
		       "read?             : ${fields[3]}\n" \
		       "edition           : ${fields[4]}\n" \
		       "initial_edit_time : ${fields[5]}\n" \
		       "edit_time         : $(date)\n"
		echo
		continue
		;;
	    'delete')
		rm $filepath
		break
		;;
	    
	    *)
		echo "Not a viable request"
		continue
		;;
	esac
    done

    # if theres been a change of information, then the filepath is written to
    if [ "$edited" = true ]; then
	printf "%b" \
	       "title             : ${fields[0]}\n" \
	       "author            : ${fields[1]}\n" \
	       "isbn10/13         : ${fields[2]}\n" \
	       "read?             : ${fields[3]}\n" \
	       "edition           : ${fields[4]}\n" \
	       "initial_edit_time : ${fields[5]}\n" \
	       "edit_time         : $(date)\n" > $filepath
	echo "$filename has been edited successfully"
    fi

    # if the original path passed to this sub-process does not match the current
    # one, the original is removed.
    if [ ! "$2" == $filepath ]; then
	rm $2
    fi
}

start_bookkeeping() {
    # write location
    library="${directory_path}/library/"

    if [ ! -d $library ]; then
	mkdir $library
	printf "%b" \
	       "The necessary directory '$(readlink -f $library)' wasn't found; " \
	       "it has been created.\n\n"
    fi

    # file used to store history for cycling back through commands
    pop_history=${directory_path}/.popinjay_history
    history -cr $pop_history

    echo "Entering library data, type exit to leave."

    while true; do
	input_string="popinjay"
	read -e -p "(${input_string}) " input
	# Don't ever call him a monkey!

	# can either enter in a new book or edit one already-entered
	case $input in
	    'exit')
		break
		;;
	    'new'|'n')
		# gets all the needed data from the user
		read -p "title: " title
		read -p "author: " author
		if [[ "$title" == "" && "$author" == "" ]]; then
		    continue
		fi
		read -p "isbn10/13: " isbn
		# keeps going until y/n given
		while true; do
		    read -p "have you read it? " yn
		    case $yn in
			[Yy]*)
			    has_read="true"
			    break
			    ;;
			[Nn]*)
			    has_read="false"
			    break
			    ;;
			*)
			    echo "Please answer y or n."
			    ;;
		    esac
		done
		read -p "edition: " edition
		entry_time=$(date)

		# the file path combines title and author and replaces all spaces with underscores
		file_title="${library}${title// /_},${author// /_}.txt"

		# in case of repeated entries (different copies of same book)
		while [ -f $file_title ]; do
		    file_title+=_another
		done

		printf "%b" \
		       "title:${title}\n" \
		       "author:${author}\n" \
		       "isbn10/13:${isbn}\n" \
		       "read?:${has_read}\n" \
		       "edition:${edition}\n" \
		       "initial_entry_time:${entry_time}\n" \
		       "edit_time:${entry_time}\n" > $file_title

		echo "successfully logged '$file_title'"
		history -s $input
		continue
		;;
	    'get')
		# uses find to get a list of books matching search query, from which the
		# user can select from if there is more than one option.
		read -p "Enter search query: " to_search
		to_search=*${to_search// /*}*
		found=($(find $library -name "${to_search}"))
		if [ ${#found[*]} -eq 0 ]; then
		    echo "Bad search query of '$to_search'"
		    continue
		elif [ ${#found[*]} -gt 1 ]; then
		    echo "multiple results gotten, select the best match"
		    select f in ${found[*]}; do
			gotten=$f
			break
		    done
		else
		    gotten=${found}
		fi

		# passes the string used in front of commands, the requested file, and the path
		# to the library
		edit_book $input_string $gotten $library
		history -s $input
		continue
		;;
	    *)
		echo "haven't the fucking foggiest"
		continue
		;;
	esac
    done

    # logs history to the history file for popinjay
    history -a ${pop_history}
    history -cr ~/.bash_history
    echo "Exited library"
}

trap 'history -a ${directory_path}/.popinjay_history;exit' EXIT
start_bookkeeping

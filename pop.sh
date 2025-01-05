#!/bin/bash


# issue: when select is used there is no way for the user
# to select no option without C-c

# absolute path used for logging information
directory_path=~/git/popinjay/
# library write path
library="${directory_path}library/"
# reading data write path
reading_data="${library}reading_data/"

if [ ! -d $library ]; then mkdir $library; fi
if [ ! -d $reading_data ]; then mkdir $reading_data; fi


enter_book() {
    # args: from_enter_read?
    #         a boolean  which determines whether popinjay asks if
    #         the book is owned vs the book is read. Asks former if
    #         enter_book gets called from enter_read vs the 'new'
    #         command of start_bookkeeping


    # gets all the needed data from the user
    read -p "title: " title
    read -p "author: " author
    # allows for the user to opt-out of the command
    if [[ "$title" == "" && "$author" == "" ]]; then
	return
    fi
    read -p "isbn10/13: " isbn

    if [ "$1" = true ]; then
	prompt="do you own it? "
    else
	prompt="have you read it? "
    fi
    while true; do
	read -p "$prompt" yn
	case $yn in
	    [Yy]*)
		book_status="true"
		break
		;;
	    [Nn]*)
		book_status="false"
		break
		;;
	    *)
		echo "Please answer y or n."
		;;
	esac
    done
    read -p "edition: " edition
    entry_time=$(date)

    # the file path combines title and author and replaces
    # all spaces with underscores
    file_title="${library}${title// /_},${author// /_}.txt"

    # in case of repeated entries (different copies of
    # same book)
    while [ -f $file_title ]; do
	file_title+=_another
    done

    if [ "$1" = true ]; then
	has_read=true
	owned=$book_status
    else
	has_read=$book_status
	owned=true
    fi

    printf "%b" \
	   "title              : ${title}\n" \
	   "author             : ${author}\n" \
	   "isbn10/13          : ${isbn}\n" \
	   "read?              : ${has_read}\n" \
	   "owned?             : ${owned}\n" \
	   "edition            : ${edition}\n" \
	   "initial_entry_time : ${entry_time}\n" \
	   "edit_time          : ${entry_time}\n" > $file_title

    echo "successfully logged '$file_title'"
}


enter_read() {
    
    # takes information about a book which has been read
    # and stores it in a file built for the year/month
    # of entry.
    while true; do
	read -p "Is it already in the system? " yn
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

    name_given=false
    while ! $name_given; do
	if [ $in_system = true ]; then
    	    read -p "Enter a search query: " query
	    query="*${query}*"
    	    found=($(find "$library" -maxdepth 1 -name "$query"))

	    if [ ${#found[*]} -eq 0 ]; then
		echo "The query '${query}' didn't turn up any results."
		select opt in "search again" "create a new entry"; do
		    if [[ "$opt" == "search again" ]]; then
			break
		    fi
		    in_system=false
		    break
		done
		continue
	    elif [ ${#found[*]} -eq 1 ]; then
		filepath=${found}
		name_given=true
		continue
	    else
		select f in ${found[*]}; do
		    filepath=$f
		    name_given=true
		    break
		done
		continue
	    fi
	else
	    enter_book true
	    # gets the most recently edited file
	    filepath="${library}$(ls -t $library | head -n1)"
	    name_given=true
	    continue
	fi
    done

    fields=()
    while read line; do
	line_split=($( echo $line | tr ":" "\n" ))
	fields+=("${line_split[*]:1}")
    done < "$filepath"

    if [[ ! "${fields[3]}" == "true" ]]; then
	fields[3]="true"
	printf "%b" \
	       "title             : ${fields[0]}\n" \
	       "author            : ${fields[1]}\n" \
	       "isbn10/13         : ${fields[2]}\n" \
	       "read?             : ${fields[3]}\n" \
	       "owned?            : ${fields[4]}\n" \
	       "edition           : ${fields[5]}\n" \
	       "initial_edit_time : ${fields[6]}\n" \
	       "edit_time         : $(date)\n" > "$filepath"
	echo "The book's status has been updated to 'read?=true'"
    fi

    year="${reading_data}$(date +%Y)/"
    month="${year}$(date +%b)"

    if [ ! -d $year ]; then
	mkdir $year
	echo
	echo "$year has been created"
	echo
    fi

    if [ ! -d $month ]; then
	mkdir $month
	echo
	echo "$month has been created"
	echo
    fi

    filename=$(basename -- "$filepath")
    filename="${filename%.*}"

    linkpath="${month}/${filename}"

    ln -s "$filepath" "$linkpath"

    echo
    echo "The book has been successfully logged as '${linkpath}'"
}


# called when a single book is being edited, a subshell of popinjay
edit_book() {
    # args: input_string filepath library_path

    # each book file is organized as
    #
    # title:BOOK_TITLE
    # author:BOOK_AUTHOR
    # isbn10/13:ISBN
    # read?:HAS_BEEN_READ
    # owned?:IS_OWNED
    # edition:BOOK_EDITION
    # edit_time:MOST_RECENT_EDIT_TIME
    # initial_entry_time:TIME_OF_ENTRY

    # retrieves the necessary data
    fields=()
    while read line; do
	line_split=($( echo $line | tr ":" "\n" ))
	fields+=("${line_split[*]:1}")
    done < $2
	
    # when made true, then the data is re-entered and the old file
    # overwritten.
    edited=false

    while true; do
	# displays the prompt as '(popinjay > BOOK) '.
	# gets the book name from the fields instead of filename to
	# allow for updates.
	bookname="${fields[0]// /_},${fields[1]// /_}"
	filepath="${3}${bookname}.txt"
	read -e -p "($input_string > $bookname) " input

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
		echo "The current status of the book is "\
		     "read?=${fields[3]}"
		select bool in "true" "false"; do
		    break
		done
		
		if [[ "$bool" == "${fields[3]}" ]]; then
		    continue
		fi
		fields[3]="$bool"
		edited=true
		;;
	    'owned?'|'owned')
		echo "The current status of the book is " \
		     "owned?=${fields[4]}"
		select bool in "true" "false"; do
		    break
		done

		if [[ "$bool" == "${fields[4]}" ]]; then
		    continue
		fi
		fields[4]="$bool"
		edited=true
		;;
	    'edition')
		read -e -i "${fields[5]}" new_edition
		if [[ "$new_edition" == "${fields[5]}" ]]; then
		    continue
		fi
		fields[5]="$new_edition"
		edited=true
		;;
	    'help'|'h')
		echo "Here is the book metadata as it currently " \
		     "stands. Call any non-time field to edit it. " \
		     "Call delete to remove the book from the library."
		echo
		printf "%b" \
		       "title             : ${fields[0]}\n" \
		       "author            : ${fields[1]}\n" \
		       "isbn10/13         : ${fields[2]}\n" \
		       "read?             : ${fields[3]}\n" \
		       "owned?            : ${fields[4]}\n" \
		       "edition           : ${fields[5]}\n" \
		       "initial_edit_time : ${fields[6]}\n" \
		       "edit_time         : $(date)\n"
		continue
		;;
	    'delete')
		rm "$filepath"
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
    if [ "$edited" = true ]; then
	printf "%b" \
	       "title             : ${fields[0]}\n" \
	       "author            : ${fields[1]}\n" \
	       "isbn10/13         : ${fields[2]}\n" \
	       "read?             : ${fields[3]}\n" \
	       "owned?            : ${fields[4]}\n" \
	       "edition           : ${fields[5]}\n" \
	       "initial_edit_time : ${fields[6]}\n" \
	       "edit_time         : $(date)\n" > "$filepath"
	echo "$bookname has been edited successfully"
    fi

    # if the original path passed to this sub-process does not match
    # the current one, the original is removed.
    if [ ! "$2" == "$filepath" ]; then
	rm $2
    fi
}

start_bookkeeping() {

    if [ ! -d $library ]; then
	mkdir $library
	printf "%b" \
	       "The necessary directory '$(readlink -f $library)' " \
	       "wasn't found; it has been created.\n\n"
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
		enter_book false
		history -s $input
		continue
		;;
	    'get')
		# uses find to get a list of books matching search
		# query, from which the user can select from if there
		# is more than one option.
		read -p "Enter search query: " to_search

		# blank entry opts out of command
		if [[ "$to_search" == "" ]]; then
		    continue
		fi
		
		# this value is passed to find, which returns a list
		# from which the user can select some result
		to_search=*${to_search// /*}*
		found=($(find "$library" -maxdepth 1 -name "${to_search}"))
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

		# passes the string used in front of commands, the
		# requested file, and the path to the library
		edit_book $input_string $gotten $library
		history -s $input
		continue
		;;
	    'read'|'r')
		enter_read
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

#!/bin/bash


# issue: when using the exit feature of enter_book by pressing enter twice
# enter_read will still grab the most recently edited file and make changes to
# it.

# issue: when switching back and forth between bools for read/owned while in
# the 'get' menu the code could potentially try to create symlinks that already
# exist

# absolute path used for logging information
directory_path=~/git/popinjay
# containing all book data
library=${directory_path}/library
# where all actual book titles are stored
all_books=${library}/books
# a set of symbolic links for all books owned is stored here
owned_books=${library}/owned_books
# reading data write path
reading_data=${library}/reading_data
# a set of symbolic links for all books read is stored here
read_books=${reading_data}/read_books

for dir in $directory_path $library $all_books $owned_books \
	   $reading_data $read_books; do
    if [ ! -d $dir ]; then mkdir $dir; fi
done

# called when a new book is being put into the system,
# via either the 'new'or 'read' commands
enter_book() {
    # args: from_enter_read?
    #         a boolean  which determines whether popinjay asks if
    #         the book is owned vs the book is read. Asks former if
    #         enter_book gets called from enter_read vs the 'new'
    #         command of start_bookkeeping

    # gets all the needed data from the user
    read -p "title: " title
    read -p "author/editor: " author
    # allows for the user to opt-out of the command
    if [[ "$title" == "" && "$author" == "" ]]; then
	return
    fi
    read -p "isbn10/13: " isbn

    if [ $1 = true ]; then
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
    read -p "comments: " comments
    entry_time=$(date)

    # the file path combines title and author and replaces
    # all spaces with underscores
    translated_name="${title// /_},${author// /_}"
    filename="${all_books}/${translated_name}.txt"

    # in case of repeated entries (different copies of
    # same book)
    while [ -f $filename ]; do
	filename+=_another
    done

    if [ "$1" = true ]; then
	has_read=true
	owned=$book_status
    else
	has_read=$book_status
	owned=true
    fi

    printf "%b" \
    	   "title              ~ ${title}\n" \
    	   "author             ~ ${author}\n" \
    	   "isbn10/13          ~ ${isbn}\n" \
    	   "read?              ~ ${has_read}\n" \
    	   "owned?             ~ ${owned}\n" \
    	   "comments           ~ ${comments}\n" \
    	   "initial_entry_time ~ ${entry_time}\n" \
    	   "edit_time          ~ ${entry_time}\n" > $filename

    read_path_symlink="${read_books}/${translated_name}"
    if [ $has_read == true ] && [ ! -f "$read_path_symlink" ]; then
	ln -s "$filename" "$read_path_symlink"
    fi
    owned_path_symlink="${owned_books}/${translated_name}"
    if [ $owned == true ] && [ ! -f "$owned_path_symlink" ]; then
	ln -s "$filename" "$owned_path_symlink"
    fi

    echo
    echo "Successfully created an entry for 'library/books/${title// /_},${author// /_}'"
}


enter_read() {
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

    again="Search again"
    new="Create a new entry"
    to_main="Back to main"

    # this loop will repeat until an appropriate book file is given
    name_given=false
    while ! $name_given; do
	if [ $in_system = true ]; then
    	    read -p "Enter search query (case sensitive): " query

	    query="*${query// /_}*"
    	    found=($(find "$all_books" -maxdepth 1 -name "$query"))
	    if [ ${#found[*]} = 0 ]; then
		echo "The query '${query}' didn't turn up any results."
		select opt in "$again" "$new" "$to_main"; do
		    if [[ "$opt" == "$again" ]]; then
			break
		    elif [[ "$opt" == "$new" ]]; then
			in_system=false
			break
		    elif [[ "$opt" == "$to_main" ]]; then
			return
		    fi
		done
	    elif [ ${#found[*]} = 1 ]; then
		select f in ${found[*]} "$again" "$new" "$to_main"; do
		    if [[ "$f" == "$again" ]]; then
			break
		    elif [[ "$f" == "$new" ]]; then
			in_system=false
			break
		    elif [[ "$f" == "$to_main" ]]; then
			return
		    else
			filepath=${found}
			name_given=true
			break
		    fi
		done
	    else
		select f in ${found[*]} "$again" "$new" "$to_main"; do
		    if [[ "$f" == "$again" ]]; then
			break
		    elif [[ "$f" == "$new" ]]; then
			in_system=false
			break
		    elif [[ "$f" == "$to_main" ]]; then
			return;
		    fi

		    filepath="$f"
		    name_given=true
		    break
		done
	    fi
	else
	    enter_book true
	    # gets the most recently edited file
	    filepath="${all_books}/$(ls -t $all_books | head -n1)"
	    name_given=true
	fi
    done

    fields=()
    while read line; do
	line_split=($( echo $line | tr "~" "\n" ))
	fields+=("${line_split[*]:1}")
    done < "$filepath"

    filename=$(basename -- "$filepath")
    filename="${filename%.*}"

    if [[ ! "${fields[3]}" == "true" ]]; then
	fields[3]="true"
	printf "%b" \
	       "title              ~ ${fields[0]}\n" \
	       "author             ~ ${fields[1]}\n" \
	       "isbn10/13          ~ ${fields[2]}\n" \
	       "read?              ~ ${fields[3]}\n" \
	       "owned?             ~ ${fields[4]}\n" \
	       "comments           ~ ${fields[5]}\n" \
	       "initial_entry_time ~ ${fields[6]}\n" \
	       "edit_time          ~ $(date)\n" > "$filepath"

	all_read_symlink="${read_books}/$filename"
	ln -s "$filepath" "$all_read_symlink"

	echo "The book's status has been updated to 'read?=true'"
    fi

    year=$(date +%Y)
    month=$(date +%b)
    yeardir="${reading_data}/${year}"
    monthdir="${yeardir}/${month}"

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

    time_read_symlink="${monthdir}/$filename"
    # ensuring that multiple entries of the same book can be logged
    # per month
    while [ -f $time_read_symlink ]; do
	time_read_symlink+=_another
    done

    ln -s "$filepath" "$time_read_symlink"

    echo
    echo "$filename has been successfully logged in 'library/reading_data/${year}/${month}'"
}

edit_book() {
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
	line_split=($( echo $line | tr "~" "\n" ))
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
	filepath="${all_books}/${bookname}.txt"
	read -e -p "($1 > $bookname) " input

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
		echo "The current status of the book is" \
		     "read?=${fields[3]}"
		select bool in "true" "false"; do
		    break
		done
		
		if [[ $bool == "${fields[3]}" ]]; then continue; fi

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

		if [[ "$bool" == "${fields[4]}" ]]; then continue; fi

		owned_status_changed=true

		fields[4]="$bool"
		edited=true
		;;
	    'comments')
		read -e -i "${fields[5]}" new_comments
		if [[ "$new_comments" == "${fields[5]}" ]]; then
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
		       "title              ~ ${fields[0]}\n" \
		       "author             ~ ${fields[1]}\n" \
		       "isbn10/13          ~ ${fields[2]}\n" \
		       "read?              ~ ${fields[3]}\n" \
		       "owned?             ~ ${fields[4]}\n" \
		       "comments           ~ ${fields[5]}\n" \
		       "initial_entry_time ~ ${fields[6]}\n" \
		       "edit_time          ~ $(date)\n"
		continue
		;;
	    'delete')
		# removes all files found in order to also get symbolic links
		found=$(find $library -name "*${bookname}*")
		for file in ${found[*]}; do
		    rm "$file"
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
    if [ "$edited" = true ]; then
	printf "%b" \
	       "title              ~ ${fields[0]}\n" \
	       "author             ~ ${fields[1]}\n" \
	       "isbn10/13          ~ ${fields[2]}\n" \
	       "read?              ~ ${fields[3]}\n" \
	       "owned?             ~ ${fields[4]}\n" \
	       "comments           ~ ${fields[5]}\n" \
	       "initial_entry_time ~ ${fields[6]}\n" \
	       "edit_time          ~ $(date)\n" > "$filepath"
	echo "$bookname has been edited successfully"
    fi

    # if the original path passed to this sub-process does not match
    # the current one, the original is removed.
    if [ ! "$2" == "$filepath" ]; then
	rm $2
    fi

    # if the value of read? is changed, then add or remove
    # the appropriate symlink as needed
    if [ $read_status_changed = true ] && [[ "${fields[3]}" == "true" ]]; then
	ln -s "$filepath" "${read_books}/$bookname"
    elif [ $read_status_changed = true ] && [[ "${fields[3]}" == "false" ]]; then
	for file in $(find "$reading_data" -name "${bookname}"); do
	    rm "$file" 
	done
    fi

    # if the value of owned? is changed, then add or remove
    # the appropriate symlink as needed
    if [ $owned_status_changed == true ] && [[ "${fields[4]}" == "true" ]]; then
	ln -s "$filepath" "${owned_books}/$bookname"
    elif [ $owned_status_changed == true ] && [[ "${fields[4]}" == "false" ]]; then
	rm -f "${owned_books}/$bookname"
    fi
    
}

start_bookkeeping() {

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
		history -s "$input"
		enter_book false
		continue
		;;
	    'get')
		history -s "$input"
		# uses find to get a list of books matching search
		# query, from which the user can select from if there
		# is more than one option.
		read -p "Enter search query (case sensitive): " to_search

		# blank entry opts out of command
		if [[ "$to_search" == "" ]]; then
		    continue
		fi
		
		# this value is passed to find, which returns a list
		# from which the user can select some result
		query="*${to_search// /_}*"
		found=($(find "$all_books" -maxdepth 1 -name "${query}"))
		if [ ${#found[*]} = 0 ]; then
		    echo "Bad search query of '$query'"
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
		edit_book $input_string $gotten

		continue
		;;
	    'read'|'r')
		history -s "$input"
		enter_read

		continue
		;;
	    *)
		echo "haven't the fucking foggiest"
		continue
		;;
	esac
    done

    # logs history to the history file for popinjay
    history -a $pop_history
    history -cr ~/.bash_history
    echo "Exited library"
}

trap 'history -a ${directory_path}/.popinjay_history;exit' EXIT
start_bookkeeping

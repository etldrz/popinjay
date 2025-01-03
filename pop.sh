#!/bin/bash

edit_book() {
    # args: input_string filepath library_path

    # each book file is organized as
    #
    # title:BOOK_TITLE
    # author:BOOK_AUTHOR
    # isbn10/13:ISBN
    # read?:HAS_BEEN_READ
    # initial_entry_time:TIME_OF_ENTRY
    # edit_time:MOST_RECENT_EDIT_TIME

    fields=()
    while read line; do
	line_split=($( echo $line | tr ":" "\n" ))
	fields+=("${line_split[*]:1}")
    done < $2
	
    echo ${fields[*]}
    edited=false

    while true; do
		#file_title="${library}${title// /_},${author// /_}.txt"
	filename="${fields[0]// /_},${fields[1]// /_}"
	filepath="${3}${filename}.txt"
	read -e -p "($input_string > $filename) " input
	case $input in
	    'exit')
		break
		;;
	    'title')
		read -e -i "${fields[0]}" new_title
		if [[ "$new_title" == "${fields[0]}" ]]; then
		    echo same
		    continue
		fi
		fields[0]="$new_title"
		edited=true
		;;
	    'author')
		read -e -i "${fields[1]}" new_author
		if [[ "$new_author" == "${fields[1]}" ]]; then
		    echo same
		    continue
		fi
		fields[1]="$new_author"
		edited=true
		;;
	    'isbn10/13'|'isbn')
		read -e -i "${fields[2]}" new_isbn
		if [[ "$new_isbn" == "${fields[2]}" ]]; then
		    echo same
		    continue
		fi
		fields[2]="$new_isbn"
		edited=true
		;;
	    'read?'|'read')
		read -e -i "${fields[3]}" new_read?
		if [[ "$new_read?" == "${fields[3]}" ]]; then
		    echo same
		    continue
		fi
		fields[3]="$new_read?"
		edited=true
		;;
	    'help'|'h')
		echo "Here is the book metadata as it currently stands. Call any non-time field to edit it."
		printf "%b" \
		       "title             : ${fields[0]}\n" \
		       "author            : ${fields[1]}\n" \
		       "isbn10/13         : ${fields[2]}\n" \
		       "read?             : ${fields[3]}\n" \
		       "initial_edit_time : ${fields[4]}\n" \
		       "edit_time         : $(date)\n"
		continue
		;;
	    'delete')
		rm $2
		break
		;;
	    
	    *)
		echo "Not a viable request"
		continue
		;;
	esac
    done

    if [ "$edited" = true ]; then
	printf "%b" \
	       "title             : ${fields[0]}\n" \
	       "author            : ${fields[1]}\n" \
	       "isbn10/13         : ${fields[2]}\n" \
	       "read?             : ${fields[3]}\n" \
	       "initial_edit_time : ${fields[4]}\n" \
	       "edit_time         : $(date)\n" > $filepath
	echo "$filename has been edited successfully"
    fi

    if [ ! "$2" == $filepath ]; then
	rm $2
    fi
}

start_bookkeeping() {
    # write location
    library="./library/"

    if [ ! -d $library ]; then
	mkdir $library
	printf "%b" \
	       "The necessary directory '$(readlink -f $library)' wasn't found; " \
	       "it has been created.\n\n"
    fi

    pop_history=./.popinjay_history
    history -cr $pop_history

    echo "Entering library data, type exit to leave."

    while true; do
	input_string="popinjay"
	read -e -p "(${input_string}) " input
	# Don't ever call him a monkey!


	## for each book, make a file containign all needed info. this can be changed latter into one
	## big file. every time a file is created, store it in a var that can be used in conjuncture
	## with the edit command. 'get' command will store requested file name into curr. smart
	## search or manual typing?

	case $input in
	    'exit')
		break
		;;
	    'new'|'n')
		echo "making new"
		read -p "title: " title
		read -p "author: " author
		if [[ "$title" == "" && "$author" == "" ]]; then
		    continue
		fi
		read -p "isbn10/13: " isbn
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
		entry_time=$(date)

		file_title="${library}${title// /_},${author// /_}.txt"
		while [ -f $file_title ]; do
		    file_title+=_another
		done
		printf "%b" \
		       "title:${title}\n" \
		       "author:${author}\n" \
		       "isbn10/13:${isbn}\n" \
		       "read?:${has_read}\n" \
		       "edit_time:${entry_time}\n" \
		       "initial_entry_time:${entry_time}\n" > $file_title

		echo "successfully logged '$file_title'"
		history -s $input
		continue
		;;
	    'edit')
		echo "editing"
		echo $input
		history -s $input
		continue
		;;
	    'get')
		# append onto input_string the book title and author
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

		gotten_book=($( echo $gotten | tr "/" "\n" ))
		gotten_book=($( echo ${gotten_book[2]} | tr "." "\n" ))
		gotten_book=${gotten_book[0]}

		edit_book $input_string $gotten $library
		history -s $input
		continue
		;;
	    *)
		echo "$input"
		echo "haven't the fucking foggiest"
		continue
		;;
	esac
    done

    history -a $pop_history
    history -cr ~/.bash_history
    echo "Exited library"
}

trap 'trap -a ./.popinjay_history;exit' EXIT
start_bookkeeping

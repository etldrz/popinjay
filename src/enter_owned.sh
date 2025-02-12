#!/bin/bash

directory_path="$HOME/git/popinjay"
# containing all book data
library="$directory_path/library"
# where all actual book data are stored
all_books="$library/books"
# a set of symbolic links for all books owned is stored here
owned_books="$library/owned"
# a set of symbolic links for all books read is stored here
read_books="$library/read"

# The deliminator used to seperate fields from values in each book file.
# Chosen because it is not commonly used in language.
bookfile_delim="~"

# called when a new book is being put into the system,
# via either the 'new'or 'read' commands
# args: from_enter_read?
#         a boolean  which determines whether popinjay asks if
#         the book is owned vs the book is read. Asks former if
#         enter_book gets called from enter_read vs the 'new'
#         command of start_bookkeeping

# gets all the needed data from the user
read -p "title: " title
read -p "author/editor: " author
# allows for the user to opt-out of the command
[ "$title" = "" ] && [ "$author" = "" ] && return

read -p "isbn10/13: " isbn
# see args description
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
# in case of repeated entries (different copies of
# same book)
filename="$all_books/$translated_name"
while [ -f "$filename.txt" ]; do
	filename+=_another
done
filename="${filename}.txt"

if [ $1 = true ]; then
	has_read=true
	owned=$book_status
else
	has_read=$book_status
	owned=true
fi

printf "%b" \
	   "title              $bookfile_delim ${title}\n" \
	   "author             $bookfile_delim ${author}\n" \
	   "isbn10/13          $bookfile_delim ${isbn}\n" \
	   "read?              $bookfile_delim ${has_read}\n" \
	   "owned?             $bookfile_delim ${owned}\n" \
	   "comments           $bookfile_delim ${comments}\n" \
	   "initial_entry_time $bookfile_delim ${entry_time}\n" \
	   "edit_time          $bookfile_delim ${entry_time}\n" > "$filename"

echo
echo "Created an entry for '${title// /_},${author// /_}'"

# symlinks are used to log metadata--if a file symlink is in $read_books
# that means it has been read, and the same holds for it being in $owned_books.
read_path_symlink="$read_books/$translated_name"
if [ $has_read = true ] && [ ! -f "$read_path_symlink" ]; then
	ln -s "$filename" "$read_path_symlink"
	echo "Shelved as read"
fi
owned_path_symlink="$owned_books/$translated_name"
if [ $owned = true ] && [ ! -f "$owned_path_symlink" ]; then
	ln -s "$filename" "$owned_path_symlink"
	echo "Shelved as owned"
fi

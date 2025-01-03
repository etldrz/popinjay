#!/bin/bash

#mine=(-a three -b 2)
#
#set -- "${mine[@]}"
#echo $@
#while getopts "a:b:" var; do
#    echo now here
#    case "$var" in
#	a)
#	    echo $OPTARG
#	    ;;
#	b)
#	    echo $OPTARG
#	    ;;
#    esac
#done

#file="pop.sh"
#while [ -f $file ]; do
#    echo here
#    file+="_another"
#done
#
#touch $file

#while true; do
#    read -p "Do you wish to install this program?" yn
#    case $yn in
#        [Yy]* ) echo shit;;
#        [Nn]* ) exit;;
#        * ) echo "Please answer yes or no.";;
#    esac
#done

found=($(find ./library -name 'tt*'))
length=${#found[*]}
echo $length
echo ${found[*]}

select f in $(find ./library -name 'tt_a*'); do
    echo $f
done

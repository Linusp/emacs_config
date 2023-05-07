#!/bin/bash

dot_emacs_path=$HOME/.emacs
emacs_dir=$HOME/.emacs.d

if [ -f $dot_emacs_path ];then
    read -p "Emacs init file already exists, continue?[y/n] " op
    case $op in
	n) exit 1
	   ;;
	no) exit 1
	    ;;
    esac
    bak=${dot_emacs_path}.bak.$(date +%s)
    mv $dot_emacs_path $bak
    echo "backup $dot_emacs_path to $bak"
fi
ln -s $(readlink -f dot_emacs) $dot_emacs_path
echo "link dot_emacs to $dot_emacs_path"

if [ -e $emacs_dir ];then
    read -p "Emacs directory already exists, continue?[y/n] " op
    case $op in
	n) exit 1
	   ;;
	no) exit 1
	    ;;
    esac
    bak=${emacs_dir}.bak.$(date +%s)
    mv $emacs_dir $bak
    echo "backup $emacs_dir to $bak"
fi
ln -s $(readlink -f emacs.d) $emacs_dir
echo "link emacs.d to ${emacs_dir}"

core_config=$(readlink -f emacs_config.org)
sed -i dot_emacs -e 's|\(org-dotemacs-default-file\) \"\(.*\)\"|\1 \"'"$core_config"'\"|g'
echo "replace org-dotemacs-default-file with the true path of emacs_config.org"

echo "Done"


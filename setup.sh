#!/bin/bash

function tx() {
	echo "\033[01;36m$1\033[00m"
}
currentDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
include="source $currentDir/all-about-that-bash.sh"
isIncluded=$(cat $HOME/.bashrc | grep -c "$include")

if [ $isIncluded -gt 0 ]; then
	echo "Setup has been completed."
	read -p "Do you want to uninstall instead? [y/n] "
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		lineNum=$(grep -n "$include" $HOME/.bashrc | cut -d : -f 1)
		sed -i.bak "${lineNum}d" $HOME/.bashrc
		echo "Uninstall complete."
		exit 0
	fi
	exit 1
fi

echo -e "\n${include}" >> $HOME/.bashrc
echo -e "Setup complete.
* Modify $(tx term) file to match your own needs
* Please restart your terminal to take effect
* And type 'helpme' to start
Good luck \u263A"
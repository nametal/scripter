#!/bin/bash

function tx() {
	echo "\033[01;36m$1\033[00m"
}
currentDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
include="source $currentDir/all-about-that-bash.sh"
isIncluded=$(cat $HOME/.bashrc | grep -c "$include")

if [ $isIncluded -gt 0 ]; then
	echo "Setup has been completed"
	exit 1
fi

echo -e "\n${include}" >> $HOME/.bashrc
echo -e "Setup complete.
* Edit $(tx cred) and $(tx term) files to match your own needs
* Please restart your terminal to take effect
* And type 'helpme' to start
Good luck \u263A"
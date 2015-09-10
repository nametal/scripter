#!/bin/bash
scriptDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $scriptDir

. vars

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

# install xclip
echo -en "Installing xclip...${cTURQUOISE}"
which xclip >/dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "Already installed."
else
	sudo apt-get install xclip
	echo "completed."
fi
echo -e "${cLIGHTGRAY}"

# choose prompt theme
echo -e "Which color theme do you prefer ?"
ask-prompt
read -p "Choose [1/2] : "
change-theme $REPLY

# include bash in bashrc
echo -e "\n${include}" >> $HOME/.bashrc
echo -e "Setup complete.
* ${cRED}IMPORTANT${cLIGHTGRAY} : make sure to modify ${cTURQUOISE}${scriptDir}/term${cLIGHTGRAY} to set up environment
* Please restart your terminal (or open new tab) to take effect
* And type 'helpme' to start
Good luck ${uSMILE}"

cd - &>/dev/null
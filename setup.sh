#!/bin/bash
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

echo -e "Which prompt do you prefer ?"
ask-prompt
read -p "Choose [1..4] : "
change-prompt $REPLY

echo -e "\n${include}" >> $HOME/.bashrc
echo -e "Setup complete.
* Modify ${cTURQUOISE}term${cLIGHTGRAY} file to match your own needs
* Please restart your terminal to take effect
* And type 'helpme' to start
Good luck ${uSMILE}"
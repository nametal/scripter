# resolve idea "can't type" problem
unlock_keyboard() {
    ibus-daemon -rd
    if [ $(ps aux | grep -c "ibus-daemon -rd") -ge 2 ]
    then
        echo "Success"
    else
        echo "Failed"
    fi
}

# get current git branch name
parsed_git_branch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1]/'
}

# connect to remote mongo machine
# warning! this is semi-automatic function
ssh-mongo() {
	local TARGET_MACHINE=$1
	local DB_NAME=$2
	local AUTH_TYPE=$3

	local MONGO_USER='yourUserName'
	local MONGO_PWD='yourPassword'
	local SLAVEOK='\nrs.slaveOk()'

	if [ -z "$1" ]; then
		echo 'usage: ssh-mongo <MACHINE> <DB_NAME> [<AUTH_TYPE>]'
		echo '	MACHINE		eg. data02 for mongodata02'
		echo '	DB_NAME 	eg. space-agent'
		echo '	AUTH_TYPE	optional, admin for admin, leave empty for dev'
		echo 'NOTE! after logged in to remote machine, paste (Ctrl+Shift+V) '
		return
	fi

	if [ -z "$DB_NAME" ]; then
		DB_NAME='data'
	fi

	if [ -n "$AUTH_TYPE" ] && [ $AUTH_TYPE = 'admin' ]; then
		MONGO_USER='space-admin'
		MONGO_PWD='yourAdminPassword'
		SLAVEOK=
	fi

	# 1. store all mongo commands to clipboard
	local CMDS="mongo\nuse ${DB_NAME} \ndb.auth('${MONGO_USER}','${MONGO_PWD}')${SLAVEOK}"
	echo -e $CMDS | xclip -sel c

	# 2. call ssh to remote machine
	ssh mongo$TARGET_MACHINE

	# 3. manual paste (Ctrl+Shift+V) on terminal
}

# get whoami status from remote machine by service name
ssh-whoami() {
	local TARGET_MACHINE=$1
	local SERVICE_NAME=$2
	local PORT=80

	if [ -z "$1" ] || [ -z "$2" ]; then
		echo 'usage: ssh-whoami <MACHINE> <SERVICE_NAME>'
		echo '  MACHINE        remote machine, eg. frs15'
		echo '  SERVICE_NAME   eg. tap, frs, fetcher'
		return
	fi

	if [ $SERVICE_NAME = "fetcher" ]; then
		ssh $1 "cat /var/space/fetcher/build.properties"
		return
	fi

	local PORT=$(getPortFromService $SERVICE_NAME)
	if [ -z "$PORT" ]; then
		echo "Service ${2} not found"
		return
	fi
	ssh $1 "curl localhost:${PORT}/whoami" | python -m json.tool
}

# self explanatory
getPortFromService() {
	local PORT=
	case "$1" in
		"tv") PORT=$SPACECOM_LISTEN_PORT;;
		"tap") PORT=$TAP_LISTEN_PORT;;
		"frs") PORT=$FRS_LISTEN_PORT;;
		"fb") PORT=$FB_LISTEN_PORT;;
		"hinv") PORT=$HOTEL_INV_LISTEN_PORT;;
		"pg") PORT=$PG_LISTEN_PORT;;
		"ne") PORT=$NAMED_ENTITY_LISTEN_PORT;;
	esac
	echo $PORT
}

tes() {
	$1
	if [ $? -eq 0 ]; then
		echo -e "${CYAN}${uSMILE}"
	else
		echo -e "${RED}${uFROWN}"
	fi
}

# kill process by service name
qkill() {
	local SERVICE_NAME=$1

	if [ -z "$SERVICE_NAME" ]; then
		echo 'usage: qkill <SERVICE_NAME>'
		echo '	SERVICE_NAME	eg. tv, frs, tap'
		return
	fi

	local PORT=$(getPortFromService $SERVICE_NAME)
	
	local PID=$(ps aux | grep -v grep | grep -v artifactory | grep $PORT | awk '{print $2}')
	
	if [ -z "$PID" ]; then
		echo "${SERVICE_NAME} service is not running"
		return
	fi

	# dangerous! please review!
	# kill $PID

	if [ $? -eq 0 ]; then
		echo 'Success'
	else
		echo 'Failed'
	fi
}

getServiceFromPort() {
	echo 'dummy'
}

getCurrentBuildVersion() {
	echo $(git branch | grep '*' | cut -d'/' -f2).$(git log --format="%h" | head -1)-$1
}

# push binary to repo
push() {
	if [ -z "$2" ]; then
		echo 'usage: push <SERVICE_NAME> <VERSION>'
		echo '   eg. push frs fixCommonInfo'
		return
	fi

	local VERSION=$(getCurrentBuildVersion $2)
	echo $VERSION

	pushd $SPACE_ROOT/repository/deploy-scripts
	
	if [ $1 = "fetcher" ]; then
		./push-fetcher.sh ${VERSION} repo01
		# echo "./push-fetcher.sh ${2} repo01"
	else
		./push.sh $1 ${VERSION} repo01 
		# echo "./push.sh ${1} ${2} repo01 "
	fi

	popd

	echo "new version = ${VERSION}"
}

  #############
 # CONSTANTS #
#############

# unicode symbol
uSMILE='\u263A'
uFROWN='\u2639'
uCHECK='\u2611'
uWRONG='\u2612'

# color constants
RED="\033[01;31m"
GREEN="\033[01;32m"
BLUE="\033[01;34m"
YELLOW="\033[01;33m"
CYAN="\033[01;36m"
NO_COLOR="\033[00m"

# Color info
# Attribute codes:
#     00=none
#     01=bold
#     04=underscore
#     05=blink
#     07=reverse
#     08=concealed

# Text color codes:
#     30=black
#     31=red
#     32=green
#     33=yellow
#     34=blue
#     35=magenta
#     36=cyan
#     37=white

# Background color codes:
#     40=black
#     41=red
#     42=green
#     43=yellow
#     44=blue
#     45=magenta
#     46=cyan
#     47=white
colors-info() {
	local fgc bgc vals seq0

	printf "Color escapes are %s\n" '\e[${value};...;${value}m'
	printf "Values 30..37 are \e[33mforeground colors\e[m\n"
	printf "Values 40..47 are \e[43mbackground colors\e[m\n"
	printf "Value  1 gives a  \e[1mbold-faced look\e[m\n\n"

	# foreground colors
	for fgc in {30..37}; do
		# background colors
		for bgc in {40..47}; do
			fgc=${fgc#37} # white
			bgc=${bgc#40} # black

			vals="${fgc:+$fgc;}${bgc}"
			vals=${vals%%;}

			seq0="${vals:+\e[${vals}m}"
			printf "  %-9s" "${seq0:-(default)}"
			printf " ${seq0}TEXT\e[m"
			printf " \e[${vals:+${vals+$vals;}}1mBOLD\e[m"
		done
		echo; echo
	done
}
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. $DIR/vars

myCRED=$DIR/cred
myTERM=$DIR/term

helpme() {
	echo -e "
calm down, here are some tools for you... ${uSMILE} 
  
  ssh-mongo              - connect to remote mongo machine with ssh (semi-automatic)
  to-mongo               - connect to remote mongo machine directly (automatic)
  ssh-whoami             - get whoami status from remote machine by service name
  qkill                  - quick kill process by service name
  qpush                  - quick push binary to repo
  unlock-keyboard        - resolve idea \"cannot type\" problem
  getPortFromService     - self explanatory
  getCurrentGitBranch    - self explanatory
  getCurrentBuildVersion - self explanatory
  wew                    - check last command return status
"
}

# check last command return status
wew() {
	if [ $? -eq 0 ]; then
		echo -e "${cTURQUOISE}${uSMILE}"
	else
		echo -e "${cRED}${uFROWN}"
	fi
}

# resolve idea "can't type" problem
unlock-keyboard() {
    ibus-daemon -rd
    if [ $(ps aux | grep -v grep | grep -c "ibus-daemon -rd") -ge 1 ]
    then
        echo "Success"
    else
        echo "Failed"
        return 1
    fi
}

# get current git branch name
getCurrentGitBranch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1]/'
}

# connect to remote mongo machine with ssh
# warning! this is semi-automatic function
ssh-mongo() {
	if [ -z "$2" ]; then
		echo "usage: ssh-mongo <machine_code> <db_name> [<auth_type>]"
		echo "  machine_code    eg. data02 for mongodata02"
		echo "  db_name         eg. $(getTerm env1)-agent"
		echo "  auth_type       optional, admin for admin, leave empty for dev"
		return 1
	fi

	if [ -z "$3" ]; then
		local MONGO_USER=dev
		local SLAVEOK='\nrs.slaveOk()'
	else
		if [ $3 = 'admin' ]; then
			local MONGO_USER=admin
		else
			echo "invalid auth type '${3}'"
			return 2
		fi
	fi
	local MONGO_PWD=$(getPassword $MONGO_USER)

	# 1. store all mongo commands to clipboard
	local CMDS="mongo\nuse ${2} \ndb.auth('${MONGO_USER}','${MONGO_PWD}')${SLAVEOK}"
	echo -e $CMDS | xclip -sel c
	echo "after ssh logged in, please paste (Ctrl+Shift+V)"
	read -p "press any key to continue..."

	# 2. ssh to remote machine
	ssh mongo$1

	# 3. manual paste (Ctrl+Shift+V) on terminal
	#    this is why I called it semi-automatic ;p
}

# connect to remote mongo machine directly
# automatic function, except rs.slaveOk()
to-mongo() {
	if [ -z "$2" ]; then
		echo "usage: to-mongo <machine_code> <db_name> [<auth_type>]"
		echo "  machine_code    eg. data02 for mongodata02"
		echo "  db_name         eg. $(getTerm env1)-agent"
		echo "  auth_type       optional, admin for admin, leave empty for dev"
		return 1
	fi

	if [ -z "$3" ]; then
		local MONGO_USER=dev
		local SLAVEOK='\nrs.slaveOk()'
	else
		if [ $3 = 'admin' ]; then
			local MONGO_USER=admin
		else
			echo "invalid auth type '${3}'"
			return 2
		fi
	fi
	local MONGO_PWD=$(getPassword $MONGO_USER)
	
	mongo --host mongo$1 --port 27017 -u $MONGO_USER -p $MONGO_PWD $2
}

# get whoami status from remote machine by service name
ssh-whoami() {
	if [ -z "$2" ]; then
		echo "usage: ssh-whoami <machine_name> <service_name>"
		echo "  machine_name    remote machine, eg. frs15"
		echo "  service_name    eg. tap, frs, fetcher"
		return 1
	fi

	if [ $2 = "fetcher" ]; then
		ssh $1 "cat /var/$(getTerm env1)/fetcher/build.properties"
		return 0
	fi

	local PORT=$(getPortFromService $2)
	if [ -z "$PORT" ]; then
		echo "service '${2}' not found"
		return 2
	fi
	ssh $1 "curl localhost:${PORT}/whoami" | python -m json.tool
}

tes() {
	echo -e "\e[0;33mtes"
}

# self explanatory
getPortFromService() {
	case "$1" in
		"tv") local genPort=$(getTerm env2)COM_LISTEN_PORT
			  local PORT=${!genPort};;
		"tap") local PORT=$TAP_LISTEN_PORT;;
		"frs") local PORT=$FRS_LISTEN_PORT;;
		"fb") local PORT=$FB_LISTEN_PORT;;
		"hinv") local PORT=$HOTEL_INV_LISTEN_PORT;;
		"pg") local PORT=$PG_LISTEN_PORT;;
		"ne") local PORT=$NAMED_ENTITY_LISTEN_PORT;;
		*) return 1;;
	esac
	echo $PORT
}

# quick kill process by service name
qkill() {
	if [ -z "$1" ]; then
		echo "usage: qkill <service_name>"
		echo "  service_name   eg. tv, frs, tap"
		return 1
	fi

	local PORT=$(getPortFromService $1)
	if [ -z "$PORT" ]; then
		echo "service '${1}' not found"
		return 2
	fi
	
	local PID=$(ps aux | grep -v grep | grep -v artifactory | grep "jar start.jar" | grep $PORT | awk '{print $2}')
	if [ -z "$PID" ]; then
		echo "service '${1}' is not running"
		return 3
	fi

	# be careful, it is dangerous!
	read -p "PID ${PID}, press any key to kill..."
	kill $PID
	wew
}

# getServiceFromPort() {
	# TODO, use sed
	# echo 'dummy'
# }

getCurrentBuildVersion() {
	if [ -d ".git" ]; then
		local branchName=$(git branch | grep '*' | cut -d'/' -f2 | cut -d'*' -f2)
		local hashCode=$(git log --format="%h" | head -1)
		echo $branchName.$hashCode-$1
	else
		echo "this is not a git repository"
		return 1
	fi
}

# quick push binary to repo
qpush() {
	if [ -z "$2" ]; then
		echo "usage: qpush <service_name> <version>"
		echo "  eg. qpush frs fixAirportInfo"
		return 1
	fi

	local newVersion=$(getCurrentBuildVersion $2)

	pushd ~/tools/repository/deploy-scripts
	
	if [ $1 = "fetcher" ]; then
		./push-fetcher.sh ${newVersion} repo01
		# echo "./push-fetcher.sh ${2} repo01"
	else
		./push.sh $1 ${newVersion} repo01 
		# echo "./push.sh ${1} ${2} repo01 "
	fi

	popd

	echo -e "New Version: ${cTURQUOISE}${newVersion}"
}

# get password from credentials
getPassword() {
	if [ -z "$1" ]; then
		echo "usage: getPassword <username>"
		return 1
	fi

	local password=$(cat $myCRED | grep ^$1: | cut -d : -f 2)
	if [ -z "$password" ]; then
		echo "password for '${1}' not found"
		return 2
	fi

	local passwordFound=$(cat $myCRED | grep -c ^$1:)
	if [ $passwordFound -gt 1 ]; then
		echo "duplicate entry for '${1}'"
		return 3
	fi

	echo $password
}

# get your own defined term
getTerm() {
	if [ -z "$1" ]; then
		echo "usage: getTerm <term>"
		return 1
	fi

	local term=$(cat $myTERM | grep ^$1: | cut -d : -f 2)
	if [ -z "$term" ]; then
		echo "term '${1}' not found"
		return 2
	fi

	local termFound=$(cat $myTERM | grep -c ^$1:)
	if [ $termFound -ne 1 ]; then
		echo "duplicate entry for '${1}'"
		return 3
	fi

	echo $term
}

# force override coloring prompt
PS1="${debian_chroot:+($debian_chroot)}$ccGREEN\u@\h$ccLIGHTGRAY:$ccYELLOW`parsed_git_branch`$ccBLUE\w$ccLIGHTGRAY\$ "
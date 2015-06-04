DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. $DIR/vars

myTERM=$DIR/term

helpme() {
	echo -e "
calm down, here are some tools for you... ${uSMILE} 
  
  ssh-mongo              - connect to remote mongo machine using ssh (semi-automatic)
  to-mongo               - connect to remote mongo machine directly (automatic)
  ssh-whoami             - get whoami status from remote machine by service name
  qkill                  - quick kill process by service name
  qpush                  - quick push binary to repo (batch-able)
  qpull                  - quick pull binary from repo to a remote server using ssh (semi-automatic)
  qlist                  - get list of running services
  unlock-keyboard        - resolve idea \"cannot type\" problem
  getPortFromService     - self explanatory
  wew                    - check last command return status
"
}

# check last command return status
wew() {
	if [ $? -eq 0 ]; then
		echo -e "${cTURQUOISE}${uCHECK}"
	else
		echo -e "${cRED}${uWRONG}"
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

# connect to remote mongo machine using ssh
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
		local SLAVEOK='rs.slaveOk()'
	else
		if [ $3 = 'admin' ]; then
			local MONGO_USER=admin
		else
			echo "invalid auth type '${3}'"
			return 2
		fi
	fi
	local MONGO_PWD=$(getTerm $MONGO_USER)

	# 1. store all mongo commands to clipboard
	local CMDS="mongo
use ${2}
db.auth('${MONGO_USER}','${MONGO_PWD}')
${SLAVEOK}"
	echo -e "$CMDS" | xclip -sel c
	echo "after ssh logged in, please paste (Ctrl+Shift+V)"
	read -s -n1 -p "press any key to continue..."

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
	local MONGO_PWD=$(getTerm $MONGO_USER)
	
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
	echo -e "${uFROWN}${uSMILE}"
	case $1 in
		1) echo "one";;
		2) echo "two";;
		3) echo "three";;
		4) echo "four";;
	esac
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
	read -p "PID ${PID}, press Enter to kill..."
	kill $PID
	wew
}

# get list of running services
qlist() {
	srvs=("tv" "tap" "frs" "fb" "hinv" "pg" "ne")
	for s in "${srvs[@]}"
	do
		local PORT=$(getPortFromService $s)
		local cSrv=$(ps aux | grep -v grep | grep -v artifactory | grep "jar start.jar" | grep -c $PORT)
		if [ $cSrv -gt 0 ]; then
			echo "$s"
		fi
	done
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

# quick push binary to repo (batch-able)
qpush() {
	if [ -z "$2" ]; then
		echo "usage: qpush <version> <s1> [<s2> <s3> ...]"
		echo "  version       build version, eg: fixAirportInfo"
		echo "  s1, s2, ..    services name, eg: tv fetcher tap"
		echo "eg. qpush fixAirportInfo tv fetcher tap"
		return 1
	fi

	local newVersion=$(getCurrentBuildVersion $1)
	pushd ~/tools/repository/deploy-scripts	> /dev/null

	local srvs=

	arr=("$@")
	for x in ${!arr[@]}
	do
		# echo "$x ${arr[$x]}"s
		if [ $x -gt 0 ]; then
			echo -e "[${x}] Pushing ${cGREEN}${arr[$x]}${cLIGHTGRAY}..."
			if [ ${arr[$x]} = "fetcher" ]; then
				./push-fetcher.sh ${newVersion} repo01
				# echo "./push-fetcher.sh ${newVersion} repo01"
				srvs="${srvs} ${arr[$x]}"
			else
				local PORT=$(getPortFromService ${arr[$x]})
				if [ -z "$PORT" ]; then
					echo "Service '${arr[$x]}' not found. Skipped"
				else
					./push.sh ${arr[$x]} ${newVersion} repo01
					# echo "./push.sh ${arr[$x]} ${newVersion} repo01"
					srvs="${srvs} ${arr[$x]}"
				fi
			fi
		fi
	done
	
	popd > /dev/null
	echo -e "\nServices   :${cGREEN}${srvs}${cLIGHTGRAY}"
	echo -e "New Version: ${cTURQUOISE}${newVersion}\n"
}

# quick pull binary from repo to a remote server using ssh (semi-automatic)
qpull() {
	if [ -z "$3" ]; then
		echo "usage: qpull <machine_name> <service_name> <version>"
		echo "  machine_name    remote machine, eg. staging04"
		echo "  service_name    eg. tap, frs, fetcher"
		echo "  version         eg. fixAirportInfo"
		return 1
	fi

	if [ $2 = "fetcher" ]; then
		local pullCommand="/var/$(getTerm env1)/running/deploy-scripts/remote-pull-fetcher.sh ${3} repo01"
	else
		local pullCommand="stop-${2}
/var/$(getTerm env1)/running/deploy-scripts/remote-pull.sh ${2} ${3} repo01
sleep 3
start-${2}"
		local logCommand="sleep 1
colortail /var/$(getTerm env1)/log/${2}_console.log"
	fi

	# 1. store all mongo commands to clipboard
	local CMDS="sudo su
${pullCommand}
exit
${logCommand}"
	echo -e "$CMDS" | xclip -sel c
	echo "after ssh logged in, please paste (Ctrl+Shift+V)"
	read -s -n1 -p "press any key to continue..."

	# 2. ssh to remote machine
	ssh $1

	# 3. manual paste (Ctrl+Shift+V) on terminal
	#    this is why I called it semi-automatic ;p
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

PROMPT_THEME=$(getTerm theme)
# force override coloring prompt
case $PROMPT_THEME in
	1) # default
		PS1="$ccGREEN\u@\h$ccLIGHTGRAY:$ccYELLOW\$(getCurrentGitBranch)$ccBLUE\w$ccLIGHTGRAY\$ ";;
	2) # midnight
		PS1="$ccBLUE\u@\h$ccLIGHTGRAY:$ccTURQUOISE\$(getCurrentGitBranch)$ccPURPLE\w$ccLIGHTGRAY\$ ";;
esac

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac
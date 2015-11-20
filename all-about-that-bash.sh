DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. $DIR/vars

myTERM=$DIR/term

helpme() {
	echo -e "
calm down, here are some tools for you... ${uSMILE} 
  
  qssh                   - quick ssh to another machine (implicitly through ansible)
  ssh-whoami             - get whoami status from $(getTerm env1) service name on target machine
  ssh-mongo              - connect to remote mongo machine using ssh (semi-automatic)
  qclip                  - quick copy any variable to clipboard
  qkill                  - quick kill process by $(getTerm env1) service name
  get-millis             - get current time in milliseconds
  unlock-keyboard        - resolve idea \"cannot type\" problem
  wew                    - check last command return status
  
  portof                 - get port number from $(getTerm env1) service name
  serviceof              - get $(getTerm env1) service name from port number
  allservices            - list all $(getTerm env1) services
${clDARKGRAY}currently disabled commands (under maintenance):
  exe (beta)             - run any command with elapsed time information
  qlist                  - quick get list of running $(getTerm env1) services
  to-mongo               - connect to remote mongo machine directly (automatic)
  qpush                  - quick push binary to repo (batch-able)
  qpull                  - quick pull binary from repo to a remote server using ssh (semi-automatic)
${cLIGHTGRAY}
tips: how to use? try one of those command by run it without parameter
"
}

qclip() {
	echo $1 | xclip -sel c
}

qenc() {
	if [ -z "$2" ]; then
		echo "usage: qdec <role> <plaintext>"
		return 1
	fi
	local role=$1
	shift
	echo $@ | openssl enc -aes-256-cbc -a -salt -out $DIR/$(getTerm $role)
}

qdec() {
	if [ -z "$1" ]; then
		echo "usage: qdec <role>"
		return 1
	fi
	openssl enc -aes-256-cbc -d -a -in $DIR/$(getTerm $1)
}

qssh() {
	if [ -z "$1" ]; then
		echo "usage: ssh <target_machine>"
		echo "  target_machine   eg. tv, frs, tap"
		return 1
	fi
	ssh -t ansible01 "ssh $@"
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
	local MONGO_PWD=$(qdec $MONGO_USER)

	# 1. store all mongo commands to clipboard
	local CMDS="mongo
use ${2}
db.auth('${MONGO_USER}','${MONGO_PWD}')
${SLAVEOK}"
	echo -e "$CMDS" | xclip -sel c
	echo "once logged in, please paste (Ctrl+Shift+V)"
	read -s -n1 -p "press any key to continue..."

	# 2. ssh to remote machine
	qssh mongo$1

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
	local MONGO_PWD=$(qdec $MONGO_USER)
	
	mongo --host mongo$1 --port 27017 -u $MONGO_USER -p $MONGO_PWD $2
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

# quick kill process by service name
qkill() {
	if [ -z "$1" ]; then
		echo "usage: qkill <service_name> [-f]"
		echo "  service_name   eg. tv, frs, tap"
		echo "  -n             disable force killing"
		return 1
	fi

	local PORT=$(portof $1)
	if [ -z "$PORT" ]; then
		echo "service '${1}' not found"
		return 2
	fi
	
	local PID=$(ps aux | grep -v grep | grep -v artifactory | grep "jar start.jar" | grep $PORT | awk '{print $2}')
	if [ -z "$PID" ]; then
		echo "service '${1}' is not running"
		return 3
	fi

	forceKill="-9"
	if [ "$2" == "-n" ]; then
		forceKill=
	fi

	# be careful, it is dangerous!
	read -p "PID ${PID}, press Enter to kill..."
	kill $forceKill $PID
	wew
}

# get list of running services
qlist() {
	if [ -z "$1" ]; then
		echo "usage: qlist <target>"
		echo "  target    target machine, eg: local, staging05"
		echo "eg. qlist staging05"
		return 1
	fi

	type allservices > /dev/null
	if [ $? -ne 0 ]; then
		return 1;
	fi

	local strCommand="ps aux | grep -v grep | grep -v artifactory | grep 'jetty-deploy' | grep -v sed | sed -e 's#.*jetty-deploy-\(\)#\1#' | cut -d '.' -f1"
	if [ "$1" != "local" ]; then
		strCommand="qssh ${1} \"${strCommand}\""
	fi

	local runningPorts=($(eval $strCommand))

	for p in "${runningPorts[@]}"
	do
		echo "${p}"
		# [[ $p =~ ^-?[0-9]+$ ]] # test if p is number
		# if [ $? -eq 0 ]; then # if $2 contains number in the end
  #   		echo number
  #   	else
  #   		echo not number
  #   		local servicename=$(serviceof $p)
		# 	echo $servicename
    	# fi
	done
}

getCurrentBuildVersion() {
	if [ -d ".git" ]; then
		local branchName=$(git branch | grep '*' | cut -d'/' -f2 | cut -d'*' -f2)
		local hashCode=$(git log --format="%h" | head -1)
		echo $branchName.$hashCode-$1-$2
	else
		echo "this is not a git repository"
		return 1
	fi
}

# quick push binary to repo (batch-able)
qpush() {
	if [ -z "$3" ]; then
		echo "usage: qpush <target> <comment> <s1> [<s2> <s3> ...]"
		echo "  target        target machine, eg: staging05"
		echo "  comment       comment on version, eg: fixAirportInfo"
		echo "  s1, s2, ..    services name, eg: tv fetcher tap"
		echo "eg. qpush fixAirportInfo tv fetcher tap"
		return 1
	fi

	local newVersion=$(getCurrentBuildVersion $1 $2)
	pushd ~/tools/repository/deploy-scripts	> /dev/null

	local pushed=
	local skipped=

	arr=("$@")
	ctr=1
	for x in ${!arr[@]}
	do
		# echo "$x ${arr[$x]}"s
		if [ $x -gt 1 ]; then # parameter #3 and more
			echo -e "[$((ctr++))] Pushing ${cGREEN}${arr[$x]}${cLIGHTGRAY}..."
			if [ ${arr[$x]} = "fetcher" ]; then
				./push-fetcher.sh ${newVersion} repo01
				# echo "./push-fetcher.sh ${newVersion} repo01" # debug-mode
				pushed="${pushed} ${arr[$x]}"
			else
				local PORT=$(portof ${arr[$x]})
				if [ -z "$PORT" ]; then
					skipped="${skipped} ${arr[$x]}"
					echo "Service '${arr[$x]}' not found. Skipped"
				else
					./push.sh ${arr[$x]} ${newVersion} repo01
					# echo "./push.sh ${arr[$x]} ${newVersion} repo01" # debug-mode
					pushed="${pushed} ${arr[$x]}"
				fi
			fi
		fi
	done

	if [ -z "$skipped" ]; then
		skipped=" -"
	fi
	if [ -z "$pushed" ]; then
		pushed=" -"
	fi
	
	popd > /dev/null
	echo
	echo -e "Summary"
	echo -e "-------"
	echo -e "Skipped  :${cRED}${skipped}${cLIGHTGRAY}"
	echo -e "Pushed   :${cGREEN}${pushed}${cLIGHTGRAY}"
	echo -e "Version  : ${cTURQUOISE}${newVersion}\n"
}

# quick pull binary from repo to a remote server using ssh (semi-automatic)
qpull() {
	if [ -z "$3" ]; then
		echo "usage: qpull <machine_name> <service_name> <version> [gocd]"
		echo "  machine_name    remote machine, eg. staging04"
		echo "  service_name    eg. tap, frs, fetcher"
		echo "  version         eg. develop.b8c3b2f-staging01-fixAirportInfo"
		echo "  gocd            type gocd if you wanna pull from gocd directory"
		return 1
	fi

	if [ "$4" == "gocd" ]; then
		local gocdDir="/var/$(getTerm env1)/gocd"
	fi

	if [ $2 = "fetcher" ]; then
		local pullCommand="/var/$(getTerm env1)/running/deploy-scripts/remote-pull-fetcher.sh ${3} repo01 ${gocdDir}"
	else
		local pullCommand="stop-${2}
/var/$(getTerm env1)/running/deploy-scripts/remote-pull.sh ${2} ${3} repo01 ${gocdDir}
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
	echo "once logged in, please paste (Ctrl+Shift+V)"
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

listAllPorts() {
	set -o posix; set | grep PORT
}

exe() {
	if [ -z "$1" ]; then
		echo "usage: exe <any command>"
		return 1
	fi

	startTime=`date +%N`
	echo $startTime
	# TODO :
	# - optimize so can run pipe command
	# - fix invalid timelapse (eg. when ssh)

	alias $@ &>/dev/null
	if [ $? -eq 0 ]; then
		# if command is an alias, then run the alias
		local xx=$(alias $@ | cut -d = -f2 | cut -d \' -f2)
		eval $xx
	else
		$@
	fi
	endTime=`date +%N`
	echo $endTime
  	elapsedTime=`expr \( $endTime - $startTime \) / 1000000`
  	echo -e "${cYELLOW}${uCHECK} ${elapsedTime} ms"
}

get-millis() {
	date +%s%3N
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
    	echo $1 | grep -q '[0-9]$'
    	if [ $? -eq 0 ]; then # if $1 contains number in the end
    		thehost="$1.$(getTerm env1).com"
    	else
    		thehost=$1
    	fi
        ssh ansible01 "ansible $thehost -m shell -a 'cat /var/$(getTerm env1)/fetcher/build.properties'"
        return 0
    fi

    local PORT=$(portof $2)
    if [ -z "$PORT" ]; then
        echo "service '${2}' not found"
        return 2
    fi
    ssh ansible01 "curl $1:${PORT}/whoami" | python -m json.tool
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
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. $DIR/vars

myTERM=$DIR/term

helpme() {
	echo -e "
calm down, here are some tools for you... ${uSMILE} 
  
  copyFrom               - copy content of remote file to clipboard
  extract                - effortlessly extract any compressed file type
  get-byte-hr            - get human readable byte size
  get-millis             - get current time in milliseconds
  get-mongo-db-size      - get mongo database size
  get-mongo-colls        - get mongo collection names
  git-sync               - git combo: fetch-[stash]-rebase-[stash pop]
  qclip                  - quick copy any variable to clipboard
  qstrip                 - quick strip a URL into readable format
  qtail                  - tail (coloured) directly from remote machine
  ssh-whoami             - get whoami status from $(getTerm env1) service name on target machine
  synch-db               - sync db from remote machine
  to-mongo               - connect to remote mongo machine directly (automatic)
  db-tojson              - get mongo query to find all (without limit)
  unlock-keyboard        - resolve idea \"cannot type\" problem
  wew                    - check last command return status
${clDARKGRAY}currently disabled commands (under maintenance):
  allservices            - list all $(getTerm env1) services
  exe (beta)             - run any command with elapsed time information
  get-log-range          - get log range determined by keyword
  ngrep                  - grep log on remote host / group at once
  ntail                  - tail log on multiple machines at once
  portof                 - get port number from $(getTerm env1) service name
  qkill                  - quick kill process by $(getTerm env1) service name (local)
  qlist                  - quick get list of running $(getTerm env1) services
  qpush                  - quick push binary to repo (batch-able)
  qpull                  - quick pull binary from repo to a remote server using ssh (semi-automatic)
  qssh                   - quick ssh to another machine (implicitly through ansible)
  serviceof              - get $(getTerm env1) service name from port number
  ssh-mongo              - connect to remote mongo machine using ssh (semi-automatic)
${cLIGHTGRAY}
tips: how to use? try one of those commands by run it without parameter
"
}

get-chmod-num() {
	stat --format '%a' $1
}

running-dev2() {
	ps aux | grep -v grep | grep dev2 | rev | cut -d' ' -f3 | rev
}

is() {
	if [ -z "$1" ]; then
		echo "usage: is <condition>"
		echo "eg : is 1 == 1"
		return 1
	fi
	[ $@ ] && echo true || echo false
}

ngrep() {
	if [ -z "$3" ]; then
		echo "usage: ngrep <hostname> <log-filename> <grep-syntax>"
		echo "   hostname     eg. frs13, frsA, fb"
		echo "   grep-syntax  regular grep syntax without grep"
		echo "example: ngrep frsA frs.log ERROR.*RouteFetcher -A1"
		return 1
	fi
	
	thehost=$(sanitize-host $1)
	logfile=$2
	shift 2
	echo "$@"
	if [[ "$@" == *"|"* ]]; then
		echo ada pipe
		beforepipe=$(echo "$@" | cut -d'|' -f1)
		afterpipe='| $(echo "$@" | cut -d'|' -f2-)'
	else
		beforepipe="$@"
		afterpipe=
	fi
	echo ssh ansible01 "ansible $thehost -m shell -a 'grep $beforepipe /var/$(getTerm env1)/log/$logfile $afterpipe'"
	return 0
}

ntail() {
	if [ -z "$2" ]; then
		echo "usage: ntail [lines] <log-filename> <machine1> [machine2 ...]"
		echo "   lines  by default is 100 if not defined"
		echo "eg: ntail 1000 frs.log frs16 frs17"
		return 1
	fi
	if [[ $1 =~ ^[0-9]+$ ]]; then # check if number
		# echo "number"
		lines=$1
		shift 1
	else
		# echo "not number"
		lines=100
	fi
	local log=$1
	shift
	local commands=
	for mac in "${@}"
	do
		commands+="qssh -n $mac 'tail -${lines}f /var/$(getTerm env1)/log/$log' | sed 's/^/[$mac]┃/' & "
	done
	eval $commands \
      | sed -u 's/\(\[[^\[ =]*\]\)/\x1b[1m\1\x1b[0m/g' \
      | sed -u 's/\(.* FATAL .*\)/\x1b[0;31m\1\x1b[0m/g' \
      | sed -u 's/\(.* ERROR .*\)/\x1b[0;31m\1\x1b[0m/g' \
      | sed -u 's/\( WARN \)/\x1b[0;33m\1\x1b[0m/g' \
      | sed -u 's/\( INFO \)/\x1b[0;32m\1\x1b[0m/g' \
      | sed -u 's/\(http:\/\/[^ ]*\)/\x1b[2;4;36m\1\x1b[0m/g'
}

qtail() {
	tailingDepth=-1000f
	if [ -z "$2" ]; then
		echo "usage :  qtail [-#f] <host> <log-filename>"
		echo "example: qtail -100f staging05 fops_console.log"
		return 1
	elif [ "$4" ]; then
		echo "too much arguments"
		return 1
	else
		if [ "$3" ]; then
			tailingDepth=$1
			shift 1
		fi
		qssh $1 "tail $tailingDepth /var/$(getTerm env1)/log/$2 \\
      | sed -u 's/\(\[[^\[ =]*\]\)/\x1b[1m\1\x1b[0m/g' \\
      | sed -u 's/\(.* FATAL .*\)/\x1b[0;31m\1\x1b[0m/g' \\
      | sed -u 's/\(.* ERROR .*\)/\x1b[0;31m\1\x1b[0m/g' \\
      | sed -u 's/\( WARN \)/\x1b[0;33m\1\x1b[0m/g' \\
      | sed -u 's/\( INFO \)/\x1b[0;32m\1\x1b[0m/g' \\
      | sed -u 's/\(http:\/\/[^ ]*\)/\x1b[2;4;36m\1\x1b[0m/g'"
		return 0
	fi
}

get-byte-hr() {
	numfmt --to=iec-i --suffix=B --padding=7 $@
};

get-mongo-db-size() {
	if [ -z "$2" ]; then
		echo "usage: get-mongo-db-size <host> <db>"
		return 1
	fi
	mongo --host $1 --eval "db = db.getMongo().getDB('$2'); db.stats().dataSize" | tail -1 | get-byte-hr
}

get-mongo-colls() {
	if [ -z "$2" ]; then
		echo "usage: get-mongo-colls <host> <db>"
		return 1
	fi
	mongo --host $1 --eval "db = db.getMongo().getDB('$2'); db.getCollectionNames();" | tail -1 | sed 's/,/ /g'
}

synch-db() {
	if [ "$1" == "--to" ]; then
		targetHost=$2
		shift 2
	else
		targetHost=localhost
	fi
	if [ "$1" == "--query" ];then
		query=$2
		shift 2
	fi
	if [ -z "$2" ]; then
		echo "usage: synch-db [--to targetHost] [--query queryStr] <host> <db> [<collection1> [collection2 ...]]"
		return 1
	fi

	local host=$1
	local db=$2
	shift 2

	# sanity check
	nc -vz $host 27017 2> /dev/null
	if [ $? -ne 0 ]; then
		echo -e "${clRED}mongo can't connect to ${cLIGHTGRAY}$host";
		return 2;
	fi

	local MONGO_USER=admin
	local MONGO_PWD=null
	# don't require pasword at all
	# if [ -n "$MONGO_PWD" ]; then
	# 	printf "(Leave empty if no auth needed) "
	# 	MONGO_PWD=$(qdec $MONGO_USER)
	# fi

	local colls="${@}"
	if [ -z "$1" ]; then # whole db
		colls=$(get-mongo-colls $host $db)
		read -p "syncing db $db, size:$(get-mongo-db-size $host $db). Are you sure[Y/N]? "
		if ! [[ $REPLY =~ ^[Yy]$ ]]; then
			return 3;
		fi
	fi

	for col in $colls
	do
		single-dump $host $db $col $MONGO_USER $MONGO_PWD $targetHost $query
	done
}

single-dump() {
	if [ -z "$7" ]; then
		tmpFile=/tmp/$1.$2.$3
	else
		tmpFile=/tmp/$1.$2.$3.$(get-millis)
	fi
	if [ "$5" == "null" ]; then
		# use mongodump for exporting in bson files
		mongoexport --host $1:27017 --db $2 --collection $3 --out $tmpFile --query "$7"
	else
		mongoexport --host $1:27017 --db $2 --collection $3 --username $4 --password $5 --out $tmpFile --query "$7"
	fi
	if [ $? -eq 0 ]; then
		echo -e "${cTURQUOISE}syncing ${3} to ${6}...${cLIGHTGRAY}"	
		if [ -z "$7" ]; then
			# use mongorestore for importing bson files, remove argument `--file`
			# instead of $tmpFile, use this: restoredFile=$(find $tmpFile/$2/$3.bson)
			mongoimport $MONGO_AUTH --host $6 --db $2 --collection $3 --file $tmpFile --drop
		else # if query exists then remove documents instead of drop collections
			echo -e "${cTURQUOISE}by ${7}...${cLIGHTGRAY}"
			mongo $2 --eval "db.$3.remove($7)"
			mongoimport $MONGO_AUTH --host $6 --db $2 --collection $3 --file $tmpFile
		fi
	else
		echo -e "${cRED}Problem occured. Not importing${cLIGHTGRAY}"
	fi
	# rm $tmpFile
}

# help you remember what is the script to print compact query
db-tojson() {
	if [ -z "$1" ]; then
		echo "usage: db-tojson <db-name>"
		echo "  it will give you (clipboard) script to get compact result of query"
		return 1
	fi
	local result="db.${1}.find().forEach(function(f){print(tojson(f, '', true));});"
	echo -e "$result <-- ${cTURQUOISE}copied to clipboard.${cLIGHTGRAY}"
	printf "${result}" | xclip -sel c
}

get-log-range() {
	if [ -z "$3" ]; then
		echo "usage: getLogRange <filename> <keyword-from> <keyword-to>"
		echo "  it will get range from the first time <keyword-from> is found until the last <keyword-to> is found"
		return 1
	fi
	if [ ! -f $1 ]; then
		echo "file \"${1}\" doesn't exists"
		return 2
	fi
	local fromLine=$(grep -n "$2" $1 | head -1 | cut -d':' -f 1)
	local toLine=$(grep -n "$3" $1 | tail -1 | cut -d':' -f 1)
	if [ -z "$fromLine" ]; then
		echo "keyword \"${2}\" not found in $1"
		return 3
	fi
	if [ -z "$toLine" ]; then
		echo -e "${cYELLOW}keyword \"${3}\" not found, grab to the last line...${cLIGHTGRAY}"
		# get last line number
		toLine=$(wc -l $1 | cut -d' ' -f 1)
	fi
	sed -n ${fromLine},${toLine}p $1
}

copyFrom() {
	if [ -z "$2" ]; then
		echo "usage: copyFrom <remote-machine> <remote-file-path>"
		return 1
	fi
	ssh $1 "cat $2" | xclip -sel c
}

qstrip() {
	if [ -z "$1" ]; then
		echo "usage: qstrip <URL-to-strip>"
		return 1
	fi
	echo $1 | sed 's/[&|?]/\n/g'
}

git-sync() {
	if [ $(git rev-parse --git-dir) ]; then # check whether this dir is git repository
		if [ -z "$1" ]; then
			git fetch --no-tags
		else
			echo -e "only fetching ${1}..."
			git fetch --no-tags origin $1
		fi
		local branchName=$(getCurrentGitBranch)
		local updatedCount=$(git log --oneline ${branchName}..origin/${branchName} | wc -l)
		if [ $updatedCount -gt 0 ]; then
			local modifiedFilesCount=$(git status -uno --porcelain | wc -l)
			if [ $modifiedFilesCount -gt 0 ]; then
				echo -e "${cGREEN}modified files found, stashing first...${cLIGHTGRAY}"
				git stash
				echo -e "${cGREEN}rebasing...${cLIGHTGRAY}"
				git rebase
				echo -e "${cGREEN}popping stash...${cLIGHTGRAY}"
				git stash pop
				echo -e "${cGREEN}"
			else
				echo -e "${cTURQUOISE}directly fetch & rebase...${cLIGHTGRAY}"
				git rebase
				echo -e "${cTURQUOISE}"
			fi
			echo -e "Sync complete.${cLIGHTGRAY}"
		else
			echo -e "${cYELLOW}no new commit from remote${cLIGHTGRAY}"
		fi
	fi
}

qclip() {
	if [ -z "$1" ]; then
		echo "usage: qclip <variable>"
		return 1
	fi
	printf $1 | xclip -sel c
}

qenc() {
	if [ -z "$1" ]; then
		echo "usage: qenc <role> (text to encrypt will be prompted later)"
		return 1
	fi
	read -s -p "plain-text : " PLAIN
	echo ""
	echo $PLAIN | openssl enc -aes-256-cbc -a -salt -out $DIR/$(getTerm $1)
}

qdec() {
	if [ -z "$1" ]; then
		echo "usage: qdec <role>"
		return 1
	fi
	openssl enc -aes-256-cbc -d -a -in $DIR/$(getTerm $1)
}

# ssh-ing a machine through ansible
qssh() {
	if [ $1 == "-n" ]; then # hidden param to redirects stdin from /dev/null
		opt="-n"
		shift
	fi
	if [ -z "$1" ]; then
		echo "usage: ssh <target_machine>"
		echo "  target_machine   eg. tv, frs, tap"
		return 1
	fi
	ssh -t $opt $(getTerm prdgateway) $@
}

qpsql() {
	if [ -z "$1" ]; then
		echo "usage: qpqsl <username>"
		return 1
	fi
	if [ -z "$2" ]; then
		echo "connecting to replica"
		hostname=$(getTerm replica)
	else
		if [ "$2" == "master" ]; then
			echo "connecting to master"
			hostname=$(getTerm master)
		else
			echo "'${2}' is unknown"
			return 2
		fi;
	fi;

	qssh PGPASSWORD="'$(qdec $1)'" psql -h $hostname -d $(getTerm dbname) -U $1
}

# check last command return status
wew() {
	if [ $? -eq 0 ]; then
		echo -e "${cTURQUOISE}${uCHECK}${cLIGHTGRAY}"
	else
		echo -e "${cRED}${uWRONG}${cLIGHTGRAY}"
	fi
}

# resolve idea "can't type" problem (corner case)
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
getCurrentGitBranch() {
	git rev-parse --abbrev-ref HEAD 2> /dev/null
}

# get formatted current git branch name
getCurrentGitBranch2 () {
  # git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1]:/'

  # alternative way
  local branchName=$(getCurrentGitBranch)
  if [ -n "$branchName" ]; then
  	echo "[${branchName}]:"
  fi
}


# connect to remote mongo machine using ssh
# warning! this is semi-automatic function
ssh-mongo() {
	if [ -z "$2" ]; then
		echo "usage: ssh-mongo <machine_code> <db_name> [write]"
		echo "  machine_code    eg. data for mongodata"
		echo "  db_name         eg. $(getTerm env1)-agent"
		echo "  write           optional, leave empty for read only"
		return 1
	fi

	if [ -n "$3" ] && [ $3 = "write" ]; then
		DBVAR=dbPrimary
		MSUFFIX=03
	else
		DBVAR=dbSecondary
		MSUFFIX=02
	fi
	
	# 1. store all mongo commands to clipboard
	local CMDS="mongo
\$${DBVAR}.connect('mongo${1}','${2}')"

	echo -e "$CMDS" | xclip -sel c
	echo "once logged in, please paste (Ctrl+Shift+V)"
	read -s -n1 -p "press any key to continue..."

	# 2. ssh to remote machine
	qssh mongoscript${MSUFFIX}

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
		MONGO_USER=dev
	else
		if [ $3 = 'admin' ]; then
			MONGO_USER=admin
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
	local onServices=()
	for p in "${runningPorts[@]}"
	do
		x=`echo "${p}" | sed 's/[^0-9]*//g'` # sanitize number
		echo $(serviceof $x)		
		# onServices+=($(serviceof $x))
	done
	return 0
	#todo enchanced : add build version next to service names
	thehost=$(sanitize-host $1)
	for x in ${!onServices[@]}
	do
		local thisVersion=ssh ansible01 "ansible $thehost -m shell -a 'cat /var/$(getTerm env1)/running/${onServices[$x]}/WEB-INF/classes/build.properties | grep build.version | cut -d'=' -f 2'"
		echo "${onServices[$x]} - ${thisVersion}"
	done
}

getCurrentBuildVersion() {
	if [ -a ".git" ]; then
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

allservices() 
{
    grep "^start.*().*PORT" -h ${otherBrc} | cut -d \( -f 1 | cut -d - -f 2-
}

# get port number by service name
portof()
{
    if [ -z "$1" ]; then
        echo "usage: portof <service name>"
        echo "   eg: portof frs"
        return 1
    fi

    local svcs=($(allservices))
    for s in "${svcs[@]}"
    do
        if [ "$s" == "$1" ]; then
            local thePort=$(grep "stop-${1}.()" -h ${otherBrc} | cut -d { -f 2 | cut -d ' ' -f 3 | cut -d $ -f 2)
            echo ${!thePort}
            return 0
        fi
    done
}

# get service name by port number
serviceof()
{
    if [ -z "$1" ]; then
        echo "usage: serviceof <port number>"
        echo "   eg: serviceof 60091"
        return 1
    fi

    if [ ${#1} -ne 5 ]; then
        echo "port must have length 5"
        return 2
    fi

    local portVar=$(grep "=${1}" -h ${otherBrc} | cut -d "=" -f1 | cut -d' ' -f2)
    if [ -n "$portVar" ]; then
        grep "start-.*${portVar}" -h ${otherBrc} | cut -d \( -f1 | cut -d - -f2
        return 0
    else
        return 3
    fi
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
    	thehost=$(sanitize-host $1)
        ssh ansible01 "ansible $thehost -m shell -a 'cat /var/$(getTerm env1)/fetcher/build.properties'"
        return 0
    fi

    local PORT=$(portof $2)
    if [ -z "$PORT" ]; then
        echo "service '${2}' not found"
        return 2
    fi

	thehost=$(sanitize-host $1)
	curl $1:${PORT}/whoami/ | python -m json.tool
}

sanitize-host() {
	echo $1 | grep -q '[0-9]$'
	if [ $? -eq 0 ]; then # if $1 contains number in the end
		thehost="$1.$(getTerm env1).com"
	else
		thehost=$1
	fi
	echo $thehost
}

PROMPT_THEME=$(getTerm theme)
# force override coloring prompt
case $PROMPT_THEME in
	1) # default
		PS1="\t $ccYELLOW\$(getCurrentGitBranch2)$ccGREEN\u@\h$ccLIGHTGRAY:$ccBLUE\w$ccLIGHTGRAY\$ ";;
	2) # midnight
		PS1="\t $ccTURQUOISE\$(getCurrentGitBranch2)$ccBLUE\u@\h$ccLIGHTGRAY:$ccPURPLE\w$ccLIGHTGRAY\$ ";;
esac

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

#remap Home-End-PgUp-PgDn (normal / external keyboard) and Home-PgUp-PgDn-End (switched / internal keyboard)
keyboard-map() {
    if [ -z "$1" ]; then
        echo "usage: keyboard-internal <is_switch_rightmost_buttons>"
        echo "  is_switch_rightmost_buttons    false=normal layout: Home-End-PgUp-PgDn"
        echo "  is_switch_rightmost_buttons    true=changed layout: Home-PgUp-PgDn-End"
        return 1
    fi

    if [ $1 = 'true' ]; then
    	xmodmap -e "keycode 115 = Prior"
    	xmodmap -e "keycode 112 = Next"
    	xmodmap -e "keycode 117 = End"
        echo "keyboard layout changed to (Home-PgUp-PgDn-End)"
        return 0
    else
    	xmodmap -e "keycode 115 = End"
    	xmodmap -e "keycode 112 = Prior"
    	xmodmap -e "keycode 117 = Next"
        echo "keyboard layout changed to (Home-End-PgUp-PgDn)"
        return 0
    fi
}

# copied from: http://serverfault.com/a/3842
extract () {
   if [ -f $1 ] ; then
       case $1 in
           *.tar.bz2)   tar xvjf $@    ;;
           *.tar.gz)    tar xvzf $@    ;;
           *.bz2)       bunzip2 $@     ;;
           *.rar)       unrar x $@     ;;
           *.gz)        gunzip $@      ;;
           *.tar)       tar xvf $@     ;;
           *.tbz2)      tar xvjf $@    ;;
           *.tgz)       tar xvzf $@    ;;
           *.zip)       unzip $@       ;;
           *.Z)         uncompress $@  ;;
           *.7z)        7z x $@        ;;
           *)           echo "don't know how to extract '$@'..." ;;
       esac
   else
       echo "'$1' is not a valid file!"
   fi
}

try-land() {
    git fetch --no-tags origin develop && git rebase origin/develop && arc land --onto develop
}

#pre-requisite: checked out on develop branch
git-land() {
    if [ -z "${1}" ]; then
      git fetch --no-tags origin develop; git rebase; git push;
    else
      for (( c=1; c<=${1}; c++ ))
      do
        echo "attempt #$c"
        git fetch --no-tags origin develop; git rebase; git push;
      done
    fi
}

gfo() {
    git fetch --no-tags origin 
}

arclog() {
    arc patch ${1} ; git log
}

trap 'echo -e "${clPURPLE}-- Started at $(date +"%H:%M:%S") --${cLIGHTGRAY}"' DEBUG

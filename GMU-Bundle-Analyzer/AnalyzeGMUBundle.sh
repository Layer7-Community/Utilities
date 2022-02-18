#!/bin/bash
#
# Script to analyze a GMU bundle exported from a Layer 7 API Gateway
#
# Expects the xpath utility (XML::XPath) to be installed and available
#
# Call with -h to see help
#
# Note: the lists of objects by ID are delimited by | to account for when
#       objects come out of LDAP that may have spaces in the ID. If an LDAP
#       object has a | in the DN it will break the analysis for that object
#
# Jay MacDonald - v1.0 - 20191017 - Original version
# Jay MacDonald - v1.1 - 20220217 - Set to use | for delimiter in types lists
#                                   since spaces interfered with LDAP IDs and
#                                   fixed a few bugs
#############################################################

################################
# Set some default values
VERBOSE="true"
DEBUG="false"
DEPENDENCIES="false"
LOG="false"
FULL="false"
IGNORE_TYPES='SOLUTION_KIT|GENERIC|SERVER_MODULE_FILE|RBAC_ROLE|RESOURCE_ENTRY'

##################
# Define functions

print_help () {
	echo "Command line parameters:"
	echo "  -b <file>     : Bundle file name"
	echo "  -F            : Full analysis (include SOLUTION_KIT, RBAC_ROLES, etc)"
	echo "  -D            : Analyze dependencies"
	echo "  -d            : Debug mode (print extra information)"
	echo "  -q            : Quiet output - only display analysis section"
	echo "  -l            : Log details to AnalyzeGMUBundle.log"
	echo "  -h            : Print this list and exit"
	echo ""
	echo "Exit status 0 if success, 1 if not"
}

verbose() {
	if [ "$VERBOSE" == "true" ] ; then
		echo $2 $1
	fi
}

debug() {
	if [ "$DEBUG" == "true" ] ; then
		echo $2 $1
	fi
}

log() {
	if [ "$LOG" == "true" ] ; then
		printf "%5d $1\n" $(($(date +%s) - $STIME)) >> AnalyzeGMUBundle.log
	fi
}

htmlDecode() {
	IFS=''
	echo $1 | sed 's/&gt;/>/g' | sed 's/&lt;/</g' | sed 's/&amp;/\&/g'
	IFS=' '
}

setIndent() {
	local i=1
	local INDENT
	while [ $i -lt $1 ] ; do
		INDENT="$INDENT|   "
		((i++))
	done
	echo "$INDENT\_ "
}

getAssociatedEncapsulatedAssertions() {
	local INDENT=$(setIndent $2)
	local NAME

	log "====> Getting associated encapsulated assertions for policy $1"

	if [ "${ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[$1]}" ] ; then
		NAME=$(echo ${ENCAPSULATED_ASSERTIONS[${ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[$1]}]})
		echo "${INDENT}$NAME (ASSOCIATED ENCAPSULATED ASSERTION)"
		log "=====> Name=$NAME (ASSOCIATED ENCAPSULATED ASSERTION)"
	fi
}

getAssociatedScheduledTasks() {
	local INDENT=$(setIndent $2)
	local NAME

	log "====> Getting associated scheduled tasks for policy $1"

	if [ "${SCHEDULED_TASKS_BY_POLICY_ID[$1]}" ] ; then
		NAME=$(echo ${SCHEDULED_TASKS[${SCHEDULED_TASKS_BY_POLICY_ID[$1]}]})
		echo "${INDENT}$NAME (ASSOCIATED SCHEDULED TASK)"
		log "=====> Name=$NAME (ASSOCIATED SCHEDULED TASK)"
	fi
}

getFragments() {
	local INDENT=$(setIndent $2)
	local NAME
	local GUID
	local ID
	local stringValue

	declare -A FOUND

	log "====> Getting fragments referenced by policy"
	for GUID in $(echo $1 | $XPATHBIN "//L7p:Include/L7p:PolicyGuid/@stringValue" 2>/dev/null) ; do
		stringValue=""
		eval $GUID
		log "=====> Processing FRAGMENT: $stringValue"
		if [[ "$stringValue" && -z "${FOUND[$stringValue]}" ]] ; then
			FOUND[$stringValue]="1"
			ID="${POLICIES_BY_GUID[$stringValue]}"
			if [[ "$ID" && "${POLICIES[$ID]}" ]] ; then
				echo "${INDENT}${POLICIES[$ID]} (INCLUDED FRAGMENT)"
				log "======> Name=${POLICIES[$ID]}"
			else
				echo "${INDENT}$stringValue (INCLUDED FRAGMENT) !! MISSING FROM BUNDLE !!"
				log "======> Name=<unknown>"
			fi
		fi
	done

	unset FOUND
}

getEncapsulatedAssertions() {
	local INDENT=$(setIndent $2)
	local NAME
	local GUID
	local ID
	local ATTRIBUTE
	local stringValue

	declare -A FOUND

	log "====> Getting encapsulated assertions referenced by policy"
	for GUID in $(echo $1 | $XPATHBIN "//L7p:Encapsulated/L7p:EncapsulatedAssertionConfigGuid/@stringValue" 2>/dev/null) ; do
		stringValue=""
		eval $GUID
		log "=====> Processing ENCAPSULATED_ASSERTION: $stringValue"
		if [[ "$stringValue" && -z "${FOUND[$stringValue]}" ]] ; then
			FOUND[$stringValue]="1"
			ID="${ENCAPSULATED_ASSERTIONS_BY_GUID[$stringValue]}"
			if [[ "$ID" && "${ENCAPSULATED_ASSERTIONS[$ID]}" ]] ; then
				NAME=$(echo ${ENCAPSULATED_ASSERTIONS[$ID]})
				echo "${INDENT}$NAME (ENCAPSULATED ASSERTION)"
				log "======> Name=$NAME (ENCAPSULATED_ASSERTION)"
			else
				ATTRIBUTE=$(echo $1 | $XPATHBIN "//L7p:Encapsulated/L7p:EncapsulatedAssertionConfigGuid[@stringValue='$stringValue']/../L7p:EncapsulatedAssertionConfigName/@stringValue" 2>/dev/null | head -1)
				eval $ATTRIBUTE
				echo "${INDENT}${stringValue} (ENCAPSULATED ASSERTION) !! MISSING FROM BUNDLE !!"
				log "======> <unknown>"
			fi
		fi
	done

	unset FOUND
}

getIdentityProviders() {
	local INDENT=$(setIndent $2)
	local GOID
	local goidValue

	declare -A FOUND

	log "====> Getting identity providers referenced by policy"
	for GOID in $(echo $1 | $XPATHBIN "//L7p:Authentication/L7p:IdentityProviderOid/@goidValue" 2>/dev/null) ; do
		goidValue=""
		eval $GOID
		log "=====> Processing IDENTITY_PROVIDER: $goidValue"
		if [[ "$goidValue" && -z "${FOUND[$goidValue]}" ]] ; then
			FOUND[$goidValue]="1"
			if [[ "$goidValue" && "${IDENTITY_PROVIDERS[$goidValue]}" ]] ; then
				echo "${INDENT}${IDENTITY_PROVIDERS[$goidValue]} (IDENTITY PROVIDER)"
				log "======> Name=${IDENTITY_PROVIDERS[$goidValue]} (IDENTITY_PROVIDER)"
			else
				echo "${INDENT}$goidValue (IDENTITY PROVIDER) !! MISSING FROM BUNDLE !!"
				log "======> Name=<unknown> (IDENTITY_PROVIDER) !! MISSING FROM BUNDLE !!"
			fi
		fi
	done

	unset FOUND
}

getUsers() {
	local INDENT=$(setIndent $2)
	local ID
	local IDENTITY_PROVIDER
	local NAME
	local USER_ID
	local goidValue
	local stringValue

	declare -A FOUND

	log "====> Getting users referenced by policy"
	for ID in $(echo $1 | $XPATHBIN "//L7p:SpecificUser/L7p:UserUid/@stringValue" 2>/dev/null) ; do
		stringValue=""
		eval $ID
		log "=====> Processing USER: $stringValue"
		if [[ "$stringValue" && -z "${FOUND[$stringValue]}" ]] ; then
			if [ "${USERS[$stringValue]}" ] ; then
				FOUND[$stringValue]="1"
				IDENTITY_PROVIDER=$(echo ${USERS[$stringValue]} | cut -d ':' -f 1)
				NAME=$(echo ${USERS[$stringValue]} | cut -d ':' -f 2-)
				echo "${INDENT}${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (USER)"
				log "=====> ${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (USER)"
			else
				USER_ID=$stringValue
				eval "$(echo $1 | $XPATHBIN "//L7p:SpecificUser/L7p:UserUid[@stringValue='$USER_ID']/../L7p:UserName/@stringValue" 2>/dev/null)"
				NAME="$stringValue"
				eval $(echo $1 | $XPATHBIN "//L7p:SpecificUser/L7p:UserUid[@stringValue='$USER_ID']/../L7p:IdentityProviderOid/@goidValue" 2>/dev/null)
				IDENTITY_PROVIDER="$goidValue"
				if [ "${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]}" ] ; then
					log "=====> ${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (USER) !! MISSING FROM BUNDLE !!"
					echo "${INDENT}${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (USER) !! MISSING FROM BUNDLE !!"
				else
					log "=====> ${NAME} in ${IDENTITY_PROVIDER} (USER) !! USER & IDENTITY_PROVIDER MISSING FROM BUNDLE !!"
					echo "${INDENT}${NAME} in ${IDENTITY_PROVIDER} (USER) !! USER & IDENTITY_PROVIDER MISSING FROM BUNDLE !!"
				fi
			fi
		fi
	done

	unset FOUND
}

getGroups() {
	local INDENT=$(setIndent $2)
	local ID
	local IDENTITY_PROVIDER
	local NAME
	local GROUP_ID

	declare -A FOUND

	log "====> Getting groups referenced by policy"
	for ID in $(echo $1 | $XPATHBIN "//L7p:MemberOfGroup/L7p:GroupId/@stringValue" 2>/dev/null) ; do
		local stringValue=""
		eval $ID
		log "=====> Processing GROUP: $stringValue"
		if [[ "$stringValue" && -z "${FOUND[$stringValue]}" ]] ; then
			FOUND[$stringValue]="1"
			if [ "${GROUPS[$stringValue]}" ] ; then
				IDENTITY_PROVIDER=$(echo ${GROUPS[$stringValue]} | cut -d ':' -f 1)
				NAME=$(echo ${GROUPS[$stringValue]} | cut -d ':' -f 2-)
				log "=====> ${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (GROUP)"
				echo "${INDENT}${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (GROUP)"
			else
				GROUP_ID=$stringValue
				eval "$(echo $1 | $XPATHBIN "//L7p:MemberOfGroup/L7p:GroupId[@stringValue='$GROUP_ID']/../L7p:GroupName/@stringValue" 2>/dev/null)"
				NAME="$stringValue"
				eval $(echo $1 | $XPATHBIN "//L7p:MemberOfGroup/L7p:GroupId[@stringValue='$GROUP_ID']/../L7p:IdentityProviderOid/@goidValue" 2>/dev/null)
				IDENTITY_PROVIDER="$goidValue"
				if [ "${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]}" ] ; then
					log "=====> ${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (GROUP) !! MISSING FROM BUNDLE !!"
					echo "${INDENT}${NAME} in ${IDENTITY_PROVIDERS[$IDENTITY_PROVIDER]} (GROUP) !! MISSING FROM BUNDLE !!"
				else
					log "=====> ${NAME} in ${IDENTITY_PROVIDER} (GROUP) !! GROUP & IDENTITY_PROVIDER MISSING FROM BUNDLE !!"
					echo "${INDENT}${NAME} in ${IDENTITY_PROVIDER} (GROUP) !! GROUP & IDENTITY_PROVIDER MISSING FROM BUNDLE !!"
				fi
			fi
		fi
	done

	unset FOUND
}

getServices() {
	local INDENT=$(setIndent $3)
	local NEXTLEVEL=$(($3+1))
	local NAME
	local SERVICE_ID
	local POLICY_XML

	log "==> Getting services in folderID=$1"
	for SERVICE_ID in ${CHILD_SERVICES[$1]} ; do
		NAME="${SERVICES[$SERVICE_ID]}"
		log "===> Processing SERVICE: $SERVICE_ID ($NAME)"
		echo "${INDENT}${NAME} (SERVICE)"
		if [ "$DEPENDENCIES" == "true" ] ; then
			log "====> Loading policy XML for $NAME"
			POLICY_XML=$(htmlDecode "$(echo "${ITEMS[$SERVICE_ID]}" | $XPATHBIN "/l7:Item//l7:Resource[@type='policy']/text()" 2>/dev/null)")
			log "====> Done"
			getFragments "$POLICY_XML" "$NEXTLEVEL"
			getEncapsulatedAssertions "$POLICY_XML" "$NEXTLEVEL"
			getIdentityProviders "$POLICY_XML" "$NEXTLEVEL"
			getUsers "$POLICY_XML" "$NEXTLEVEL"
			getGroups "$POLICY_XML" "$NEXTLEVEL"
		fi
	done
}

getPolicies() {
	local INDENT=$(setIndent $3)
	local NEXTLEVEL=$(($3+1))
	local NAME
	local POLICY_ID
	local POLICY_XML

	log "==> Getting policies in folderID=$1"
	for POLICY_ID in ${CHILD_POLICIES[$1]} ; do
		NAME=${POLICIES[$POLICY_ID]}
		log "===> Processing POLICY: $POLICY_ID ($NAME)"
		echo "${INDENT}${NAME} (POLICY)"
		if [ "$DEPENDENCIES" == "true" ] ; then
			log "====> Loading policy XML for $NAME"
			POLICY_XML=$(echo "${ITEMS[$POLICY_ID]}" | $XPATHBIN "/l7:Item//l7:Resource[@type='policy']/text()" 2>/dev/null | sed 's/&lt;/</g' | sed 's/&gt;/>/g' | sed 's/&amp;/&/g')
			log "====> Done"
			getFragments "$POLICY_XML" "$NEXTLEVEL"
			getEncapsulatedAssertions "$POLICY_XML" "$NEXTLEVEL"
			getAssociatedEncapsulatedAssertions "$POLICY_ID" "$NEXTLEVEL"
			getIdentityProviders "$POLICY_XML" "$NEXTLEVEL"
			getUsers "$POLICY_XML" "$NEXTLEVEL"
			getGroups "$POLICY_XML" "$NEXTLEVEL"
			getAssociatedScheduledTasks "$POLICY_ID" "$NEXTLEVEL"
		fi
	done
}

getSubFolders() {
	local FULL_PATH
	local NAME
	local INDENT
	local LEVEL
	local SUBFOLDERS
	local SUBFOLDER_ID

	NAME=${FOLDERS[$1]}
	FULL_PATH="${2}/$NAME"
	log "======================================= NEW FOLDER"
	log "=> Processing FOLDER: $1 ($FULL_PATH)"
	if [ "$1" != "$ROOTNODEID" ] ; then
		INDENT=$(setIndent $3)
	fi
	echo "${INDENT}${NAME}/"
	SUBFOLDERS="${CHILD_FOLDERS[$1]}"
	LEVEL=$(($3+1))
	if [ "$SUBFOLDERS" ] ; then
		log "==> List of subfolders found by ID: $SUBFOLDERS"
		for SUBFOLDER_ID in $SUBFOLDERS ; do
			NAME=${FOLDERS[$SUBFOLDER_ID]}
			getSubFolders $SUBFOLDER_ID "$FULL_PATH" "$LEVEL"
		done
	fi
	getServices $1 "$FULL_PATH" "$LEVEL"
	getPolicies $1 "$FULL_PATH" "$LEVEL"
}

setFolderPaths() {
	local SUBFOLDERS

	verbose '.' -n
	if [ "$1" != "$ROOTNODEID" ] ; then
		FOLDER_PATHS[$1]="${2}/${FOLDERS[$1]}"
	elif [ "${FOLDERS[$1]}" ] ; then
		FOLDER_PATHS[$1]="/${FOLDERS[$1]}"
	else
		FOLDER_PATHS[$1]=""
	fi
	log "==> $1 == ${FOLDER_PATHS[$1]}"
	SUBFOLDERS="${CHILD_FOLDERS[$1]}"
	if [ "$SUBFOLDERS" ] ; then
		for SUBFOLDER in $SUBFOLDERS ; do
			setFolderPaths $SUBFOLDER "${FOLDER_PATHS[$1]}"
		done
	fi
}

################################################### Start main work

echo "$0 - Analyse a GMU bundle exported from a Layer 7 API Gateway"
echo ""

# Confirm external commands are available
COMMANDS='date xpath sed cut'
for COMMAND in $COMMANDS ; do
	which $COMMAND > /dev/null
	if [ $? -ne 0 ] ; then
		echo "ERROR: Can't run required command: $COMMAND"
		echo "Please ensure that it is available and executable"
		echo ""
		print_help
		exit 1
	fi
done

##############################################################
# Parse the command line options (override defaults set above)
OPTS="b:FqdDlh"

while getopts $OPTS opt ; do
	case $opt in
	   b)	BUNDLE=$OPTARG;;

	   q)	VERBOSE="false";;

	   F)	FULL="true";;

	   d)	DEBUG="true";;

	   D)	DEPENDENCIES="true";;

	   l)	LOG="true";;

	   h)	print_help
		exit 0;;

	   ?)   exit 1;;
	esac
done

verbose "=> Configuration summary:"
if [ "$FULL" == "true" ] ; then verbose "==> Running full analysis of bundle" ; fi
if [ "$DEBUG" == "true" ] ; then verbose "==> Debug mode is on" ; fi
if [ "$DEPENDENCIES" == "true" ] ; then verbose "==> Analysing dependencies" ; fi
if [ "$LOG" == "true" ] ; then verbose "==> Logging details to AnalyzeGMUBundle.log" ; fi


############################
# Determine how xpath is called. Some versions don't expect -q -e
verbose '=> Determining how to call xpath command: ' -n
echo '<foo><bar>baz</bar></foo>' | xpath > /dev/null 2>&1 -q -e '/foo/bar/text()'

if [ $? == 0 ] ; then
	XPATHBIN='xpath -q -e'
else
	XPATHBIN='xpath'
fi
IFS='' ; verbose " '$XPATHBIN'" ; IFS=' '

###############################
# Verify bundle file is defined
if [ -z "$BUNDLE" ] ; then
	echo "ERROR: Bundle file must be defined (use -b)"
	echo ""
	print_help
	exit 1
fi

###########################
# Verify bundle file exists
if [ ! -f "$BUNDLE" ] ; then
	echo "ERROR: Could not find bundle file ($BUNDLE)"
	echo ""
	print_help
	exit 1
fi

######################################################
# Remove log file if logging enabled and file is found
if [ "$LOG" == "true" ] ; then
	STIME=$(date +%s)
	if [ -f AnalyzeGMUBundle.log ] ; then
		verbose "=> Removing AnalyzeGMUBundle.log"
		rm -f AnalyzeGMUBundle.log
		touch AnalyzeGMUBundle.log
	fi
	log "=> Running $0 on $(date '+%A %B %e') at $(date +%T)"
	log "=> Configuration summary:"
	log "==> BUNDLE=$BUNDLE"
	log "==> VERBOSE=$VERBOSE"
	log "==> FULL=$FULL"
	log "==> DEBUG=$DEBUG"
	log "==> DEPENDENCIES=$DEPENDENCIES"
	log "==> LOG=$LOG"
fi

###############################################
# Declare all the associative arrays we may use
unset PARENTS && declare -A PARENTS
unset CHILD_FOLDERS && declare -A CHILD_FOLDERS
unset CHILD_SERVICES && declare -A CHILD_SERVICES
unset CHILD_POLICIES && declare -A CHILD_POLICIES
unset FOLDERS && declare -A FOLDERS
unset FOLDER_PATHS && declare -A FOLDER_PATHS
unset SERVICES && declare -A SERVICES
unset POLICIES && declare -A POLICIES
unset POLICIES_BY_GUID && declare -A POLICIES_BY_GUID
unset ENCAPSULATED_ASSERTIONS && declare -A ENCAPSULATED_ASSERTIONS
unset ENCAPSULATED_ASSERTIONS_BY_GUID && declare -A ENCAPSULATED_ASSERTIONS_BY_GUID
unset ENCAPSULATED_ASSERTIONS_BY_POLICY_ID && declare -A ENCAPSULATED_ASSERTIONS_BY_POLICY_ID
unset CLUSTER_PROPERTIES && declare -A CLUSTER_PROPERTIES
unset SSG_KEY_ENTRIES && declare -A SSG_KEY_ENTRIES
unset SCHEDULED_TASKS && declare -A SCHEDULED_TASKS
unset SCHEDULED_TASKS_BY_POLICY_ID && declare -A SCHEDULED_TASKS_BY_POLICY_ID
unset IDENTITY_PROVIDERS && declare -A IDENTITY_PROVIDERS
unset USERS && declare -A USERS
unset GROUPS && declare -A GROUPS
unset ITEMS && declare -A ITEMS
unset ITEM_LIST && declare -A ITEM_LIST

#######################################################
# Define the regex patterns used when loading the items
REGEX_START_ITEM='^ *<l7:Item>?$'
REGEX_END_ITEM='^ *</l7:Item>?$'
REGEX_ID='^ +<l7:Id>(.+)</l7:Id>?$'
REGEX_TYPE='^ +<l7:Type>([A-Z_]+)</l7:Type>?$'
if [ "$FULL" == "true" ] ; then
	REGEX_IGNORE_TYPES='(BOGUS)'
else
	REGEX_IGNORE_TYPES="($IGNORE_TYPES)"
fi

IN_ITEM=0	# Flag to indicate we are inside and item while reading bundle
ON_LINE=0
NEW_LINE=$'\n'

########################################################
# Read the bundle line by line and load into ITEMS array
verbose "=> Loading items from $BUNDLE" -n
IFS=''
while read LINE ; do
	IFS=' '
	((ON_LINE++))
	if [[ $ON_LINE =~ 0000$ ]] ; then
		log "=> Read $ON_LINE lines"
	fi

	if [[ $LINE =~ $REGEX_START_ITEM ]] ; then
		IN_ITEM=1
		LINE='<l7:Item xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">'
		ITEM=''
		ID=''
		TYPE=''
	fi

	if [[ $LINE =~ $REGEX_END_ITEM && $IN_ITEM -eq 1 ]] ; then
		verbose '.' -n
		IN_ITEM=0
		ITEM+="</l7:Item>"
		ITEMS["$ID"]="$ITEM"
	fi

	if [ $IN_ITEM -eq 1 ] ; then
		ITEM+="${LINE}${NEW_LINE}"
		if [[ $LINE =~ $REGEX_ID ]] ; then
			ID="${BASH_REMATCH[1]}"
		fi
		if [[ $LINE =~ $REGEX_TYPE ]] ; then
			TYPE="${BASH_REMATCH[1]}"
			# We don't care about many types...
			if [[ $TYPE =~ $REGEX_IGNORE_TYPES ]] ; then
				IN_ITEM=0
			else
				ITEM_LIST[$TYPE]+="|$ID"
			fi
		fi
	fi
	IFS=''
done < $BUNDLE
verbose " Found ${#ITEMS[*]} items over $ON_LINE lines of XML"
IFS=' '

# Strip the leading | from each entry in the ITEM_LIST array
for TYPE in ${!ITEM_LIST[*]} ; do
	ITEM_LIST[$TYPE]=$(echo ${ITEM_LIST[$TYPE]} | sed 's/^|//')
done

############################
# Determine cluster hostname
verbose '=> Determining cluster hostname:' -n
log "=> Determining cluster hostname"
CLUSTER_HOSTNAME="<unknown>"	# Default if not found
if [ ${#ITEM_LIST[CLUSTER_PROPERTY]} -ne 0 ] ; then
	IFS='|'
	for OBJECT_ID in ${ITEM_LIST[CLUSTER_PROPERTY]} ; do
		log "==> Processing CLUSTER_PROPERTY $OBJECT_ID"
		IFS=' '
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "===> NAME = $NAME"
		if [ "$NAME" == "cluster.hostname" ] ; then
			CLUSTER_HOSTNAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:ClusterProperty/l7:Value/text()" 2>/dev/null)")
			log "===> CLUSTER_HOSTNAME = $CLUSTER_HOSTNAME"
			break
		fi
		IFS='|'
	done
fi

IFS='' ; verbose " $CLUSTER_HOSTNAME" ; IFS='|'


#######################################################################
# Process folders if any found in the bundle
verbose "=> Processing folders" -n

if [ ${#ITEM_LIST[FOLDER]} -ne 0 ] ; then

	#######################################################################
	# Process folders into FOLDERS array and determine parents and children
	# PARENTS is an associative array that holds the parentId for every folder
	# CHILD_FOLDERS is an associative array that holds all the immediate chilren of a folder
	log "=> Processing folders"
	log "==> List of folders found by ID: ${ITEM_LIST[FOLDER]}"
	IFS='|'
	for OBJECT_ID in ${ITEM_LIST[FOLDER]} ; do
		IFS=' '
		verbose '.' -n
		log "==> Processing FOLDER $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "===> NAME = $NAME"
		FOLDERS[$OBJECT_ID]="$NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item//@folderId" 2>/dev/null)
		log "===> PARENTID = $folderId"
		PARENTS[$OBJECT_ID]="$folderId"
		if [ "$folderId" ] ; then
			if [ "${CHILD_FOLDERS[$folderId]}" ] ; then
				CHILD_FOLDERS[$folderId]+="|$OBJECT_ID"
			else
				CHILD_FOLDERS[$folderId]="$OBJECT_ID"
			fi
		fi
		IFS='|'
	done
	verbose " Processed ${#FOLDERS[*]} folders"

	##########################
	# Determine root folder ID
	# Root folder ID will be the one that either doesn't have a parent OR that we don't know the parent
	verbose '=> Determining root folder ID:' -n
	log "=> Determining root folder ID"
	for ROOTNODEID in "${!FOLDERS[@]}" ; do
		PARENT=${PARENTS[$ROOTNODEID]}
		if [ -z "$PARENT" ] ; then
			break
		fi
		if [ -z "${FOLDERS[${PARENTS[$ROOTNODEID]}]}" ] ; then
			break
		fi
	done
	IFS='' ; verbose " $ROOTNODEID" ; IFS='|'

	########################################
	# Set the name of the root node to empty
	if [ "${FOLDERS[$ROOTNODEID]}" == "Root Node" ] ; then
		FOLDERS[$ROOTNODEID]=""
	fi

	#############################
	# Load the FOLDER_PATHS array
	verbose "=> Determining folder paths" -n
	log "=> Determining folder paths"
	setFolderPaths "$ROOTNODEID" ""
	verbose " Processed ${#FOLDER_PATHS[*]} folder paths"
else
	verbose ": No folders found in bundle"
fi

########################################################################
# Process services into SERVICES array and determine parent and children
verbose "=> Processing services" -n
log "=> Processing services"
if [ ${#ITEM_LIST[SERVICE]} -ne 0 ] ; then
	log "==> List of services found by ID: ${ITEM_LIST[SERVICE]}"
	for OBJECT_ID in ${ITEM_LIST[SERVICE]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing SERVICE $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item//@folderId" 2>/dev/null)
		log "====> PARENTID = $folderId"
		PARENTS[$OBJECT_ID]="$folderId"
		if [ "$folderId" ] ; then
			if [ "${CHILD_SERVICES[$folderId]}" ] ; then
				CHILD_SERVICES[$folderId]+="|$OBJECT_ID"
			else
				CHILD_SERVICES[$folderId]="$OBJECT_ID"
			fi
		fi
		SERVICES[$OBJECT_ID]="$NAME"
		IFS='|'
	done
	verbose " Processed ${#SERVICES[*]} services"
else
	verbose ": No services found in bundle"
fi

########################################################################
# Process policies into POLICIES array and determine parent and children
verbose "=> Processing policies" -n
log "=> Processing policies"
if [ ${#ITEM_LIST[POLICY]} -ne 0 ] ; then
	log "==> List of policies found by ID: ${ITEM_LIST[POLICY]}"
	for OBJECT_ID in ${ITEM_LIST[POLICY]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing POLICY $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item//@folderId" 2>/dev/null)
		log "====> PARENTID = $folderId"
		PARENTS[$OBJECT_ID]="$folderId"
		if [ "$folderId" ] ; then
			if [ "${CHILD_POLICIES[$folderId]}" ] ; then
				CHILD_POLICIES[$folderId]+="|$OBJECT_ID"
			else
				CHILD_POLICIES[$folderId]="$OBJECT_ID"
			fi
		fi
		POLICIES[$OBJECT_ID]="$NAME"
		if [ "$DEPENDENCIES" == "true" ] ; then
			eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:Policy/@guid" 2>/dev/null)
			log "====> Policy GUID = $guid"
			POLICIES_BY_GUID[$guid]="$OBJECT_ID"
		fi
		IFS='|'
	done
	verbose " Processed ${#POLICIES[*]} policies"
else
	verbose ": No policies found in bundle"
fi

#####################################################################################################
# Process encapsulated assertions into ENCAPSULATED_ASSERTION array and determine associated policies
verbose "=> Processing encapsulated assertions" -n
log "=> Processing encapsulated assertions"
if [ ${#ITEM_LIST[ENCAPSULATED_ASSERTION]} -ne 0 ] ; then
	log "==> List of encapsulated assertions found by ID: ${ITEM_LIST[ENCAPSULATED_ASSERTION]}"
	for OBJECT_ID in ${ITEM_LIST[ENCAPSULATED_ASSERTION]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing ENCAPSULATED_ASSERTION $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		ENCAPSULATED_ASSERTIONS[$OBJECT_ID]="$NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:EncapsulatedAssertion/l7:PolicyReference/@id" 2>/dev/null)
		log "====> Associated policy = $id (${POLICIES[$id]})"
		ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[$id]="$OBJECT_ID"
		GUID=$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:EncapsulatedAssertion//l7:Guid/text()" 2>/dev/null)
		log "====> Encapsulated assertion GUID = $guid"
		ENCAPSULATED_ASSERTIONS_BY_GUID[$GUID]="$OBJECT_ID"
		IFS='|'
	done
	verbose " Processed ${#ENCAPSULATED_ASSERTIONS[*]} encapsulated assertions"
else
	verbose ": No encapsulated assertions found in bundle"
fi

##########################################################
# Process cluster properties into CLUSTER_PROPERTIES array
verbose "=> Processing cluster properties" -n
log "=> Processing cluster properties"
if [ ${#ITEM_LIST[CLUSTER_PROPERTY]} -ne 0 ] ; then
	log "==> List of cluster properties found by ID: ${ITEM_LIST[CLUSTER_PROPERTY]}"
	for OBJECT_ID in ${ITEM_LIST[CLUSTER_PROPERTY]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing CLUSTER_PROPERTY $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		CLUSTER_PROPERTIES[$OBJECT_ID]="$NAME"
		IFS='|'
	done
	verbose " Processed ${#CLUSTER_PROPERTIES[*]} cluster properties"
else
	verbose ": No encapsulated assertions found in bundle"
fi

#################################################
# Process private keys into SSG_KEY_ENTRIES array
verbose "=> Processing private keys" -n
log "=> Processing private keys"
if [ ${#ITEM_LIST[SSG_KEY_ENTRY]} -ne 0 ] ; then
	log "==> List of SSG keys found by ID: ${ITEM_LIST[SSG_KEY_ENTRY]}"
	for OBJECT_ID in ${ITEM_LIST[SSG_KEY_ENTRY]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing SSG_KEY_ENTRY $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		SSG_KEY_ENTRIES[$OBJECT_ID]="$NAME"
		IFS='|'
	done
	verbose " Processed ${#SSG_KEY_ENTRIES[*]} private keys"
else
	verbose ": No private keys found in bundle"
fi

######################################################################################
# Process scheduled tasks into SCHEDULED_TASKS array and determine associated policies
verbose "=> Processing scheduled tasks" -n
log "=> Processing scheduled tasks"
if [ ${#ITEM_LIST[SCHEDULED_TASK]} -ne 0 ] ; then
	log "==> List of scheduled tasks found by ID: ${ITEM_LIST[SCHEDULED_TASK]}"
	for OBJECT_ID in ${ITEM_LIST[SCHEDULED_TASK]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing SCHEDULED_TASK $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		SCHEDULED_TASKS[$OBJECT_ID]="$NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:ScheduledTask/l7:PolicyReference/@id" 2>/dev/null)
		log "====> Associated policy = $id (${POLICIES[$id]})"
		SCHEDULED_TASKS_BY_POLICY_ID[$id]="$OBJECT_ID"
		IFS='|'
	done
	verbose " Processed ${#SCHEDULED_TASKS[*]} scheduled tasks"
else
	verbose ": No scheduled tasks found in bundle"
fi

##########################################################
# Process identity providers into IDENTITY_PROVIDERS array
verbose "=> Processing identity providers" -n
log "=> Processing identity providers"
if [ ${#ITEM_LIST[ID_PROVIDER_CONFIG]} -ne 0 ] ; then
	log "==> List of identity providers found by ID: ${ITEM_LIST[ID_PROVIDER_CONFIG]}"
	for OBJECT_ID in ${ITEM_LIST[ID_PROVIDER_CONFIG]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing ID_PROVIDER_CONFIG $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		IDENTITY_PROVIDERS[$OBJECT_ID]="$NAME"
		IFS='|'
	done
	verbose " Processed ${#IDENTITY_PROVIDERS[*]} identity providers"
else
	verbose ": No identity providers found in bundle"
fi

##################################################################
# Process users into USERS array with associated identity provider
verbose "=> Processing users" -n
log "=> Processing users"
if [ ${#ITEM_LIST[USER]} -ne 0 ] ; then
	log "==> List of users found by ID: ${ITEM_LIST[USER]}"
	for OBJECT_ID in ${ITEM_LIST[USER]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing USER $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:User/@providerId" 2>/dev/null)
		log "====> Associated provider = $providerId (${IDENTITY_PROVIDERS[$providerId]})"
		USERS[$OBJECT_ID]="$providerId:$NAME"
		IFS='|'
	done
	verbose " Processed ${#USERS[*]} users"
else
	verbose ": No users found in bundle"
fi

####################################################################
# Process groups into GROUPS array with associated identity provider
verbose "=> Processing groups" -n
log "=> Processing groups"
if [ ${#ITEM_LIST[GROUP]} -ne 0 ] ; then
	log "==> List of groups found by ID: ${ITEM_LIST[GROUP]}"
	for OBJECT_ID in ${ITEM_LIST[GROUP]} ; do
		IFS=' '
		verbose '.' -n
		log "===> Processing GROUP $OBJECT_ID"
		NAME=$(htmlDecode "$(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Name/text()" 2>/dev/null)")
		log "====> NAME = $NAME"
		eval $(echo "${ITEMS[$OBJECT_ID]}" | $XPATHBIN "/l7:Item/l7:Resource/l7:Group/@providerId" 2>/dev/null)
		log "====> Associated provider = $providerId (${IDENTITY_PROVIDERS[$providerId]})"
		GROUPS[$OBJECT_ID]="$providerId:$NAME"
		IFS='|'
	done
	verbose " Processed ${#GROUPS[*]} groups"
else
	verbose ": No groups found in bundle"
fi

verbose ''

# Display everything we found if $DEBUG is true
if [ "$DEBUG" == "true" ] ; then
	if [ ${#FOLDERS[@]} -gt 0 ] ; then
		debug ""
		debug "Folders:"
		debug "[Folder ID - Folder Name]"
		for ID in "${!FOLDERS[@]}"; do debug "$ID - ${FOLDERS[$ID]}" ; done
	fi

	if [ ${#FOLDER_PATHS[@]} -gt 0 ] ; then
		debug ""
		debug "Folder Paths:"
		debug "[Folder ID - Folder Path]"
		for ID in "${!FOLDER_PATHS[@]}"; do debug "$ID - ${FOLDER_PATHS[$ID]}" ; done
	fi

	if [ ${#SERVICES[@]} -gt 0 ] ; then
		debug ""
		debug "Services:"
		debug "[Service ID - Path to Service]"
		for ID in "${!SERVICES[@]}"; do debug "$ID - ${FOLDER_PATHS[${PARENTS[$ID]}]}/${SERVICES[$ID]}" ; done
	fi

	if [ ${#POLICIES[@]} -gt 0 ] ; then
		debug ""
		debug "Policies:"
		debug "[Policy ID - Path to Policy]"
		for ID in "${!POLICIES[@]}"; do debug "$ID - ${FOLDER_PATHS[${PARENTS[$ID]}]}/${POLICIES[$ID]}" ; done
	fi

	if [ ${#PARENTS[@]} -gt 0 ] ; then
		debug ""
		debug "Parent Folders:"
		debug "[Folder ID - Parent Folder ID]"
		for ID in "${!PARENTS[@]}"; do debug "$ID - ${PARENTS[$ID]}" ; done
	fi

	if [ ${#CHILD_FOLDERS[@]} -gt 0 ] ; then
		debug ""
		debug "Child Folders:"
		debug "[Folder ID - List of Child Folder IDs]"
		for ID in "${!CHILD_FOLDERS[@]}"; do debug "$ID - ${CHILD_FOLDERS[$ID]}" ; done
	fi

	if [ ${#CHILD_SERVICES[@]} -gt 0 ] ; then
		debug ""
		debug "Child Services:"
		debug "[Folder ID - List of Child Service IDs]"
		for ID in "${!CHILD_SERVICES[@]}"; do debug "$ID - ${CHILD_SERVICES[$ID]}" ; done
	fi

	if [ ${#CHILD_POLICIES[@]} -gt 0 ] ; then
		debug ""
		debug "Child Policies:"
		debug "[Folder ID - List of Child Policy IDs]"
		for ID in "${!CHILD_POLICIES[@]}"; do debug "$ID - ${CHILD_POLICIES[$ID]}" ; done
	fi

	if [ "$DEPENDENCIES" == "true" ] ; then
		if [ ${#POLICIES_BY_GUID[@]} -gt 0 ] ; then
			debug ""
			debug "Policy GUIDs:"
			debug "[Policy GUID - Policy ID - Path to Policy]"
			for GUID in "${!POLICIES_BY_GUID[@]}"; do debug "$GUID - ${POLICIES_BY_GUID[$GUID]} - ${FOLDER_PATHS[${PARENTS[${POLICIES_BY_GUID[$GUID]}]}]}/${POLICIES[${POLICIES_BY_GUID[$GUID]}]}" ; done
		fi

		if [ ${#ENCAPSULATED_ASSERTIONS[@]} -gt 0 ] ; then
			debug ""
			debug "Encapsulated Assertions:"
			debug "[Encapsulated Assertion ID - Encapsulated Assertion Name]"
			for ID in "${!ENCAPSULATED_ASSERTIONS[@]}"; do debug "$ID - ${ENCAPSULATED_ASSERTIONS[$ID]}" ; done
		fi

		if [ ${#ENCAPSULATED_ASSERTIONS_BY_GUID[@]} -gt 0 ] ; then
			debug ""
			debug "Encapsulated Assertion GUIDs:"
			debug "[Encapsulated Assertion GUID - Encapsulated Assertion ID - Encapsulated Assertion Name]"
			for GUID in "${!ENCAPSULATED_ASSERTIONS_BY_GUID[@]}"; do debug "$GUID - ${ENCAPSULATED_ASSERTIONS_BY_GUID[$GUID]} - ${ENCAPSULATED_ASSERTIONS[${ENCAPSULATED_ASSERTIONS_BY_GUID[$GUID]}]}" ; done
		fi

		if [ ${#ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[@]} -gt 0 ] ; then
			debug ""
			debug "Encapsulated Assertion Associations:"
			debug "[Policy ID - Encapsulated Assertion ID - Encapsulated Assertion Name]"
			for ID in "${!ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[@]}"; do debug "$ID - ${ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[$ID]} - ${ENCAPSULATED_ASSERTIONS[${ENCAPSULATED_ASSERTIONS_BY_POLICY_ID[$ID]}]}" ; done
		fi

		if [ ${#CLUSTER_PROPERTIES[@]} -gt 0 ] ; then
			debug ""
			debug "Cluster Properties:"
			debug "[Cluster Property ID - Cluster Property Name]"
			for ID in "${!CLUSTER_PROPERTIES[@]}"; do debug "$ID - ${CLUSTER_PROPERTIES[$ID]}" ; done
		fi

		if [ ${#SSG_KEY_ENTRIES[@]} -gt 0 ] ; then
			debug ""
			debug "Private Keys:"
			debug "[Private Key ID - Private Key Name]"
			for ID in "${!SSG_KEY_ENTRIES[@]}"; do debug "$ID - ${SSG_KEY_ENTRIES[$ID]}" ; done
		fi

		if [ ${#SCHEDULED_TASKS[@]} -gt 0 ] ; then
			debug ""
			debug "Scheduled Tasks:"
			debug "[Scheduled Task ID - Scheduled Task Name]"
			for ID in "${!SCHEDULED_TASKS[@]}"; do debug "$ID - ${SCHEDULED_TASKS[$ID]}" ; done
		fi

		if [ ${#IDENTITY_PROVIDERS[@]} -gt 0 ] ; then
			debug ""
			debug "Identity Providers:"
			debug "[Identity Provider ID - Identity Provider Name]"
			for ID in "${!IDENTITY_PROVIDERS[@]}"; do debug "$ID - ${IDENTITY_PROVIDERS[$ID]}" ; done
		fi

		if [ ${#USERS[@]} -gt 0 ] ; then
			debug ""
			debug "Users:"
			debug "[User ID - Identity Provider ID:User Name]"
			for ID in "${!USERS[@]}"; do debug "$ID - ${USERS[$ID]}" ; done
		fi

		if [ ${#GROUPS[@]} -gt 0 ] ; then
			debug ""
			debug "Groups:"
			debug "[Group ID - Identity Provider ID:Group Name]"
			for ID in "${!GROUPS[@]}"; do debug "$ID - ${GROUPS[$ID]}" ; done
		fi
	fi
	debug ''
fi

log "=================================== Starting Analysis"
echo "Analysis of $BUNDLE:"
echo ""
echo "Statistics:"
echo "  Folders: ${#FOLDERS[@]}"
echo "  Services: ${#SERVICES[@]}"
echo "  Policies: ${#POLICIES[@]}"
echo "  Encapsulated Assertions: ${#ENCAPSULATED_ASSERTIONS[@]}"
echo "  Cluster Properties: ${#CLUSTER_PROPERTIES[@]}"
echo "  Private Keys: ${#SSG_KEY_ENTRIES[@]}"
echo "  Scheduled Tasks: ${#SCHEDULED_TASKS[@]}"
echo "  Identity Providers: ${#IDENTITY_PROVIDERS[@]}"
echo "  Users: ${#USERS[@]}"
echo "  Groups: ${#GROUPS[@]}"
echo ""
log "=================================== Displaying Items by Type"
echo "Items by Type:"
IFS=' '
for TYPE in "${!ITEM_LIST[@]}" ; do
	echo "  $TYPE:"
	IFS='|'
	for ID in ${ITEM_LIST[$TYPE]} ; do
		IFS=' '
		NAME=$(echo ${ITEMS[$ID]} | $XPATHBIN '/l7:Item/l7:Name/text()' 2>/dev/null)
		echo "    $ID : $NAME"
		IFS='|'
	done
	IFS=' '
done

# Dump the tree if we have any folders in the bundle
if [ ${#FOLDERS[@]} -ne 0 ] ; then
	echo ""
	log "=================================== Dumping Tree"
	echo "Tree:"
	IFS='|' ; getSubFolders $ROOTNODEID '' '0' ; IFS=' '
fi

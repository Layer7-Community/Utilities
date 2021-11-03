#!/bin/bash
#
# Run from cron to report on current MySQL connections
#
# Under normal operating conditions, assuming that the only application
# using the database is the Layer 7 API Gateway, the SECONDARY node should
# only see one ESTABLISHED connection to port 3306 (the replication thread)
# and the PRIMARY should see more than one connection (the replication thread
# plus all of the processing nodes).
#
# This script checks the count of connections and if it does not match the
# above criteria for this type of node then it generates a log entry (using
# logger) and optionally sends an alert via email.
#
# If notification emails will be sent, MAKE SURE NOTIFY_TO is set else pass
# in as an argument.
#
# Jay MacDonald - 20200319
#############################################################

################################
# Set some default values
TYPE="SECONDARY"	# Overwritten by -t
VERBOSE="false"		# Overwritten by -v
NOTIFY="no"		# Overwritten by -n
NOTIFY_TO="SET ME"	# Overwritten by -T (required if -n set)
NOTIFY_CC=''		# Overwritten by -C (optional if -n set)
NOTIFY_BCC=''		# Overwritten by -B (optional if -n set)

##################
# Define functions

print_help () {
	echo "$0 - Check MySQL connections for Layer 7 API Gateway"
	echo ''
	echo 'Command line parameters:'
	echo "  -t [PRIMARY|SECONDARY]  : Database node type (Default=$TYPE)"
	echo '  -v                      : Verbose output'
	echo '  -n                      : Send notification of error states'
	echo '  -T [email]              : To email address for notification'
	echo '  -C [email]              : Cc email address for notification'
	echo '  -B [email]              : Bcc email address for notification'
	echo '  -h                      : Print this list and exit'
	echo ''
	echo ' * Exit status 0 if success'
	echo ' * Exit status 1 if no MySQL connections found (very bad)'
	echo ' * Exit status 2 if PRIMARY is not active SSG database'
	echo ' * Exit status 3 if SECONDARY is active SSG database'
	echo ''
	echo 'Run from cron every minute to report on current MySQL connections'
	echo ''
	echo 'Under normal operating conditions, assuming that the only application'
	echo 'using the database is the Layer 7 API Gateway, the SECONDARY node should'
	echo 'only see one ESTABLISHED connection to port 3306 (the replication thread)'
	echo 'and the PRIMARY should see more than one connection (the replication thread'
	echo 'plus all of the processing nodes).'
	echo ''
	echo 'This script checks the count of connections and if it does not match the'
	echo 'above criteria for this type of node then it generates a log entry (using'
	echo 'logger) and optionally sends an alert via email.'
	echo ''
}

verbose() {
	if [ "$VERBOSE" == "true" ] ; then
		echo $2 $1
	fi
}

clean_up() {
	rm -f /tmp/mc*.$$
	if [ -n "$1" ] ; then
		exit $1
	else
		exit 0
	fi
}

# Parameters to notify are $1=subject, $2=message (optional if /tmp/mc_message.$$ not found)
notify() {
	if [ "$NOTIFY" == "yes" ] ; then
		if [ -n "$1" ] ; then
			SUBJECT="$1"
		else
			SUBJECT="Alert from Layer 7 API Gateway MySQL connection monitor script"
		fi

		echo "From: ${USER}@${HOSTNAME}" > /tmp/mc_notify.$$
		echo "To: $NOTIFY_TO" >> /tmp/mc_notify.$$
		if [ -n "$NOTIFY_CC" ] ; then
			echo "Cc: $NOTIFY_CC" >> /tmp/mc_notify.$$
		fi
		if [ -n "$NOTIFY_BCC" ] ; then
                        echo "Bcc: $NOTIFY_BCC" >> /tmp/mc_notify.$$
		fi
		echo "Subject: $SUBJECT" >> /tmp/mc_notify.$$
		echo "" >> /tmp/mc_notify.$$

		if [ -f /tmp/mc_message.$$ ] ; then
			# Use /tmp/mc_message.$$ for body
			cat /tmp/mc_message.$$ >> /tmp/mc_notify.$$
		elif [ -n "$2" ] ; then
			# Used passed message for body
			echo "$2" >> /tmp/mc_notify.$$
		else
			# Repeat subject as body
			echo "$1" >> /tmp/mc_notify.$$
		fi

		verbose "=> Sending notification by email"

		cat /tmp/mc_notify.$$ | /usr/sbin/sendmail -t 2>/dev/nul
        fi
}

################################################### Start main work


##############################################################
# Parse the command line options (override defaults set above)
OPTS="t:nT:C:B:vh"

while getopts $OPTS opt ; do
        case $opt in
           t)   TYPE=$OPTARG;;

           n)   NOTIFY='yes';;

           T)   NOTIFY_TO=$OPTARG;;

           C)   NOTIFY_CC=$OPTARG;;

           B)   NOTIFY_BCC=$OPTARG;;

           v)   VERBOSE='true';;

           h)   print_help
                exit 0;;

           ?)   exit 1;;
        esac
done

verbose "$0 - Check MySQL connections for Layer 7 API Gateway"
verbose ""

##############################################################
# Confirm $TYPE is valid

if [ "$TYPE" != "PRIMARY" -a "$TYPE" != "SECONDARY" ] ; then
	echo "Error: Invalid node type declared \($TYPE\)"
	clean_up 1
fi

##############################################################
# Get the count of MySQL connections
verbose '=> Gathering mysql connection details:' -n
COUNT=$(netstat -tnp | grep ':3306' | grep ESTABLISHED | grep mysql | wc -l)
IFS='' verbose " OK"

if [ $COUNT -eq 0 ] ; then
	# If either node has no connections then this is bad
	verbose '==> WARNING: No MySQL connections found'
	logger -t mysql_connections "WARNING: No MySQL connections found"
	notify "Layer 7 API Gateway WARNING: No MySQL connections found" "WARNING: No MySQL connections found on $HOST"
	clean_up 1
fi

if [ $COUNT -eq 1 ] ; then
	verbose "=> $COUNT MySQL connection found"
	if [ "$TYPE" == "PRIMARY" ] ; then
		# If PRIMARY node only has one connection then it is not active for SSG, which is atypical
		verbose "==> WARNING: PRIMARY node is not active SSG node"
		logger -t mysql_connections "WARNING: PRIMARY node is not active SSG node"
		netstat -tnp | head -2 > /tmp/mc_message.$$
		netstat -tnp | grep ':3306' | grep ESTABLISHED | grep mysql >> /tmp/mc_message.$$
		notify "Layer 7 API Gateway WARNING: PRIMARY node is not active SSG node"
		clean_up 2
	else
		# If SECONDARY node only has one connection then it is not active for SSG, which is normal
		verbose "==> SECONDARY node is not active node. This is good."
		logger -t mysql_connections "INFO: SECONDARY node is not the active node. This is good."
		clean_up 0
	fi
fi

if [ $COUNT -gt 1 ] ; then
	verbose "=> $COUNT MySQL connections found"
	if [ "$TYPE" == "SECONDARY" ] ; then
		# If SECONDARY node has more than one connection then it is active for SSG, which is atypical
		verbose "==> WARNING: SECONDARY node is active SSG node"
		logger -t mysql_connections "WARNING: SECONDARY node is active SSG node"
		netstat -tnp | head -2 > /tmp/mc_message.$$
		netstat -tnp | grep ':3306' | grep ESTABLISHED | grep mysql >> /tmp/mc_message.$$
		notify "Layer 7 API Gateway WARNING: SECONDARY node is active SSG node"
		clean_up 3
	else
		# If PRIMARY node has more than one connection then it is active for SSG, which is normal
		verbose "==> PRIMARY node is active node. This is good."
		logger -t mysql_connections "INFO: PRIMARY node is active node. This is good."
		clean_up 0
	fi
fi

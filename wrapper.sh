#!/bin/sh

echo "Start running wrapper script"
set -e
set -x

TRIGGER_BACKUP="0"

readTrigger() {
	local maxTriggerDelaySeconds="10"
	local triggerTimestamp="$(cat /usr/local/tomcat/repository/trigger-backup)"
	local maxTriggerTimestamp="$(($triggerTimestamp+$maxTriggerDelaySeconds))"
	local curTimestamp="$(date +%s)"
	if [ "$curTimestamp" -le "$maxTriggerTimestamp" ] ; then
		TRIGGER_BACKUP="1"
	fi
}

if [ -f "/usr/local/tomcat/repository/trigger-backup" ] ; then
	#readTrigger()
	TRIGGER_BACKUP="1"
	rm -f /usr/local/tomcat/repository/trigger-backup
fi

# TODO parameterize
/wait-for-it.sh localhost:3306

waitForHealthcheck() {
	# TODO parameterize
	bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' -H "Host: localhost" --max-time 10 localhost:8080/site/pl)" != "200" ]]; do sleep 10; done'
}

runSqlQuery() {
	# TODO parameterize
	mysql --protocol=tcp --host=localhost --port=3306 -u hippo_test -p"$HIPPO_CONTENTSTORE_PASSWORD" "$@"
}

takeBackupAfterAtLeast() {
	local sleepDuration="$1"
	sleep "$sleepDuration"

	# make sure we get a complete backup
	waitForHealthcheck

	local curTimestamp="$(date +%s)"
	# TODO parameterize
	printf '%s' "$curTimestamp" > /usr/local/tomcat/repository/trigger-backup
	kill 1
}

executeBackup() {
	echo "Starting backup"
	local repositoryRevision="$(runSqlQuery hippo -e "select REVISION_ID from REPOSITORY_LOCAL_REVISIONS where JOURNAL_ID='root-$(hostname)'" -s -N)"
	local curTimestamp="$(date +%s)"
	rm -f /usr/local/tomcat/repository.tar.gz
	(cd /usr/local/tomcat && tar czf repository.tar.gz repository)
	gsutil cp /usr/local/tomcat/repository.tar.gz "gs://int-ecom-1012-junior-staging-repository-backups/${repositoryRevision}-${curTimestamp}.tar.gz"
	echo "Backup done"
}

if [ "$TRIGGER_BACKUP" = "1" ] ; then
	executeBackup
else
	takeBackupAfterAtLeast "1h" &
fi

set +x
set +e

echo "Finished running wrapper script"

exec "$@"

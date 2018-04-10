#!/bin/sh

echo "Start running wrapper script"
set -e
set -x

runSqlQuery() {
	# TODO parameterize
	mysql --protocol=tcp --host=localhost --port=3306 -u hippo_test -p"$HIPPO_CONTENTSTORE_PASSWORD" "$@"
}

getJournalId() {
	echo "root-$(hostname)"
}

getLocalRepositoryRevision() {
	runSqlQuery hippo -e "select REVISION_ID from REPOSITORY_LOCAL_REVISIONS where JOURNAL_ID='$(getJournalId)'" -s -N
}

updateLocalRepositoryRevision() {
	local revisionId="$1"
	runSqlQuery hippo -e "insert into REPOSITORY_LOCAL_REVISIONS (JOURNAL_ID, REVISION_ID) values ('$(getJournalId)', '$revisionId')"
}

restoreFromBackup() {
	# todo find newest backup or skip
	# todo extract repository revision from filename
	local backupTgzGsPath="gs://int-ecom-1012-junior-staging-repository-backups/21688296-1523370560.tar.gz"
	local backupRepoRevision="21688296"
	echo "Restoring local repository from backup with revision $backupRepoRevision"

	gsutil cp "$backupTgzGsPath" /usr/local/tomcat/backup.tar.gz
	(cd /usr/local/tomcat && tar xvzf backup.tar.gz)
	rm -f /usr/local/tomcat/backup.tar.gz
	updateLocalRepositoryRevision "21688296"

	echo "Done restoring local repository from backup"
}

restoreIfNecessary() {
	local curRevision="$(getLocalRepositoryRevision)"
	if [ "$curRevision" = "" ] ; then
		restoreFromBackup
	fi
}

restoreIfNecessary

set +x
set +e

echo "Finished running wrapper script"

exec "$@"

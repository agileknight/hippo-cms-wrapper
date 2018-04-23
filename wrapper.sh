#!/bin/sh

echo "Start running wrapper script"

set -e
# TODO remove later
set -x

requestImport() {
	touch /control/REQUEST_IMPORT
}

waitForImportComplete() {
	while [ ! -f /control/IMPORT_COMPLETE ]; do
		sleep 5
	done
	echo "Import complete"
}

requestImportIfNecessary() {
	if [ -z "$(ls -A /usr/local/tomcat/repository)" ]; then
		echo "Requesting import of lucene index"
		requestImport
	fi
}

waitForImportIfNecessary() {
	if [ -f /control/REQUEST_IMPORT ]; then
		waitForImportComplete
	fi
}

requestImportIfNecessary
waitForImportIfNecessary
rm -f rm /control/IMPORT_COMPLETE

set +e

echo "Finished running wrapper script"

exec "$@"

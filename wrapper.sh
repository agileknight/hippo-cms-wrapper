#!/bin/sh

echo "Start running wrapper script"

set -e

requestImport() {
    echo "Requesting import of lucene index"
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
        requestImport
    fi
}

finishImportIfNecessary() {
    if [ -f /control/REQUEST_IMPORT ]; then
        waitForImportComplete
    fi
    rm -f /control/IMPORT_COMPLETE
}

executeGracefulRestart() {
    echo "Triggering graceul restart"
    # main process in docker always has pid 1
    # send SIGTERM for graceul shutdown
    # should trigger restart of container, depends on restart policy always
    kill 1
}

waitForShutdownRequest() {
    while [ ! -f /control/REQUEST_SHUTDOWN ]; do
        sleep 5
    done
    executeGracefulRestart
}

requestExport() {
    echo "Requesting export of lucene index"
    mv /control/REQUEST_SHUTDOWN /control/REQUEST_EXPORT
}

requestExportIfNecessary() {
    if [ -f /control/REQUEST_SHUTDOWN ]; then
        requestExport
    fi
}

waitForExportComplete() {
    while [ ! -f /control/EXPORT_COMPLETE ]; do
        sleep 5
    done
    echo "Export complete"
}

finishExportIfNecessary() {
    if [ -f /control/REQUEST_EXPORT ]; then
        waitForExportComplete
    fi
    rm -f /control/EXPORT_COMPLETE
}

requestImportIfNecessary

# make sure we finish running import even in case of a restart
finishImportIfNecessary

# this happens after shutdown-triggered restart before service is started again
# export needs to happen with service stopped to prevent open file handlers and inconsistent state
requestExportIfNecessary

finishExportIfNecessary

waitForShutdownRequest &

set +e

echo "Finished running wrapper script"

exec "$@"

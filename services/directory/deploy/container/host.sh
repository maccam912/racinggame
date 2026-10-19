#!/bin/sh
# Tini remains PID 1 and reaps orphaned workers. This wrapper restarts only the
# directory child; a planned stop forwards repeated signals through its drain.
set -u
operator=${PR_DIRECTORY_BINARY:-/opt/pacific-rush/pacific-directory}
pid_file=${PR_HOST_PID_FILE:-/tmp/pacific-directory.pid}
if [ "${1:-}" != serve ]; then
    exec "$operator" "$@"
fi
stopping=0
child=''
forward_stop() {
    stopping=1
    if [ -n "$child" ]; then
        kill -TERM "$child" 2>/dev/null || true
    fi
}
trap forward_stop TERM INT
while [ "$stopping" -eq 0 ]; do
    "$operator" "$@" &
    child=$!
    printf '%s\n' "$child" > "$pid_file"
    status=0
    # A trap interrupts wait while the service is still draining. Wait again;
    # exiting the wrapper early would end the container's worker namespace.
    while :; do
        wait "$child" || status=$?
        if ! kill -0 "$child" 2>/dev/null; then break; fi
    done
    child=''
    rm -f "$pid_file"
    if [ "$stopping" -ne 0 ]; then break; fi
    printf '{"code":"directory_restarting","exit_code":%s}\n' "$status"
    sleep 1 &
    sleeper=$!
    wait "$sleeper" || true
done
exit 0

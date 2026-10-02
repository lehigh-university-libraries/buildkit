#!/command/with-contenv bash
# shellcheck shell=bash

# Invoked indirectly by the SIGTERM trap below.
# shellcheck disable=SC2317,SC2329
on_terminate() {
    echo "Termination signal received. Exiting..."
    exit 0
}
trap 'on_terminate' SIGTERM

sleep 60

# The kotlin check should be stopping this container
exit 1

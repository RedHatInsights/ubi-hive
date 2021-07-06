#!/bin/bash

set -e

# add UID to /etc/passwd if missing
if ! whoami &> /dev/null; then
    if test -w /etc/passwd || stat -c "%a" /etc/passwd | grep -qE '.[267].'; then
        echo "Adding user ${USER_NAME:-hadoop} with current UID $(id -u) to /etc/passwd"
        # Remove existing entry with user first.
        # cannot use sed -i because we do not have permission to write new
        # files into /etc
        sed  "/${USER_NAME:-hadoop}:x/d" /etc/passwd > /tmp/passwd
        # add our user with our current user ID into passwd
        echo "${USER_NAME:-hadoop}:x:$(id -u):0:${USER_NAME:-hadoop} user:${HOME}:/sbin/nologin" >> /tmp/passwd
        # overwrite existing contents with new contents (cannot replace the
        # file due to permissions)
        cat /tmp/passwd > /etc/passwd
        rm /tmp/passwd
    fi
fi

exec $@

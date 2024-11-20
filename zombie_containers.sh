#!/bin/bash

ppids=$(ps -eo ppid,stat | awk '$2 ~ /^Z/ {print $1}' | sort | uniq)

for ppid in $ppids; do
    for container in $(docker ps -q); do
        if docker top "$container" -eo pid | grep -qw "$ppid"; then
            container_name=$(docker inspect --format '{{.Name}}' "$container" | sed 's/^.\{1\}//')
            echo "PPID $ppid is in container $container ($container_name)"
        fi
    done
done

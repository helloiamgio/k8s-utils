#!/bin/bash

echo "Top 10 processi per uso memoria e container associati:"
echo "------------------------------------------------------"

ps -eo pid,%mem,comm --sort=-%mem | head -n 11 | tail -n 10 | while read -r pid mem proc; do
  container_id=$(cat /proc/$pid/cgroup 2>/dev/null | grep "docker" | awk -F'/' '{print $3}' | head -n 1)
  if [ -n "$container_id" ]; then
    container_name=$(docker ps --no-trunc --format "{{.ID}} {{.Names}}" | grep "^$container_id" | awk '{print $2}')
  else
    container_name="N/A (non in un container)"
  fi
  printf "PID: %-8s Mem: %-5s%% Proc: %-20s Container: %s\n" "$pid" "$mem" "$proc" "$container_name"
done

echo
echo "Top 10 processi per uso CPU e container associati:"
echo "-------------------------------------------------"

ps -eo pid,%cpu,comm --sort=-%cpu | head -n 11 | tail -n 10 | while read -r pid cpu proc; do
  container_id=$(cat /proc/$pid/cgroup 2>/dev/null | grep "docker" | awk -F'/' '{print $3}' | head -n 1)
  if [ -n "$container_id" ]; then
    container_name=$(docker ps --no-trunc --format "{{.ID}} {{.Names}}" | grep "^$container_id" | awk '{print $2}')
  else
    container_name="N/A (non in un container)"
  fi
  printf "PID: %-8s CPU: %-5s%% Proc: %-20s Container: %s\n" "$pid" "$cpu" "$proc" "$container_name"
done

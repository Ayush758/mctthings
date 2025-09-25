#!/bin/bash

# Define the network range
NETWORK="192.168.100"

# Loop through IPs from 1 to 254
for i in {1..254}; do
  IP="$NETWORK.$i"

  # Ping the IP with 1 packet and 1-second timeout
  if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
    # Print active IP in green
    echo -e "\e[32m$IP is active\e[0m"
  else
    # Print inactive IP in default color
    echo "$IP is inactive"
  fi
done

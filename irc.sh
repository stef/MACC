#!/bin/bash

IRC_HOST="$(cat irc_server)"
IRC_PORT="$(cat irc_port)"
IRC_NICK=$(apg -q -a1 -n 1 -m 6 -M CL)
IRC_CHAN="$(cat chan)
IRC_CONNECTIONS="connections"

mkdir -p "$IRC_CONNECTIONS"

while true
do
  (sleep 34; echo "/j $IRC_CHAN" >> "$IRC_CONNECTIONS/$IRC_HOST/in") &
  ii \
    -i "$IRC_CONNECTIONS" \
    -s "$IRC_HOST" \
    -p "$IRC_PORT" \
    -n "$IRC_NICK" \
    -f "$IRC_NICK"
done

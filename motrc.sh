#!/usr/bin/ksh

# depends on apg, seccure

alias enc='seccure-encrypt -q -c p521 -m 256'
alias dec='seccure-decrypt -q -c p521 -m 256'
alias key='seccure-key -q -c p521'
alias dh='seccure-dh -q -c p521'

PUBF="pub"
KEYF="key"
MULTIPLEXER="server"

socket=$(mktemp)

if [[ ! -r $KEYF ]]; then
    echo "[!] no keys found, generating new" >&2
    apg -q -a1 -m 90 -n 1 >"$PUBF"
    key -F "$PUBF" >"$KEYF"
fi

PUB=$(cat "$PUBF")
KEY=$(cat "$KEYF")

echo "agent:$socket" >>"$MULTIPLEXER"/in

function agent {
    [[ "x$1" == "x$socket" ]] && return
    echo "found peer $1"
    dh 2>&1 |&
    read -p p
    while [[ "$p" == "WARNING: Cannot obtain memory lock: Cannot allocate memory." ]]; do
        # skip warning
        read -p p
    done
    echo "dh:$socket:$p" >>"$1"
    tail -fn0 "$socket" | while read line; do
        echo "$line" | grep -qs "dh2:$1:" &&  {
            resp=$(echo "${line}" | cut -d':' -f3-)
            print -p "$resp"
            break
        }
    done
    read -p skey
    read -p vkey
    print "$skey\n$vkey\n\n"
}

function dhreply {
    [[ ! "x$1" =~ 'x[^:]*:.*' ]] || return
    peer=$(echo "$1" | cut -d":" -f1)
    echo "dh request from $peer"
    p=$(echo "${1}" | cut -d':' -f2-)
    dh 2>&1 |&
    read -p p2
    while [[ "$p2" == "WARNING: Cannot obtain memory lock: Cannot allocate memory." ]]; do
        # skip warning
        read -p p2
    done
    print -p "$p"
    sleep 1
    echo "dh2:$socket:$p2" >>"$peer"
    read -p skey
    read -p vkey
    print "$skey\n$vkey\n\n"
}

tail -q --pid=$$ -fn0 "$MULTIPLEXER"/out -fn0 "$socket" | while read line; do
    case "$line" in
        agent:*) agent "${line#agent:}" ; continue;;
        dh:*) dhreply "${line#dh:}" ; continue;;
    esac
done

rm "$socket"

#!/usr/bin/ksh

# depends on apg, seccure

alias enc='seccure-encrypt -q -c p521 -m 256'
alias dec='seccure-decrypt -q -c p521 -m 256'
alias sign='seccure-sign -q -c p521'
alias verify='seccure-verify -c p521'
alias key='seccure-key -q -c p521'
alias dh='seccure-dh -q -c p521'

PUBF="pub"
KEYF="key"
MULTIPLEXER="server"
VOLATILE="volatile"

socket=$(mktemp)

if [[ ! -r $KEYF ]]; then
    echo "[!] no keys found, generating new" >&2
    apg -q -a1 -m 90 -n 1 >"$KEYF"
    key -F "$KEYF" >"$PUBF" 2>/dev/null
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
    print "$skey\n$vkey" >"${VOLATILE}/${1##*/}"
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
    echo "dh2:$socket:$p2" >>"$peer"
    read -p skey
    read -p vkey
    print "$skey\n$vkey" >"${VOLATILE}/${peer##*/}"
    auth_reply "$peer" "$vkey" "auth"
}

function auth {
    peer=$(echo "$1" | cut -d":" -f1)
    auth=$(echo "$1" | cut -d":" -f2- | sed 's/\(.\{64\}\)/\1\n/g' | openssl enc -aes-256-cfb -d -a -kfile "${VOLATILE}/${peer##*/}")
    vkey_other=$(echo "$auth" | head -1)
    while read name key; do
        vkey=$(tail -1 "${VOLATILE}/${peer##*/}")
        [[ "x$vkey" == "x$vkey_other" ]] && echo -n "$auth" | verify -a "$key" 2>&1 | fgrep -qs "Signature successfully verified!" && {
            echo "accepted connection from $name"
            # TODO: check this if this can be spoofed, and the verification key leaked, consequences?
            [[ -z "$2" ]] && auth_reply "$peer" "$vkey" "auth2"
            break
        }
    done <"${VOLATILE}/peers"
}

# params: peer, vkey, cmd
function auth_reply {
    auth=$(echo "$2" | sign -F "$KEYF" -a 2>&1 | fgrep -v "WARNING: Cannot obtain memory lock: Cannot allocate memory.")
    printf "$3:$socket:" >>"$1"; echo "$auth" | openssl enc -aes-256-cfb -e -a -kfile "${VOLATILE}/${1##*/}" | tr -d '\n' >>"$1"
    echo  >>"$1"
}

#function send {
#    printf "msg:$1:" >>"$1"; echo "$2" | openssl enc -aes-256-cfb -e -a -kfile "${VOLATILE}/${1##*/}" | tr -d '\n' >>"$1"
#    echo >>"$1"
#}

function msg {
    peer=$(echo "$1" | cut -d":" -f1)
    echo "${1}" | cut -d':' -f2- | sed 's/\(.\{64\}\)/\1\n/g' | openssl enc -aes-256-cfb -d -a -kfile "${VOLATILE}/${peer##*/}"
}

tail -q --pid=$$ -fn0 "$MULTIPLEXER"/out -fn0 "$socket" | while read line; do
    case "$line" in
        agent:*) agent "${line#agent:}" ; continue;;
        dh:*) dhreply "${line#dh:}" ; continue;;
        dh2:*) continue;;
        auth:*) auth "${line#auth:}"; continue;;
        auth2:*) auth "${line#auth2:}" "final"; continue;;
        msg:*) msg "${line#msg:}"; continue;;
        *) echo "${line}";;
    esac
done

rm "$socket"

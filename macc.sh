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
MULTIPLEXER="${1:-server}"
VOLATILE="volatile"

# initiates a session setup with a new agent
function agent {
    [[ "x$1" == "x$socket" ]] && return
    printf "%s -!- %s found\n" "$(date '+%H:%M')" "$1"
    dh 2>&1 |&
    read -p p
    while [[ "$p" == "WARNING: Cannot obtain memory lock: Cannot allocate memory." ]]; do
        # skip warning
        read -p p
    done
    sendto "$1" "dh:$socket:$p"
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

# handle replies to DH key exchanges
function dhreply {
    [[ ! "x$1" =~ 'x[^:]*:.*' ]] || return
    peer=$(echo "$1" | cut -d":" -f1)
    printf "%s -!- %s dh request\n" "$(date '+%H:%M')" "$peer"
    p=$(echo "${1}" | cut -d':' -f2-)
    dh 2>&1 |&
    read -p p2
    while [[ "$p2" == "WARNING: Cannot obtain memory lock: Cannot allocate memory." ]]; do
        # skip warning
        read -p p2
    done
    print -p "$p"
    read -p skey
    read -p vkey
    print "$skey\n$vkey" >"${VOLATILE}/${peer##*/}"
    sendto "$peer" "dh2:$socket:$p2"
    sleep 0.2
    auth_reply "$peer" "$vkey" "auth"
}

# authenticate peer, initiated by joining agent after successful DH shared secret setup
function auth {
    peer=$(echo "$1" | cut -d":" -f1)
    auth=$(echo "$1" | cut -d":" -f2- | sed 's/\(.\{64\}\)/\1\n/g' | openssl enc -aes-256-cfb -d -a -kfile "${VOLATILE}/${peer##*/}")
    vkey_other=$(echo "$auth" | head -1)
    while read name key; do
        vkey=$(tail -1 "${VOLATILE}/${peer##*/}")
        [[ "x$vkey" == "x$vkey_other" ]] && echo -n "$auth" | verify -a "$key" 2>&1 | fgrep -qs "Signature successfully verified!" && {
            echo "$VOLATILE/${peer##*/}" >>"$VOLATILE/session"
            echo "$name" >"$VOLATILE/${peer##*/}.name"
            printf "%s -!- %10-s joined\n" "$(date '+%H:%M')" "$name"
            # TODO: check this if this can be spoofed, and the verification key leaked, consequences?
            [[ -z "$2" ]] && auth_reply "$peer" "$vkey" "auth2"
            break
        }
    done <peers
}

# send signed verification key from DH exchange, authenticating the peers.
# params: peer, vkey, cmd
function auth_reply {
    auth=$(echo "$2" | sign -F "$KEYF" -a 2>&1 | fgrep -v "WARNING: Cannot obtain memory lock: Cannot allocate memory.")
    sendto "$1" "$(printf "$3:$socket:"; echo "$auth" | openssl enc -aes-256-cfb -e -a -kfile "${VOLATILE}/${1##*/}" | tr -d '\n'; echo)"
}

# create a unique key, encrypt this seperately with all the shared secrets from this session,
# encrypt the data using the unique key and send this to the broadcast channel
function send {
    mkey=$(mktemp "$VOLATILE/key.XXXXXX")
    apg -q -a1 -m 90 -n 1 >"$mkey"
    data=$(echo "msg:$socket:$1" | openssl enc -aes-256-cfb -e -a -kfile "$mkey" | tr -d '\n')
    keybag=""
    sort "$VOLATILE/session" | uniq | while read peer; do
        keybag="$keybag $(cat "$mkey" | openssl enc -aes-256-cfb -e -a -kfile "${VOLATILE}/${peer##*/}" | tr -d '\n')"
    done
    rm "$mkey"
    echo "msg:$data:$keybag" >>"$MULTIPLEXER"/in
}

function peername {
    cat "$VOLATILE/${1##*/}.name"
}

# receive an encrypted message
# try to decrypt using the shared secret with the sender on all encrypted keys
# try to decrypt the message with the decrypted keys, if starts with msg: display the rest"
function msg {
    data=$(echo "$1" | cut -d":" -f1)
    keys=$(echo "$1" | cut -d":" -f2-)
    mkey=$(mktemp "$VOLATILE/key.XXXXXX")
    ready=false
    sort  "$VOLATILE/session" | uniq | while read pkey; do
        for key in $keys; do
            echo "$key" | sed 's/\(.\{64\}\)/\1\n/g' | openssl enc -aes-256-cfb -d -a -kfile "$pkey" >"$mkey"
            clr="$(echo "$data" | sed 's/\(.\{64\}\)/\1\n/g' | openssl enc -aes-256-cfb -d -a -kfile "$mkey")"
            [[ "msg:" == "$(echo "$clr" | cut -c1-4)" ]] && {
                peer=$(echo "${clr}" | cut -d':' -f2)
                [[ "x$peer" == "x${socket}" ]] || {
                    msg=$(echo "${clr}" | cut -d':' -f3-)
                    printf "%s <%10-s> %s\n" "$(date '+%H:%M')" "$(peername $peer)" "$msg"
                }
                ready=true
                break
            }
        done
        $ready && break
    done
}

function leave {
    [[ "x$1" == "x$socket" ]] && return
    tmp=$(mktemp)
    sort  "$VOLATILE/session" | uniq | fgrep -v "${VOLATILE}/${1##*/}" >"$tmp" && mv "$tmp" "$VOLATILE/session"
    printf "%s -!- %10-s left\n"  "$(date '+%H:%M')" "$(peername $1)"
}

function sendto {
    echo "$2" >>"$1"
}

# clean up bg processes and volatile data
function cleanup {
    echo "leave:$socket" >>"$MULTIPLEXER"/in
    rm "$socket" "${VOLATILE}"/tmp.* "${VOLATILE}"/key.* "$VOLATILE"/session 2>>/dev/null
    kill $groupdesc $sockdesc #$userdesc
    exit 2
}
trap "cleanup" INT PIPE

# dispatch messages in group channel for broadcast
function group_dispatcher {
    tail -q --pid=$$ -fn0 "$MULTIPLEXER"/out | while read line; do
        case "$line" in
            agent:*) agent "${line#agent:}" ; continue;;
            leave:*) leave "${line#leave:}" ; continue;;
            msg:*) msg "${line#msg:}"; continue;;
            *) echo "${line}";;
        esac
    done
}

# dispatcher for private socket for p2p connections
function sock_dispatcher {
    tail -q --pid=$$ -fn0 "$socket" | while read line; do
        case "$line" in
            dh:*) dhreply "${line#dh:}" ; continue;;
            dh2:*) continue;;
            auth:*) auth "${line#auth:}"; continue;;
            auth2:*) auth "${line#auth2:}" "final"; continue;;
            *) echo "unknown message ${line}";;
        esac
    done
}

socket=$(mktemp)

# generate static private/pub key pair
if [[ ! -r $KEYF ]]; then
    echo "[!] no keys found, generating new" >&2
    apg -q -a1 -m 90 -n 1 >"$KEYF"
    key -F "$KEYF" >"$PUBF" 2>/dev/null
fi

PUB=$(cat "$PUBF")
KEY=$(cat "$KEYF")

[[ ! -d "$VOLATILE" ]] && mkdir "$VOLATILE"

# announce intent to join on broadcast channel
echo "agent:$socket" >>"$MULTIPLEXER"/in

group_dispatcher &
groupdesc=$!
sock_dispatcher &
sockdesc=$!

# wait for user input
while read line; do
    send "$line"
done


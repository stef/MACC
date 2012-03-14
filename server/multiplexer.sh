#!/usr/bin/ksh

[[ ! -p "in" ]] && {
    rm in
    mknod in p
}
while true; do
    cat in | tee -a out
done

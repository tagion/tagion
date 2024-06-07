#!/bin/bash

ROOT=.

for j in $(seq 1 4); do
    echo "------- ROUND $j"
    tmpr=$(mktemp).hibon
    for i in $(seq 1 2); do
        echo "-- WALLET $i"
        tmpf=$(mktemp).hibon
        $ROOT/bin/geldbeutel ./wallets/wallet$i.json -x 000$i --trt-read --output $tmpf
        echo "-- TRT READ REQ:"
        for k in $(seq 1 50); do
            echo -n "."
            tmpo=$(mktemp).hibon
            tmph=$(mktemp).hibon
            cat $tmpf  \
                | curl \
                    -X POST -s \
                    -H "Content-Type: application/octet-stream" \
                    --data-binary @-  \
                    -o $tmpo \
                    http://localhost:8080/api/v1/dart && \
            if [[ $k > 1 ]]; then
                diff -s $tmpr $tmpo |grep -q identical || ( echo && echo "[$k] TRT read result for wallet $i has changed" )
            fi    
            rm -f $tmpr
            tmpr=$tmpo
            sleep 0.1
        done
        echo ""
        echo "-- REPEATED $k times"
        rm -f $tmpf
    done
    rm -f $tmpr
    echo "-- MAKE PAYMENT"
    tmpi=$(mktemp)
    $ROOT/bin/wallet $ROOT/wallets/wallet1.json -x 0001 --create-invoice TEST:32 --output $tmpi
    $ROOT/bin/wallet $ROOT/wallets/wallet2.json -x 0002 --pay $tmpi --send
    echo "Wailting 12 sec..."
    sleep 12
    echo "Go!"
    rm -f $tmpi
done

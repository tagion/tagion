#!/bin/bash

set -e


function _log(){
    echo "$(date +%FT%T) - ${1} ${2} ${3} ${4} ${5} ${6} ${7} ${8}"
}


#-------------------------------------------- define

export GODEBUG=cgocheck=0
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

WD=$( dirname -- "$( readlink -f -- "$0"; )"; )
TNAME="test-$(date +%Y%m%d%H%M)"

if [ -z $TB_TESTROOT ]
then
    _log "ERROR: TB_TESTROOT should be set"
    exit -1
fi    

TB_TESTROOT=$(realpath $TB_TESTROOT)

if [ -z $TB_TESTDIR ]
then
    _log "ERROR: TB_TESTDIR should be set"
    exit -1
fi

if [ -z $TB_ARTIFACT ]
then
    _log "ERROR: TB_ARTIFACT should be set"
    exit -1
fi    

if [ -z $TB_LOGDIR ]
then
    TB_LOGDIR=$TB_TESTROOT
fi

TB_LOGDIR=$(realpath $TB_LOGDIR)

TB_PID=

TDIR="$TB_TESTROOT/$TB_TESTDIR"



#-------------------------------------------- lib

function _cleares(){
    vars=$( set |awk '$1 ~ /^TB_RES_/ { sub(/=.*$/,"=",$1); print $1}' )
    eval $vars
}

function prepareenv(){
    _WD=$(pwd)
    _log "Creating test dir: $TDIR"
    mkdir -p $TB_LOGDIR
    mkdir -p $TDIR/tmp
    mkdir -p $TDIR/wallet
    mkdir -p $TDIR/data/node0
    _log "Fetching tagion"
    cp $TB_ARTIFACT $TDIR                #--- TODO: download artifact here
    chmod 755 $TDIR/tagion
    cd $TDIR
    ln -s tagion tagionwave
    ln -s tagion tagionwallet
    ln -s tagion dartutil
    ln -s tagion tagionboot
    ./dartutil --initialize --dartfilename data/node0/dart.drt
    cd wallet
    ../tagionwallet --generate-wallet --questions q1,q2,q3,q4 --answers a1,a2,a3,a4 -x 0001
    _log "Creating environment with wallet: 25x4000 coins"
    for((i=0;i<25;i++))
    do
        ../tagionwallet --create-invoice GENESIS:4000 --invoice ../tmp/ginvoice.hibon -x 0001
        ../tagionboot ../tmp/ginvoice.hibon -o ../tmp/gcoin.hibon > /dev/null 2>&1
        ../dartutil --dartfilename ../data/node0/dart.drt --modify --inputfile ../tmp/gcoin.hibon
        if (( $(expr $i % 5) == 0 ))
        then
            _log "... ${i}"
        fi
    done
    cd $_WD
    _log "Environment done"
}

function runtagion(){
    _WD=$(pwd)
    cd $TDIR
    ./tagionwave \
        --dart-init=false \
        --dart-synchronize=true \
        -N 5 \
        > $TDIR/tmp/error.log 2>&1 &
    TB_PID=$!        
    cd $_WD
}

function test_health() {
    _WD=$(pwd)
    cd $TDIR/wallet
    vars=$( ( /bin/time --quiet -f "etime: %e" \
    /usr/bin/timeout --preserve-status -v -k 4s 4s \
    ../tagionwallet \
        -p $1 \
        --health 2>&1 ) \
    | awk '{
        if($1 ~ /timeout/){
            print "TB_RES_OUT=TIMEOUT";
            exit 0;
        }
        if($1 == "etime:")
            print "TB_RES_ETIME="$2;
        if($0 ~ /Exception/){
            print "TB_RES_OUT=ERROR"
            str = $0;
            gsub(/["\$\\]/,"\\\\&",str)
            print "TB_RES_ERROR=\""str"\""
            exit 0;
        }    
        if(NR == 1)
            if($1 ~ /HEALTHCHECK/)
                print "TB_RES_SMOKE=OK";
            else
                print "TB_RES_SMOKE=FAIL";
        if(NR == 2)
            if($0 ~ /refused/)
                print "TB_RES_SOCKET=FAIL";
            else
                print "TB_RES_SOCKET=OK";
        if(NR == 4)
            if($0 ~ /Healthcheck/){
                print "TB_RES_OUT=OK";
                str = $0;
                gsub(/["\$\\]/,"\\\\&",str)
                print "TB_RES_JSON=\""str"\"";
            }else if($0 == "{}")
                print "TB_RES_OUT=EMPTY"
    }' )   
    eval $vars
    cd $_WD
    return 0
}

function test_wallet_amount() {
    _WD=$(pwd)
    cd $TDIR/wallet
    vars=$( ( /bin/time --quiet -f "etime: %e" \
    /usr/bin/timeout --preserve-status -v -k 4s 4s \
    ../tagionwallet \
        -p $1 \
        -x 0001 \
        --update \
        --amount 2>&1 ) \
    | awk '{
        if($1 ~ /timeout/){
            print "TB_RES_OUT=TIMEOUT";
            exit 0;
        }
        if($1 == "etime:")
            print "TB_RES_ETIME="$2;
        if($0 ~ /Exception/){
            print "TB_RES_OUT=ERROR"
            str = $0;
            gsub(/["\$\\]/,"\\\\&",str)
            print "TB_RES_ERROR=\""str"\""
            exit 0;
        }    
        if(NR == 1)
            if($1 == "Wallet")
                print "TB_RES_OUT=OK";
    }' )    
    eval $vars
    cd $_WD
    return 0
}


#-------------------------------------------- main()

prepareenv

if [ $? -ne 0 ]; then
    _log  "ERROR: on creating test env"
    exit $?
fi    

runtagion 

if [ $? -ne 0 ]; then
    _log "ERROR: on starting tagionwave"
    exit $?
fi    

_log "Waiting 8s to start..."
sleep 8

_log "pid: $TB_PID"
_log ""
_ecnt_h=0
_ecnt_w=0
for lap in LAP1 LAP2 LAP3
do
    _log "[ $lap ]"
    _log "  - test healthcheck"
    _errcode=0
    for port in 10800 10801 10802 10803 10804
    do
        test_health $port
        _log "    [HEALTHCHECK] port: <$port> smoke: <$TB_RES_SMOKE> socket: <$TB_RES_SOCKET> out: <$TB_RES_OUT> error: <$TB_RES_ERROR> time: <$TB_RES_ETIME>"
        if [[ $TB_RES_SMOKE != "OK" || $TB_RES_SOCKET != "OK" || $TB_RES_OUT != "OK" ]];
        then
            _errcode=-1
            (( _ecnt_h =  _ecnt_h + 1 ))
        fi    
        _cleares
        sleep 1
    done
    _log "  - done"
    _log "  - current error status: [$_errcode]"
    _log "  - test wallet amount"
    for port in 10800
    do
        test_wallet_amount $port
        _log "    [WALLET] port: <$port> out: <$TB_RES_OUT> error: <$TB_RES_ERROR> time: <$TB_RES_ETIME>"
        if [ $TB_RES_OUT != "OK" ];
        then
            _errcode=-1
            (( _ecnt_w =  _ecnt_h + 1 ))
        fi    
        _cleares
        sleep 1
    done    
    _log "  - done"
    _log "  - current error status: [$_errcode]"
    _log "[ /$lap ]"
    _log ""
done

grep -E '(ERROR|FATAL)' $TDIR/tmp/error.log > $TB_LOGDIR/$TB_TESTDIR.error.log

_log "Stopping process"
kill -9 $TB_PID
_log "Clearing test dir"
rm -rf $TDIR

_log " --- Socket test summary"
_log " failed health checks: $_ecnt_h"
_log " failed wallet checks: $_ecnt_w"
_log " total error code:     $_errcode"
_log " ----"

exit $_errcode


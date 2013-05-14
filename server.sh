#!/bin/bash

OPTS_COMMON="-pa apps/*/ebin -pa deps/*/ebin -env ERL_CRASH_DUMP_SECONDS 1 -boot start_sasl -config serv"

usage() {
    echo usage: `basename $0` [--championship GAMETYPE NN] --port PORT
}

if [ $# -lt 2 ] ; then
    usage
    exit 1
fi

if [ $# -eq 5 ] ; then
    erl $OPTS_COMMON -eval "serv:start_championship($5, $2)."
fi
if [ $# -eq 2 ] ; then
    erl $OPTS_COMMON -eval "serv:start_normal($2)."
fi

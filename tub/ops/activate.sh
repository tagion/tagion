#!/usr/bin/env bash

get_newest_success_run_id() {
    gh run list --repo tagion/tagion -b current -w 'Main Flow' -s success -L1 --json databaseId --jq '.[0].databaseId'
}

get_workflow_artifact() {
    _worflowid=$1
    _outdir="artifacts/$_worflowid"

    mkdir -p $_outdir

    if [ ! -d "$_outdir/build" ]; then
        (cd $_outdir
            gh run download "$_worflowid" --repo tagion/tagion -n successful_artifact
            tar xzf *.tar.gz
        )
    fi

    echo $_outdir
}

## Main()
set -xe
gh auth status
workflowid=$(get_newest_success_run_id)
artifact_path=$(get_workflow_artifact $workflowid)
cd $artifact_path
make install
./scripts/run_ops.sh

#!/usr/bin/env bash

BRANCH="${BRANCH:=current}"

get_newest_success_run_id() {
    gh run list --repo tagion/tagion -b "$BRANCH" -w 'Main Flow' -s success -L1 --json databaseId --jq '.[0].databaseId'
}

get_workflow_artifact() {
    _prefix=$1
    _worflowid=$2
    _outdir="artifacts/$_prefix:$_worflowid"

    mkdir -p "$_outdir"

    if [ ! -d "$_outdir/build" ]; then
        (cd "$_outdir"
            gh run download "$_worflowid" --repo tagion/tagion -n x86_64-linux
        )
    fi

    echo "$_outdir"
}

## Main()
gh auth status
set -xe
systemctl stop --user neuewelle tagionshell || echo ok

# Archive old net data
DIR_EPOCH=$(stat -c%W ~/.local/share/tagion)
(cd ~/.local/share/
    OLD_TAR_NAME=tagion_$(date -d "@$DIR_EPOCH" +%F_%H-%M).tar.gz && \
      tar czf "$OLD_TAR_NAME" tagion/ && \
      rm -r tagion || \
      echo "No old data to backup"
)

workflowid=$(get_newest_success_run_id)
_date=$(date +'%Y-%m-%d')
artifact_path=$(get_workflow_artifact "$_date" "$workflowid")


# Run the operational test script
(cd "$artifact_path"
    make install-ops || echo "Busy"

    OPS_FLAGS="--duration=20 --unit=hours" ./scripts/run_ops.sh -i=true
)

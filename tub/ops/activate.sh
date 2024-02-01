#!/usr/bin/env bash

BRANCH="${BRANCH:=current}"

get_newest_success_run_id() {
    gh run list --repo tagion/tagion -b "$BRANCH" -w 'Main Flow' -s success -L1 --json databaseId --jq '.[0].databaseId'
}

get_workflow_artifact() {
    _worflowid=$1
    _outdir="artifacts/$_worflowid"

    mkdir -p "$_outdir"

    if [ ! -d "$_outdir/build" ]; then
        (cd "$_outdir"
            gh run download "$_worflowid" --repo tagion/tagion -n successful_artifact
            tar xzf ./*.tar.gz
        )
    fi

    echo "$_outdir"
}

## Main()
set -xe
systemctl stop --user neuewelle tagionshell || echo ok
DIR_EPOCH=$(stat -c%W ~/.local/share/tagion)
cd ~/.local/share/
OLD_TAR_NAME=tagion_$(date -d "@$DIR_EPOCH" +%F_%H-%M).tar.gz && \
  tar czf "$OLD_TAR_NAME" tagion/ && \
  rm -r tagion || \
  echo "No old data to backup"


gh auth status
workflowid=$(get_newest_success_run_id)
artifact_path=$(get_workflow_artifact "$workflowid")
cd "$artifact_path"
make install
rm -r ~/.local/share/tagion || echo "Nothing to delete"
OPS_FLAGS="--duration=20 --unit=hours" ./scripts/run_ops.sh -i=true

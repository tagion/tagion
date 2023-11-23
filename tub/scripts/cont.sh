#!/usr/bin/env bash

set -xe

remove_first() {
    tmp_file=$(mktemp)
    job_file=$1
    tail -n +2 $job_file > $tmp_file && mv $tmp_file $job_file
}

stop_old_jobs() {
    job_file=$1
    max_jobs="${$2:-3}"

    container_names=$(head -n -$max_jobs)
    for name in container_names; do
        lxc stop $name
    done;
}

new_job() {
    container_name=$1
    mkdir -p $container_name
    gh run download --repo tagion/tagion -n successful_artifact --dir $container_name
    cd $container_name
    tar xzf *
    lxc launch ubuntu:22.04 $container_name
    lxc file push -pr build/ $container_name/home/ubuntu/
    lxc exec $container_name -- /home/ubuntu/build/x86_64-linux/bin/run-ops.sh
    cd -
}

#!/usr/bin/env bash

set -xe

stop_old_jobs() {
    job_file=$1
    max_jobs="${2:-3}"

    container_names=$(head -n -$max_jobs $job_file)
    for name in container_names; do
        echo "stopping $name"
        lxc stop $name && lxc delete $name
    done;

    tmp_file=$(mktemp)
    tail -n -$max_jobs $job_file > $tmp_file && mv $tmp_file $job_file
}

new_job() {
    job_file=$1
    container_name=$2
    mkdir -p $container_name
    gh run download --repo tagion/tagion -n successful_artifact --dir $container_name
    cd $container_name
    tar xzf *
    lxc launch ubuntu:22.04 $container_name
    lxc file push -pr build/ $container_name/home/ubuntu/
    lxc exec $container_name -- /home/ubuntu/build/x86_64-linux/bin/run-ops.sh
    cd -

    echo $container_name >> $job_file
}

# new_job jobs.txt $(date)
stop_old_jobs jobs.txt

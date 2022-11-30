#!/usr/bin/env bash
cat << EOF > $1
#!/usr/bin/env bash
export DBIN=$DBIN
export DLOG=$DLOG
export BDD=$BDD
export TESTBENCH=$TESTBENCH
export BDD_LOG=$BDD_LOG
export BDD_RESULTS=$BDD_RESULTS
export REPOROOT=$REPOROOT
export FUND=$FUND
export REPORT_ROOT=$REPOROOT/regression
PATH=\$DBIN:\$PATH
cd $$REPORT_ROOT
screen -S reporter-view -dm npm run dev &
touch $@
EOF



#!/usr/bin/env bash
cat << EOF > $1
#!/usr/bin/env bash
export DBIN=$DBIN
export DLOG=$DLOG
export BDD=$BDD
export TESTLOG=$TESTLOG
export BDD_LOG=$BDD_LOG
export BDD_RESULTS=$BDD_RESULTS
export FUND=$FUND
export REPOROOT=$REPOROOT
export FUND=$FUND
export TEST_STAGE=$TEST_STAGE
PATH=\$DBIN:\$PATH
\$*
EOF



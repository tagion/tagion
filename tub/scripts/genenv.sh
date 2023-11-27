#!/usr/bin/env bash
cat << EOF > $1
#!/usr/bin/env bash
export DBIN=$DBIN
export DLOG=$DLOG
export BDD=$BDD
export BDD_LOG=$BDD_LOG
export BDD_RESULTS=$BDD_RESULTS
export REPOROOT=$REPOROOT
export TEST_STAGE=$TEST_STAGE
export SEED=$SEED
PATH=\$DBIN:\$PATH
\$*
EOF



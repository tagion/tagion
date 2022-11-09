#!/usr/bin/env bash
cat << EOF > $1
#!/usr/bin/env bash
export DBIN=$DBIN
export DLOG=$DLOG
export BDD=$BDD
export TESTBENCH=$TESTBENCH
export BDD_LOG=$BDD_LOG
export REPOROOT=$REPOROOT
PATH=\$DBIN:\$PATH
\$*
EOF



REPOROOT?=${shell git rev-parse --show-toplevel}
GIT_INFO?=${shell git config --get remote.origin.url}
GIT_REVNO?=${shell git log --pretty=format:'%h' | wc -l}
GIT_HASH?=${shell git rev-parse HEAD}
define GITROOT
${shell cd $1; git rev-parse --show-toplevel}
endef

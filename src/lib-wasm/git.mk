GIT_INFO=${sheel git config --get remote.origin.url}
GIT_REVNO=${shell git log --pretty=format:'%h' | wc -l}
GIT_HASH=${shell git rev-parse HEAD}
GIT_ROOT= ${shell git rev-parse --show-toplevel}

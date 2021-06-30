MAKER_GIT_HASH ?= ${shell git rev-parse HEAD}
MAKER_GIT_REVNO ?= ${shell git log --pretty=format:'%h' | wc -l}

info:
	${call log.header, maker :: info}
	${call log.kvp, commit, $(MAKER_GIT_HASH)}
	${call log.kvp, revision, ${strip $(MAKER_GIT_REVNO)}}
	${call log.close}
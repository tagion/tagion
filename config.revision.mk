REVISION_FILE?=$(DBUILD)/revision.mixin
GIT_HASH=${shell git rev-parse HEAD}
GIT_INFO=${shell git  config --get remote.origin.url}
GIT_REVNO=${shell git log --pretty=format:'%h'|wc -l}
GIT_DATE=${shell date +'%F %H:%M'}

DFLAGS+=$(DIMPORTFILE)$(DBUILD)

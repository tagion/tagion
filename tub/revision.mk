GIT_HASH ?= ${shell git rev-parse HEAD}
GIT_REVNO ?= ${shell git log --pretty=format:'%h' | wc -l}

%/revision.di:
	@echo "Revision generation is not yet supported"
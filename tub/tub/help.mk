HELPER+=main_help

.PHONY: help

help: $(HELPER)

TUB_COMMIT = ${shell cd $(DROOT)/tub; git rev-parse --short HEAD}
TUB_BRANCH = ${shell cd $(DROOT)/tub; git rev-parse --abbrev-ref HEAD}

main_help:
	$(PRECMD)
	echo
	echo $(SEP) help
	echo "make init: First-time tub initialization (required)"
	echo 
	echo "make configure: Configure units to compile"
	echo "make lib*: Compile src/lib-*"
	echo "make lib*.test: Compile and execute tests for src/lib-*"
	echo "make tagion*: Compile src/bin-*"
	echo "make *: compile wrapped library | example: make secp256k1"
	echo "make clean: Clean built and generated files"
	echo
	echo "make help: Show this help"
	echo "make env: Show Make variables"
	echo "make clone-* BRANCH=<branch>: Clone specific unit"
	echo
	echo "README: $(DTUB)/README.md"
	echo "Branch: $(TUB_BRANCH)"
	echo "Commit: $(TUB_COMMIT)"
	echo
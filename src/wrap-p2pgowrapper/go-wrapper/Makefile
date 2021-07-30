include git.mk

ifndef INCLUDE
${error this Makefile can must be executed from a parent Makefile}
endif
include ${INCLUDE}
#include ${REPOROOT}/go-lib/setup.mk

all: ${CHELPERH} ${GOLIBP2P} ${HELPERDI} ${LIBP2PDI}
	@echo "################################## END GO LIB ##########################################"

${GOLIBP2P}: #${LIBP2PDI} ${HELPERDI}
	@echo "########################################################################################"
	@echo "## Build go libp2p"
	$(PRECMD)go build -buildmode=c-archive -o ${GOLIBP2P}
	$(PRECMD)mv ${GOLIBP2P:.a=.h} ${INCROOT}


build: ${GOLIBP2P}

buildlibdi: ${LIBP2PDI}
builddi: ${HELPERDI}
buildch: ${CHELPERH}

${LIBP2PDI}: ${LIBP2PH}
	@echo "########################################################################################"
	@echo "## DSTEP libp2p.di"
	$(PRECMD) dstep $< -o $@ --package ${DPACKAGE} --global-import ${DHELPERPACKAGE}

${HELPERDI}: ${CHELPER}
	@echo "########################################################################################"
	@echo "## DSTEP helper.di"
	$(PRECMD)dstep $< -o $@ --package ${DPACKAGE}

${CHELPERH}: ${CHELPER}
	@echo "########################################################################################"
	@echo "## "$(notdir $@)
	$(PRECMD)cp $< $@

clean:
	@echo "########################################################################################"
	@echo "## GO CLEAN"
	$(PRECMD)rm -f ${LIBP2PDI} ${HELPERDI}
	$(PRECMD)rm -f ${CHELPERH}
	$(PRECMD)rm -f ${GOLIBP2P}

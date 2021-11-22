REPO_P2PGOWRAPPER ?= git@github.com:tagion/p2pgowrapper.git
VERSION_P2PGOWRAPPER := dfc77c04e0395e09652c0daa25f9f19b77c2b1d6

DSRC_P2PGOWRAPPER := ${call dir.resolve, src}
DTMP_P2PGOWRAPPER := $(DTMP)/p2pgowrapper

DIR_P2PGOWRAPPER_PREFIX := $(DIR_P2PGOWRAPPER)/lib
DIR_P2PGOWRAPPER_SRC := $(DIR_P2PGOWRAPPER)/src

ifeq ($(OS),Darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

p2pgowrapper.preconfigure: $(DSRC_P2PGOWRAPPER)/.src
p2pgowrapper: $(DTMP)/libp2pgowrapper.a
	@

TOCLEAN_P2PGOWRAPPER += $(DTMP)/libp2pgowrapper.a
TOCLEAN_P2PGOWRAPPER += $(DSRC_P2PGOWRAPPER)
TOCLEAN_P2PGOWRAPPER += $(DTMP_P2PGOWRAPPER)

TOCLEAN += $(TOCLEAN_P2PGOWRAPPER)

clean-p2pgowrapper: TOCLEAN := $(TOCLEAN_P2PGOWRAPPER)
clean-p2pgowrapper: clean
	@

$(DTMP)/libp2pgowrapper.a: $(DSRC_P2PGOWRAPPER)/.src $(DTMP_P2PGOWRAPPER)/bin/.way
	$(PRECMD)$(CP) $(DSRC_P2PGOWRAPPER) $(DTMP_P2PGOWRAPPER)
	$(PRECMD)cd $(DTMP_P2PGOWRAPPER); go build -buildmode=c-archive -o $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.a
	$(PRECMD)cd $(DTMP_P2PGOWRAPPER); $(MV) $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.a $(DTMP)/libp2pgowrapper.a

$(DSRC_P2PGOWRAPPER)/.src:
	$(PRECMD)git clone --depth 1 $(REPO_P2PGOWRAPPER) $(DSRC_P2PGOWRAPPER)
	$(PRECMD)git -C $(DSRC_P2PGOWRAPPER) fetch --depth 1 $(REPO_P2PGOWRAPPER) $(VERSION_P2PGOWRAPPER)
	$(PRECMD)touch $@


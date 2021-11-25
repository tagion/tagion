REPO_P2PGOWRAPPER ?= git@github.com:tagion/p2pgowrapper.git
VERSION_P2PGOWRAPPER := dfc77c04e0395e09652c0daa25f9f19b77c2b1d6

DSRC_P2PGOWRAPPER := ${call dir.resolve, src}
DTMP_P2PGOWRAPPER := $(DTMP)/p2pgowrapper

DIR_P2PGOWRAPPER_PREFIX := $(DIR_P2PGOWRAPPER)/lib
DIR_P2PGOWRAPPER_SRC := $(DIR_P2PGOWRAPPER)/src

p2pgowrapper: $(DTMP)/libp2pgowrapper.a
	@

TOCLEAN_P2PGOWRAPPER += $(DTMP)/libp2pgowrapper.a
TOCLEAN_P2PGOWRAPPER += $(DTMP_P2PGOWRAPPER)

TOCLEAN += $(TOCLEAN_P2PGOWRAPPER)

clean-p2pgowrapper: TOCLEAN := $(TOCLEAN_P2PGOWRAPPER)
clean-p2pgowrapper: clean
	@

$(DTMP)/libp2pgowrapper.a: $(DTMP_P2PGOWRAPPER)/.way
	$(PRECMD)$(CP) $(DSRC_P2PGOWRAPPER)/* $(DTMP_P2PGOWRAPPER)
	$(PRECMD)cd $(DTMP_P2PGOWRAPPER); go build -buildmode=c-archive -o $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.a
	$(PRECMD)cd $(DTMP_P2PGOWRAPPER); $(MV) $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.a $(DTMP)/libp2pgowrapper.a



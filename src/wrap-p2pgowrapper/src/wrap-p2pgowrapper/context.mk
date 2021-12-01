DSRC_P2PGOWRAPPER := ${call dir.resolve, src}
DTMP_P2PGOWRAPPER := $(DTMP)/p2pgowrapper

CONFIGUREFLAGS_P2PGOWRAPPER :=

include ${call dir.resolve, cross.mk}

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



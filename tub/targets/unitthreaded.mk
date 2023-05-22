UT_PACKAGE=~/.dub/packages/unit-threaded-2.1.6/unit-threaded
UT_FILE=bin/ut.d

UT_INC=${addprefix -I,${shell cd ~/.dub/packages/unit-threaded-2.1.6/unit-threaded/; dub describe --data=import-paths --data-list}}
UT_SRC=${shell find $(UT_PACKAGE) -name "*.d" -a -not -path "*/tests/*" -a -not -path "*/tmp/*" -a -not -path "*/example/*" -a -not -path "*/gen/*" -a -not -name "autorunner.d"} 
UT_BIN=$(DBIN)/ut
$(UT_BIN): DFLAGS+=$(UT_INC)
$(UT_BIN): DFLAGS+=$(DUNITTEST) $(DDEBUG_SYMBOLS)
$(UT_BIN): LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)

$(UT_BIN): $(LIB_DFILES)
$(UT_BIN): $(UT_SRC) $(DIFILES)

$(UT_BIN): $(UT_FILE)
unitthreaded: $(UT_BIN)
	
gen_ut:
	$(UT_PACKAGE)/gen_ut_main --file $(UT_FILE) $(UT_INC) ${addprefix -I,$(DINC)} 

BASIC_DFILES+=tagion/basic/TagionExceptions.d
BASIC_DFILES+=tagion/basic/Basic.d
BASIC_DFILES+=tagion/basic/Message.d
BASIC_DFILES:=$(addprefix $(TAGION_BASIC)/,$(BASIC_DFILES))

TAGION_DFILES+=$(BASIC_DFILES)

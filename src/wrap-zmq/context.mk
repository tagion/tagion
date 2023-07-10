

LIBZMQ_NAME:=libzmq

ifdef SHARED
LIBZMQ_FILE:=$(LIBZMQ_NAME).$(DLLEXT)
CONFIGUREFLAGS_ZMQ += --enable-shared=yes
else
LIBZMQ_FILE:=$(LIBZMQ_NAME).$(STAEXT)
CONFIGUREFLAGS_ZMQ += --enable-shared=on
endif


DSRC_ZMQ := ${call dir.resolve, libzmq}
DTMP_ZMQ := $(DTMP)/libzmq

LIBZMQ:=$(DTMP_ZMQ)/.libs/$(LIBZMQ_FILE)
LIBZMQ_STATIC:=$(DTMP_ZMQ)/.libs/$(LIBZMQ_NAME).$(STAEXT)
LIBZMQ_OBJ:=$(DTMP_ZMQ)/src/libzmq_la-zmq.o


zmq: $(LIBZMQ)

proper-zmq:
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RM) $(LIBZMQ)
	$(RMDIR) $(DTMP_ZMQ)

.PHONY: proper-zmq

proper: proper-zmq

$(DTMP_ZMQ)/.libs/$(LIBZMQ_NAME).%: $(DTMP)/.way $(DLIB)/.way
	$(PRECMD)
	${call log.kvp, $@}
	$(CP) $(DSRC_ZMQ) $(DTMP_ZMQ)
	$(CD) $(DTMP_ZMQ)
	./autogen.sh
	./configure $(CONFIGUREFLAGS_ZMQ)
	$(MAKE) clean
	$(MAKE)

env-zmq:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, CONFIGUREFLAGS_ZMQ, $(CONFIGUREFLAGS_ZMQ)}
	${call log.kvp, LIBZMQ, $(LIBZMQ)}
	${call log.kvp, DTMP_ZMQ, $(DTMP_ZMQ)}
	${call log.kvp, DSRC_ZMQ, $(DSRC_ZMQ)}
	${call log.close}

.PHONY: env-zmq

env: env-zmq

help-zmq:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make zmq", "Creates the zmq library"}
	${call log.help, "make help-zmq", "Will display this part"}
	${call log.help, "make proper-zmq", "Erase all zmq objects and libraries"}
	${call log.help, "make env-zmq", "List all zmq build environment"}
	${call log.close}

.PHONY: help-zmq

help: help-zmq


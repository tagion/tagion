
VALGRIND_FLAGS+=--tool=callgrind 
VALGRIND_FLAGS+=--dump-instr=yes 
VALGRIND_FLAGS+=--simulate-cache=yes 
VALGRIND_FLAGS+=--collect-jumps=yes

VALGRIND_TOOL?=valgrind
CALLGRIND_UNITTEST_OUT?=$(DLOG)/callgrind.unittest.log

ifdef VALGRIND
PRETOOL:=$(VALGRIND_TOOL) $(VALGRIND_FLAGS)
endif

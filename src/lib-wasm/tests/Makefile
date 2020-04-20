
REPOROOT?=${shell git rev-parse --show-toplevel}
WAVMROOT:=$(REPOROOT)/../WAVM/

# Unwind
CFLAGS+=${shell pkg-config --cflags libunwind}
LDFLAGS+=${shell pkg-config --libs libunwind}

# LLVM Flags
CFLAGS+=${shell llvm-config --cxxflags}
LDFLAGS+=${shell llvm-config --ldflags --libs}

# WAVM
CFLAGS+=-I$(WAVMROOT)/Include/ -g
DFLAGS+=-I$(REPOROOT)
DFLAGS+=-g
LDFLAGS+=-L$(WAVMROOT) -lWAVM

DLDFLAGS:=${addprefix -L,$(LDFLAGS)}

CXX:=g++
DC:=dmd
MAIN:=embedder_example

# test:
# 	echo ${DLDFLAGS}

run: all
	export LD_LIBRARY_PATH=$(WAVMROOT); ./$(MAIN)

all: $(MAIN)

ifdef CLANG
%: %.c
	$(CXX) $(CFLAGS) -m64 $< -o $@ ${LDFLAGS}
else
%: %.d
	$(DC)  $(DFLAGS) -m64 $< -of=$@ ${DLDFLAGS}
endif

clean:
	rm -f $(MAIN)

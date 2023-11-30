CFLAGS=-g -ggdb -Wall -Werror -O3 
DC=dmd
DCFLAGS=-O -d -m64 -i -debug -g -gf -gs -gx -dip1000

all: cfiles dfiles

cfiles: libcf.a ctest

libcf.a: cfunctions.o cserver.o
	ar rcs $@ $^

cfunctions.o: cfunctions.c cfunctions.h
	gcc -c -o $@ $<

cserver.o: cserver.c cserver.h
	gcc -c -o $@ $<

ctest:
	gcc $(CFLAGS) -o ctest *.c

dfiles:
	$(DC) $(DCFLAGS) -of=dtest -I. -L-L. -L-lcf dtest.d

clean:
	rm -f *.o *.a ctest dtest


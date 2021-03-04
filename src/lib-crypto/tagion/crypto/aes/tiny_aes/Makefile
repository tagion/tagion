MAIN:=tiny_aes
DFILES:=$(MAIN).d
OBJS:=${DFILES:.d=.o}

all: build run


build: $(DFILES)
	dmd -g -unittest -main $(DFILES)

run:
	./$(MAIN);

clean:
	rm -f $(MAIN)
	rm -f $(OBJS)

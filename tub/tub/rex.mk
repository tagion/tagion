REX := $(DTUB)/rex/rex
rex: $(REX)
	@

$(REX):
	$(PRECMD)git clone https://github.com/tagion/rex.git $(DTUB)/rex
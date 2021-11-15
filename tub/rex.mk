REX := $(DIR_TUB)/rex/rex
rex: $(REX)
	@

$(REX):
	$(PRECMD)git clone https://github.com/tagion/rex.git $(DIR_TUB)/rex
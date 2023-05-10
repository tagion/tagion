clean-libs:
	$(PRECMD)
	$(RM) -r $(DLIB)/*

.PHONY: clean-libs

clean: clean-libs

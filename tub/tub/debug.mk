define debug
${if $(MAKEDEBUG), ${info [debug] ${strip $1}},}
endef
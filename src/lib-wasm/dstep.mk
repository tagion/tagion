dodi: ${WAVM_DI}
	echo ${WAVM_DI}
	echo ${WAVM_H}

${WAVM_DI}: ${WAVM_H} makeway
	dstep $< -o $@ --package $(WAVM_PACKAGE)
	${WAVMa2p} $@

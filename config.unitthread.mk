UNITTHREAD_PATH?=~/.dub/packages/unit-threaded-2.1.6/unit-threaded
UNITTHREAD_INC:=${shell cd $(UNITTHREAD_PATH); dub describe --data=import-paths}

test78:
	echo $(UNITTHREAD_INC)
	
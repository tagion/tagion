# Local setup, ignored by git
-include $(DIR_ROOT)/local.mk

# Core tub functionality
include $(DIR_TUB)/basic/_.mk
include $(DIR_TUB)/meta/_.mk
include $(DIR_TUB)/compile/_.mk
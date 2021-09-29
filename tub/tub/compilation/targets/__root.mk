# The flow of target generation:
# 	1. goals.mk - parse make arguments to define targets
# 	2. include.mk - initiate target generation process
# 	3. resolve.mk - resolve dependencies of target unit
# 
# For each target found in 1, do 2 -> 3;

include $(DIR_TUB)/compilation/targets/vars.mk

include $(DIR_TUB)/compilation/targets/list.mk
include $(DIR_TUB)/compilation/targets/include.mk
include $(DIR_TUB)/compilation/targets/resolve.mk

include $(DIR_TUB)/compilation/targets/interface.mk

include $(DIR_TUB)/compilation/targets/goals.mk
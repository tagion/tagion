DEPS += lib-services
DEPS += lib-utils
DEPS += lib-dart

PROGRAM := tagionlogservicetest

$(PROGRAM).configure: SOURCE := tagion/*.d

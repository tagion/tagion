# tools directory
TOOLS:=$(abspath $(REPOROOT)/tools)

LDC_VERSION:=1.37.0
CMAKE_VERSION:=3.19.2

LDC_HOST:=ldc2-${LDC_VERSION}-osx-universal
LDC_HOST_TAR:=$(LDC_HOST).tar.xz

IOS_CMAKE_TAR:=cmake-${CMAKE_VERSION}-macos-universal.tar.gz
IOS_CMAKE:=ios-cmake

install-ios-toolchain: $(TOOLS)/.way
install-ios-toolchain: $(LDC_HOST) $(IOS_CMAKE)

$(TOOLS)/.way:
	mkdir -p $(TOOLS)
	touch $(TOOLS)/.way

$(TOOLS)/$(LDC_HOST)/.done:
	cd $(TOOLS)
	wget https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/${LDC_HOST_TAR} -O ${LDC_HOST_TAR}
	tar xf $(LDC_HOST_TAR)
	cd -
	touch $@

$(TOOLS)/$(LDC_HOST)/etc/ldc2.conf: tub/ldc2.conf
	cp tub/ldc2.conf $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/.done
$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

$(TOOLS)/$(IOS_CMAKE)/.done:
	cd $(TOOLS)
	wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${IOS_CMAKE_TAR} -O ${IOS_CMAKE_TAR}
	mkdir $(IOS_CMAKE)
	tar xf $(IOS_CMAKE_TAR) -C $(IOS_CMAKE) --strip-components 3
	cd -
	touch $@

$(IOS_CMAKE): $(TOOLS)/$(IOS_CMAKE)/.done

clean-tools:
	$(RM) -vr $(TOOLS)

.PHONY: clean-tools

proper: clean-tools
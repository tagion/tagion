#!/usr/bin/env bash
# Because i don't want to specify every single include path in external projects
mkdir -p include/tagion
cd include/tagion
ln -s ../../src/lib-actor/tagion/actor
ln -s ../../src/lib-communication/tagion/communication
ln -s ../../src/lib-crypto/tagion/crypto
ln -s ../../src/lib-dart/tagion/dart
ln -s ../../src/lib-funnel/tagion/script
ln -s ../../src/lib-gossip/tagion/gossip
ln -s ../../src/lib-hashchain/tagion/epochain
ln -s ../../src/lib-hashchain/tagion/hashchain
ln -s ../../src/lib-hashchain/tagion/recorderchain
ln -s ../../src/lib-hashgraph/tagion/hashgraph
ln -s ../../src/lib-hashgraphview/tagion/hashgraphview
ln -s ../../src/lib-hibon/tagion/hibon
ln -s ../../src/lib-logger/tagion/logger
ln -s ../../src/lib-monitor/tagion/monitor
ln -s ../../src/lib-network/tagion/network
ln -s ../../src/lib-nngd/libnng/libnng
ln -s ../../src/lib-nngd/nngd/nngd
ln -s ../../src/lib-options/tagion/options
ln -s ../../src/lib-phobos/tagion/std
ln -s ../../src/lib-services/tagion/GlobalSignals.d
ln -s ../../src/lib-services/tagion/services
ln -s ../../src/lib-tools/tagion/tools
ln -s ../../src/lib-trt/tagion/trt
ln -s ../../src/lib-utils/tagion/utils
ln -s ../../src/lib-wallet/tagion/wallet
ln -s ../../src/lib-wasm/tagion/wasm
ln -s ../../src/lib-basic/tagion/basic
cd -

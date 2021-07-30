package main

//#include "c_helper.h"
import "C"

import (
	"fmt"
	"p2p/core"
	"p2p/helper"
	"p2p/registry"
	"runtime"
	"strings"
	"unsafe"

	logging "github.com/ipfs/go-log"
	"github.com/libp2p/go-libp2p"
	autonat "github.com/libp2p/go-libp2p-autonat"
	coreLibp2p "github.com/libp2p/go-libp2p-core"
)

func main() {
}

//export enableLogger
func enableLogger() {
	logging.SetAllLoggers(logging.LevelDebug)
}

// ======OPTIONS=======

//export optAddressApi
func optAddressApi(addr C.DBuffer) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := helper.OptAddress(asString(addr))
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optNoListenAddrsApi
func optNoListenAddrsApi() (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := libp2p.NoListenAddrs
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optEnableAutoNATServiceApi
func optEnableAutoNATServiceApi() (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := helper.OptEnableAutonat()
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optEnableAutoRelayApi
func optEnableAutoRelayApi() (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := helper.OptEnableAutoRelay()
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optEnableNATPortMapApi
func optEnableNATPortMapApi() (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := helper.OptEnableNATPortMap()
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optIdentityApi
func optIdentityApi(seed C.int) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := helper.OptIdentity(int(seed))
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export subscribeToRechabiltyEventApi
func subscribeToRechabiltyEventApi(h unsafe.Pointer, handler unsafe.Pointer, tid C.DBuffer) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	node := helper.ConvertToNode(h)
	subs := core.SubscribeToRechabiltyEvent(node, handler, asString(tid))
	registry.Register(unsafe.Pointer(&subs))
	return unsafe.Pointer(&subs), code
}

//export subscribeToAddressUpdatedEventApi
func subscribeToAddressUpdatedEventApi(h unsafe.Pointer, handler unsafe.Pointer, tid C.DBuffer) (prt unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	node := helper.ConvertToNode(h)
	subs := core.SubscribeToAddressUpdatedEvent(node, handler, asString(tid))
	registry.Register(unsafe.Pointer(&subs))
	return unsafe.Pointer(&subs), code
}

//export unsubscribeApi
func unsubscribeApi(subsPtr unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	subs := helper.ConvertToSubscription(subsPtr)
	subs.Close()
	return code
}

// ======CONTEXT======

//export createBackgroundContextApi
func createBackgroundContextApi() (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	ctx := core.CreateBackgroundContext()
	registry.Register(unsafe.Pointer(&ctx))
	return unsafe.Pointer(&ctx), code
}

// ======MDNS======

//export createMdnsApi
func createMdnsApi(ctxPtr unsafe.Pointer, nodePtr unsafe.Pointer, time int32, rendezvous C.DBuffer) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	ctx := helper.ConvertToContext(ctxPtr)
	node := helper.ConvertToNode(nodePtr)
	service := core.CreateMdnsService(ctx, node, time, asString(rendezvous))
	registry.Register(unsafe.Pointer(&service))
	return unsafe.Pointer(&service), code
}

//export registerNotifeeApi
func registerNotifeeApi(servicePtr unsafe.Pointer, handler unsafe.Pointer, tid C.DBuffer) (notifeePtr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	service := helper.ConvertToMdnsService(servicePtr)
	notifee := core.RegisterNotifee(service, handler, asString(tid))
	notifeePtr = unsafe.Pointer(&notifee)
	registry.Register(notifeePtr)
	return notifeePtr, code
}

//export unregisterNotifeeApi
func unregisterNotifeeApi(servicePtr unsafe.Pointer, notifeePtr unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	service := helper.ConvertToMdnsService(servicePtr)
	notifee := helper.ConvertToNotifee(notifeePtr)
	core.UnregisterNotifee(service, notifee)
	return code
}

//export stopMdnsApi
func stopMdnsApi(servicePtr unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	service := helper.ConvertToMdnsService(servicePtr)
	core.CloseMdns(service)
	return code
}

// ======NODE======

//export createNodeApi
func createNodeApi(ctx unsafe.Pointer, opts []unsafe.Pointer) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	context := helper.ConvertToContext(ctx)
	op := make([]libp2p.Option, len(opts))
	for i, o := range opts {
		op[i] = helper.ConvertToOption(o)
	}
	node := core.CreateNode(context, op...)
	registry.Register(unsafe.Pointer(&node))
	return unsafe.Pointer(&node), code
}

//export closeNodeApi
func closeNodeApi(node unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	core.CloseNode(n)
	return code
}

//export getNodeIdApi
func getNodeIdApi(node unsafe.Pointer, callback unsafe.Pointer, context unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	addr := core.GetNodeId(n)
	addrPtr := make([]byte, len(addr))
	copy(addrPtr, addr)
	C.bridgeCallback(C.callback(callback), unsafe.Pointer(&(addrPtr[0])), C.int(len(addr)), context)
	return code
}

//export getNodeAddrInfoMarshalApi
func getNodeAddrInfoMarshalApi(node unsafe.Pointer, callback unsafe.Pointer, context unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	addr := core.GetNodeAddrInfoMarshal(n)
	addrPtr := make([]byte, len(addr))
	copy(addrPtr, addr)
	C.bridgeCallback(C.callback(callback), unsafe.Pointer(&(addrPtr[0])), C.int(len(addr)), context)
	return code
}

//export getNodeAddressesApi
func getNodeAddressesApi(node unsafe.Pointer, callback unsafe.Pointer, context unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	addreses := core.GetNodeAddress(n)
	addrJoined := strings.Join(addreses[:], ",")
	addrPtr := make([]byte, len(addrJoined))
	copy(addrPtr, addrJoined)
	C.bridgeCallback(C.callback(callback), unsafe.Pointer(&(addrPtr[0])), C.int(len(addrJoined)), context)
	return code
}

//export getNodePublicAddressApi
func getNodePublicAddressApi(node unsafe.Pointer, callback unsafe.Pointer, context unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	address := core.GetNodePublicAddress(n)
	if len(address) != 0 {
		addrPtr := make([]byte, len(address))
		copy(addrPtr, address)
		C.bridgeCallback(C.callback(callback), unsafe.Pointer(&(addrPtr[0])), C.int(len(address)), context)
	} else {
		empty := C.emptyDBuffer()
		C.bridgeCallback(C.callback(callback), unsafe.Pointer(&empty), C.int(0), context)
	}
	return code
}

//export getAddrInfoMarshalApi
func getAddrInfoMarshalApi(node unsafe.Pointer, callback unsafe.Pointer, context unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	addreses := core.GetNodeAddress(n)
	addrJoined := strings.Join(addreses[:], ",")
	addrPtr := make([]byte, len(addrJoined))
	copy(addrPtr, addrJoined)
	C.bridgeCallback(C.callback(callback), unsafe.Pointer(&(addrPtr[0])), C.int(len(addrJoined)), context)
	return code
}

//export handleApi
func handleApi(node unsafe.Pointer, addr C.DBuffer, pids []C.DBuffer, marshal bool) (ptr unsafe.Pointer, id uint64, code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	protocolIds := make([]coreLibp2p.ProtocolID, len(pids))
	for i, val := range pids {
		protocolIds[i] = helper.GetPid(asString(val))
	}

	if marshal {
		stream := core.SetHandlerMarshal(n, asByteArr(addr), protocolIds)
		registry.Register(unsafe.Pointer(&stream))
		id = helper.GetIdentifier()
		return unsafe.Pointer(&stream), id, code
	} else {
		stream := core.SetHandler(n, asString(addr), protocolIds)
		registry.Register(unsafe.Pointer(&stream))
		id = helper.GetIdentifier()
		return unsafe.Pointer(&stream), id, code
	}
}

//export connectApi
func connectApi(node unsafe.Pointer, ctx unsafe.Pointer, addr C.DBuffer, marshal bool) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	c := helper.ConvertToContext(ctx)
	if marshal {
		core.ConnectMarshal(n, c, asByteArr(addr))
	} else {
		core.Connect(n, c, asString(addr))
	}
	return code
}

//export listenStreamApi
func listenStreamApi(stream unsafe.Pointer, id uint64, handler unsafe.Pointer, tid C.DBuffer, timeout int32, maxLength int32) (code C.ErrorCode) {
	defer handleError(&code)
	s := helper.ConvertToStream(stream) //TODO: can throw an exception
	nid := new(uint64)
	*nid = id
	handlerFunc := helper.GetHandler(handler, asString(tid), timeout, maxLength, nid)
	handlerFunc(s)
	return code
}

// ======LISTEN======

//export listenApi
func listenApi(node unsafe.Pointer, pid C.DBuffer, handler unsafe.Pointer, tid C.DBuffer, timeout int32, maxLength int32) (code C.ErrorCode) {
	defer handleError(&code)
	helper.PrintToConsole("called go listen pid: ", asString(pid))
	n := helper.ConvertToNode(node)
	core.Listen(n, helper.GetPid(asString(pid)), helper.GetHandler(handler, asString(tid), timeout, maxLength, nil))
	return code
}

//export listenMatchApi
func listenMatchApi(node unsafe.Pointer, pid C.DBuffer, handler unsafe.Pointer, tid C.DBuffer, timeout int32, maxLength int32, pids []C.DBuffer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	protocolIds := make([]string, len(pids))
	for i, val := range pids {
		protocolIds[i] = asString(val)
	}
	match := helper.GetMatch(protocolIds)
	core.ListenMatch(n, helper.GetPid(asString(pid)), helper.GetHandler(handler, asString(tid), timeout, maxLength, nil), match)
	return code
}

//export closeListenerApi
func closeListenerApi(node unsafe.Pointer, pid C.DBuffer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToNode(node)
	core.CloseListener(n, helper.GetPid(asString(pid)))
	return code
}

//export writeApi
func writeApi(stream unsafe.Pointer, data unsafe.Pointer, dataLen C.int) (code C.ErrorCode) {
	defer handleError(&code)
	s := helper.ConvertToStream(stream)
	core.Write(s, C.GoBytes(data, dataLen))
	return code
}

//export closeStreamApi
func closeStreamApi(stream unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	s := helper.ConvertToStream(stream)
	core.CloseStream(s)
	return code
}

//export resetStreamApi
func resetStreamApi(stream unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	s := helper.ConvertToStream(stream)
	core.ResetStream(s)
	return code
}

//export destroyApi
func destroyApi(ptr unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	registry.Unregister(ptr)
	return code
}

// AUTONAT

//export createAutoNATApi
func createAutoNATApi(host unsafe.Pointer, ctx unsafe.Pointer, opts []unsafe.Pointer) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	h := helper.ConvertToNode(host)
	c := helper.ConvertToContext(ctx)

	op := make([]autonat.Option, len(opts))
	for i, o := range opts {
		op[i] = helper.ConvertToAutonatOption(o)
	}

	nat := core.CreateAutoNAT(c, h, op...)
	registry.Register(unsafe.Pointer(&nat))
	return unsafe.Pointer(&nat), code
}

//export optEnableServiceApi
func optEnableServiceApi(host unsafe.Pointer) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	h := helper.ConvertToNode(host)
	opt := core.OptEnableService(h.Network())
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optWithoutStartupDelayApi
func optWithoutStartupDelayApi() (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := core.OptWithoutStartupDelay()
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export optWithScheduleApi
func optWithScheduleApi(retryInterval int32, refreshInterval int32) (ptr unsafe.Pointer, code C.ErrorCode) {
	defer handleError(&code)
	opt := core.OptWithSchedule(retryInterval, refreshInterval)
	registry.Register(unsafe.Pointer(&opt))
	return unsafe.Pointer(&opt), code
}

//export getPublicAddress
func getPublicAddress(nat unsafe.Pointer, callback unsafe.Pointer, context unsafe.Pointer) (code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToAutoNAT(nat)
	addr := core.GetAutoNATAddress(n)
	addrPtr := make([]byte, len(addr))
	copy(addrPtr, addr)
	C.bridgeCallback(C.callback(callback), unsafe.Pointer(&(addrPtr[0])), C.int(len(addr)), context)
	return code
}

//export getNATStatus
func getNATStatus(nat unsafe.Pointer) (status C.NATStatus, code C.ErrorCode) {
	defer handleError(&code)
	n := helper.ConvertToAutoNAT(nat)
	status = (C.NATStatus)(core.GetAutoNATStatus(n))
	return status, code
}

//export callGCApi
func callGCApi() { //only for testing
	runtime.GC()
}

// TODO: moveout after
// ======helper functions======

func asString(str C.DBuffer) string {
	return C.GoStringN((*C.char)(str.pointer), str.length)
}
func asByteArr(str C.DBuffer) []byte {
	return []byte(C.GoStringN((*C.char)(str.pointer), str.length))
}
func asCallback(cb C.DCallback) helper.Callback {
	return helper.Callback{CallbackFunction: cb.callback, Context: cb.context}
}

func handleError(code *C.ErrorCode) {
	if err := recover(); err != nil {
		fmt.Println("ERROR FROM GO:", err)
		*code = C.InternalError
	} else {
		*code = C.Ok
	}
}

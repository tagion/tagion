package core

//#include "../c_helper.h"
import "C"
import (
	"bufio"
	"context"
	"encoding/binary"
	"fmt"
	"p2p/helper"
	"runtime"
	"time"
	"unsafe"

	"github.com/libp2p/go-libp2p"
	core "github.com/libp2p/go-libp2p-core"
	"github.com/libp2p/go-libp2p-core/event"
	libp2phost "github.com/libp2p/go-libp2p-core/host"
	"github.com/libp2p/go-libp2p-core/network"
	"github.com/libp2p/go-libp2p-core/peer"
	host "github.com/libp2p/go-libp2p-host"
	peerstore "github.com/libp2p/go-libp2p-peerstore"
	"github.com/libp2p/go-libp2p/p2p/discovery"

	multiaddr "github.com/multiformats/go-multiaddr"
	manet "github.com/multiformats/go-multiaddr-net"
)

func CreateBackgroundContext() context.Context {
	return context.Background()
}

func CreateMdnsService(ctx context.Context, node host.Host, t int32, rendezvous string) discovery.Service {
	ser, err := discovery.NewMdnsService(ctx, node, time.Millisecond*time.Duration(t), rendezvous)
	if err != nil {
		panic(err)
	}
	return ser
}

type discoveryNotifee struct {
	handlerCallback unsafe.Pointer
	tidPtr          []byte
}

func (n *discoveryNotifee) HandlePeerFound(pi peer.AddrInfo) {
	addrInfoStr := pi.String() //TODO: check marshalJson!
	addrInfoPtr := make([]byte, len(addrInfoStr))
	copy(addrInfoPtr, addrInfoStr)
	C.bridgeHandlerCallback(
		C.handlerCallback(n.handlerCallback),
		C.getDBuffer(unsafe.Pointer(&(addrInfoPtr[0])), C.int(len(addrInfoPtr))),
		C.getDBuffer(unsafe.Pointer(&(n.tidPtr[0])), C.int(len(n.tidPtr))),
		nil,
		C.ulong(1),
		C.Control_PeerDiscovered)
}

func getNotifeeHander(handler unsafe.Pointer, tid string) discoveryNotifee {
	tidPtr := make([]byte, len(tid))
	copy(tidPtr, tid)
	return discoveryNotifee{handlerCallback: handler, tidPtr: tidPtr}
}
func RegisterNotifee(service discovery.Service, handler unsafe.Pointer, tid string) discovery.Notifee {
	notifeeHanler := getNotifeeHander(handler, tid)
	service.RegisterNotifee(&notifeeHanler)
	return &notifeeHanler
}

func UnregisterNotifee(service discovery.Service, notifee discovery.Notifee) {
	service.UnregisterNotifee(notifee)
}

func CloseMdns(service discovery.Service) {
	err := service.Close()
	if err != nil {
		panic(err)
	}
}

func CreateNode(ctx context.Context, options ...libp2p.Option) host.Host {
	node, err := libp2p.New(ctx, options...)
	if err != nil {
		panic(err)
	}
	return node
}

func CloseNode(node host.Host) {
	node.Close()
}

func GetNodeId(node host.Host) string {
	return node.ID().Pretty()
}

func GetNodeAddress(node host.Host) []string {
	addrs := node.Addrs()
	addrsStr := make([]string, len(addrs))
	for i, a := range addrs {
		addrsStr[i] = a.String()
	}
	return addrsStr
}

func GetNodeAddrInfoMarshal(node host.Host) string {
	addrInfo := libp2phost.InfoFromHost(node)

	addrInfoMarshal, err := addrInfo.MarshalJSON()

	if err != nil {
		panic(err)
	}

	return string(addrInfoMarshal)
}

func GetNodePublicAddress(node host.Host) string {
	// fmt.Println("get node public addreses")
	addrs := node.Addrs()
	fmt.Println(addrs)
	for _, addr := range addrs {
		// fmt.Println(i)
		// fmt.Println(addr)
		// fmt.Println(manet.IsPublicAddr(addr))
		// fmt.Println(isTcp(addr))
		if manet.IsPublicAddr(addr) && isTcp(addr) {
			// fmt.Println("FOUND PUBLIC ADDR")
			return addr.String()
		}
	}
	// fmt.Println("Not found")
	return ""
}

func isTcp(a multiaddr.Multiaddr) bool {
	// fmt.Println("IS TCP:", a)
	found := false
	multiaddr.ForEach(a, func(c multiaddr.Component) bool {
		found = c.Protocol().Code == multiaddr.P_TCP
		return !found
	})

	// fmt.Println(found)
	return found
}

func Connect(node host.Host, ctx context.Context, address string) {
	maddr, err := multiaddr.NewMultiaddr(address)
	if err != nil {
		panic(err)
	}

	info, err := peer.AddrInfoFromP2pAddr(maddr)
	if err != nil {
		panic(err)
	}

	node.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.PermanentAddrTTL)

	if err := node.Connect(ctx, *info); err != nil {
		panic(err)
	}

	// node.Peerstore().SetProtocols(info.ID, autonat.AutoNATProto)
	// peers := node.Network().Peers()
	// fmt.Println("PROTOCOLS")
	// for _, p := range peers {
	// 	// info := node.Peerstore().PeerInfo(p)
	// 	// Exclude peers which don't support the autonat protocol.
	// 	protos, _ := node.Peerstore().GetProtocols(p)
	// 	fmt.Println(protos)
	// 	// for proto := range protos {
	// 	// 	fmt.Println("protocol: %s", proto)
	// 	// }
	// }
}

func ConnectMarshal(node host.Host, ctx context.Context, address []byte) {
	addr := peer.AddrInfo{}
	err := addr.UnmarshalJSON(address)
	if err != nil {
		panic(err)
	}

	node.Peerstore().AddAddrs(addr.ID, addr.Addrs, peerstore.PermanentAddrTTL)

	if err := node.Connect(ctx, addr); err != nil {
		panic(err)
	}
}

func SetHandler(node host.Host, address string, pids []core.ProtocolID) core.Stream {
	// printToConsole("trying to connect to" + address + " with pid: " + protocol.ConvertToStrings(([]core.ProtocolID{pid}))[0])
	maddr, err := multiaddr.NewMultiaddr(address)
	if err != nil {
		panic(err)
	}

	info, err := peer.AddrInfoFromP2pAddr(maddr)
	if err != nil {
		panic(err)
	}

	node.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.PermanentAddrTTL)
	s, err := node.NewStream(context.Background(), info.ID, pids[:]...)
	if err != nil {
		panic(err)
	}
	return s
}

func SetHandlerMarshal(node host.Host, address []byte, pids []core.ProtocolID) core.Stream {
	addr := peer.AddrInfo{}
	err := addr.UnmarshalJSON(address)
	if err != nil {
		panic(err)
	}

	node.Peerstore().AddAddrs(addr.ID, addr.Addrs, peerstore.PermanentAddrTTL)
	s, err := node.NewStream(context.Background(), addr.ID, pids[:]...)
	if err != nil {
		panic(err)
	}
	return s
}

func ResetStream(stream core.Stream) {
	helper.PrintToConsole("RESET STREAM")
	if stream != nil {
		stream.Reset()
	} else {
		helper.PrintToConsole("STREAM IS NULL")
	}
}

func CloseStream(stream core.Stream) {
	helper.PrintToConsole("CLOSE STREAM")
	if stream != nil {
		stream.Close()
	} else {
		helper.PrintToConsole("STREAM IS NULL")
	}
}

func Listen(node host.Host, pid core.ProtocolID, streamHandler network.StreamHandler) {
	// printToConsole("listen with pid: " + protocol.ConvertToStrings(([]core.ProtocolID{pid}))[0])
	node.SetStreamHandler(pid, streamHandler)
}

func ListenMatch(node host.Host, pid core.ProtocolID, streamHandler network.StreamHandler, match func(string) bool) {
	node.SetStreamHandlerMatch(pid, match, streamHandler)
}

func CloseListener(node host.Host, pid core.ProtocolID) {
	node.RemoveStreamHandler(pid)
}

func WriteStr(stream core.Stream, data string) {
	w := bufio.NewWriter(bufio.NewWriter(stream))
	_, err := w.WriteString(data)
	if err != nil {
		panic(err)
	}
	w.Flush()
	w.Reset(nil)
}

func Write(stream core.Stream, data []byte) {
	// w := bufio.NewWriter(bufio.NewWriter(stream))
	// _, err := w.Write(data)
	// if err != nil {
	// 	panic(err)
	// }
	// w.Flush()
	// w.Reset(nil)
	if stream == nil {
		panic("Stream is null")
	}
	_, err := stream.Write(data)
	if err != nil {
		panic(err)
	}
}

func SubscribeToRechabiltyEvent(host host.Host, handlerFunc unsafe.Pointer, tid string) event.Subscription {
	fmt.Println("handling for Event EvtLocalReachabilityChanged")
	eventbus := host.EventBus()
	sub, _ := eventbus.Subscribe([]interface{}{new(event.EvtLocalReachabilityChanged)})
	go subshandler(sub, handlerFunc, tid, eventbus)
	return sub
}

func subshandler(sub event.Subscription, handlerFunc unsafe.Pointer, tid string, evbus event.Bus) {
	tidPtr := make([]byte, len(tid))
	copy(tidPtr, tid)
	tidBuffer := C.getDBuffer(unsafe.Pointer(&(tidPtr[0])), C.int(len(tid)))
	defer sub.Close()
	for e := range sub.Out() {
		fmt.Println("%s", e)
		switch e := e.(type) {
		case event.EvtLocalReachabilityChanged:
			{
				fmt.Println("send event rechability update")
				r := e.Reachability
				rPtr := make([]byte, 4)
				// copy(rPtr, r[0:4])
				binary.LittleEndian.PutUint32(rPtr, uint32(r))
				rBuffer := C.getDBuffer(unsafe.Pointer(&(rPtr[0])), 4)
				fmt.Println(e)
				C.bridgeCallbackAsync(C.asyncCallback(handlerFunc), rBuffer, tidBuffer)
			}
		case event.EvtLocalAddressesUpdated:
			{
				fmt.Println("sending event")
				_ = e
				C.bridgeCallbackAsync(C.asyncCallback(handlerFunc), C.emptyDBuffer(), tidBuffer)
			}
		default:
			{
			}
		}

	}
	runtime.KeepAlive(evbus)
	runtime.KeepAlive(sub)
	fmt.Println("subscribe to rechability end")
}

func SubscribeToAddressUpdatedEvent(host host.Host, handlerFunc unsafe.Pointer, tid string) event.Subscription {
	fmt.Println("handling for Event EvtLocalAddressesUpdated")
	eventbus := host.EventBus()
	sub, _ := eventbus.Subscribe([]interface{}{new(event.EvtLocalAddressesUpdated)})
	go subshandler(sub, handlerFunc, tid, eventbus)
	return sub
}

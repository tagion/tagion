package helper

//#include "../c_helper.h"
import "C"
import (
	"bufio"
	"context"
	"crypto/rand"
	"fmt"
	"io"
	mrand "math/rand"
	"unsafe"

	"p2p/registry"

	"github.com/libp2p/go-libp2p"
	autonat "github.com/libp2p/go-libp2p-autonat"
	core "github.com/libp2p/go-libp2p-core"
	"github.com/libp2p/go-libp2p-core/event"
	"github.com/libp2p/go-libp2p-core/network"
	"github.com/libp2p/go-libp2p-core/protocol"
	crypto "github.com/libp2p/go-libp2p-crypto"
	host "github.com/libp2p/go-libp2p-host"
	"github.com/libp2p/go-libp2p/p2p/discovery"
)

func OptAddress(address string) libp2p.Option {
	return libp2p.ListenAddrStrings(address)
}
func OptIdentity(seed int) libp2p.Option {
	var r io.Reader
	if seed == 0 {
		r = rand.Reader
	} else {
		r = mrand.New(mrand.NewSource(int64(seed)))
	}
	priv, _, err := crypto.GenerateKeyPairWithReader(crypto.RSA, 2048, r)
	if err != nil {
		panic(err)
	}
	return libp2p.Identity(priv)
}

// func OptDefaultMuxer() libp2p.Option {
// 	return libp2p.Muxer(libp2p.DefaultMuxer())
// }
func OptEnableAutonat() libp2p.Option {
	PrintToConsole("Enable NAT service should be used")
	fmt.Println(libp2p.EnableNATService())
	return libp2p.EnableNATService()
}

func OptEnableAutoRelay() libp2p.Option {
	var AutoRelay = libp2p.ChainOptions(libp2p.EnableAutoRelay(), libp2p.DefaultStaticRelays())

	return AutoRelay
}

func OptEnableNATPortMap() libp2p.Option {
	return libp2p.NATPortMap()
}

func GetPid(pid string) core.ProtocolID {
	return protocol.ConvertFromStrings(([]string{pid}))[0]
}

func GetHandler(handlerFunc unsafe.Pointer, tid string, timeout int32, maxSize int32, id *uint64) network.StreamHandler {
	return func(s network.Stream) {
		PrintToConsole(fmt.Sprint(id))
		nid := id
		if nid == nil {
			nid = new(uint64)
			*nid = GetIdentifier()
		}
		PrintToConsole("Connected with id: " + fmt.Sprint(*nid))
		tidPtr := make([]byte, len(tid))
		copy(tidPtr, tid)
		tidBuffer := C.getDBuffer(unsafe.Pointer(&(tidPtr[0])), C.int(len(tid)))
		registry.Register(unsafe.Pointer(&s))
		C.bridgeHandlerCallback(C.handlerCallback(handlerFunc), C.emptyDBuffer(), tidBuffer, unsafe.Pointer(&s), C.ulong(*nid), C.Control_Connected)
		// if err := s.SetDeadline(time.Now().Add(time.Millisecond * time.Duration(timeout))); err != nil {
		// 	s.Reset()
		// 	return
		// }
		go handle(handlerFunc, tidBuffer, s, maxSize, *nid)
	}
}

func handle(cb unsafe.Pointer, tid C.DBuffer, s network.Stream, maxSize int32, id uint64) {
	defer func() {
		if r := recover(); r != nil {
			PrintToConsole("Recovered err: %s", r)
			// C.bridgeHandlerCallback(C.handlerCallback(cb), C.emptyDBuffer(), tid, nil, C.ulong(id), C.Control_Disconnected)
		}
	}()
	const size_bytes = 4
	r := bufio.NewReader(bufio.NewReader(s))
	for {
		var result uint64
		var shift uint
		is_err := false
		head := make([]byte, 9)
		i := 0
		for {
			b, err := r.ReadByte()
			if i >= 9 {
				PrintToConsole("LEB128 overflow")
				is_err = true
				break
			}
			head[i] = b
			i++
			if err != nil {
				PrintToConsole(err.Error())
				is_err = true
				break
			}
			result |= (uint64(0x7F & b)) << shift
			PrintToConsole("result:", result)
			if b&0x80 == 0 {
				break
			}
			shift += 7
		}
		PrintToConsole("breaked ", result)
		if is_err {
			break
		}
		trimed_head := make([]byte, i)
		for x := 0; x < i; x++ {
			trimed_head[x] = head[x]
		}
		buflen := result
		// PrintToConsole("BUFFER len: " + strconv.FormatUint(uint64(buflen), 10))
		if buflen > uint64(maxSize) {
			PrintToConsole("Response is too long %d %d", buflen, uint64(maxSize))
			break
		}
		if buflen != 0 {
			body := make([]byte, buflen)
			if _, err := io.ReadFull(r, body); err != nil {
				PrintToConsole("Read error")
				break
			}
			response := append(trimed_head, body...)
			// fmt.Println("Received in id: ", id)
			C.bridgeHandlerCallback(C.handlerCallback(cb), C.getDBuffer(unsafe.Pointer(&(response[0])), C.int(len(response))), tid, unsafe.Pointer(&s), C.ulong(id), C.Control_RequestHandled)
		}
	}
	C.bridgeHandlerCallback(C.handlerCallback(cb), C.emptyDBuffer(), tid, nil, C.ulong(id), C.Control_Disconnected)
}
func GetMatch(protocolIds []string) func(string) bool {
	return func(protocolId string) bool {
		PrintToConsole("Trying to match:", protocolId, " with :", protocolIds)
		for _, n := range protocolIds {
			if protocolId == n {
				return true
			}
		}
		return false
	}
}
func PrintToConsole(a ...interface{}) {
	fmt.Print("FROM GO: ")
	fmt.Println(a...)
}

func ConvertToContext(pointer unsafe.Pointer) context.Context {
	return *(*context.Context)(pointer)
}

func ConvertToMdnsService(pointer unsafe.Pointer) discovery.Service {
	return *(*discovery.Service)(pointer)
}

func ConvertToNode(pointer unsafe.Pointer) host.Host {
	return *(*host.Host)(pointer)
}

func ConvertToStream(pointer unsafe.Pointer) core.Stream {
	return *(*core.Stream)(pointer)
}

func ConvertToOption(pointer unsafe.Pointer) libp2p.Option {
	return *(*libp2p.Option)(pointer)
}

func ConvertToSubscription(pointer unsafe.Pointer) event.Subscription {
	return *(*event.Subscription)(pointer)
}

func ConvertToNotifee(pointer unsafe.Pointer) discovery.Notifee {
	return *(*discovery.Notifee)(pointer)
}

func ConvertToAutoNAT(pointer unsafe.Pointer) autonat.AutoNAT {
	return *(*autonat.AutoNAT)(pointer)
}

func ConvertToAutonatOption(pointer unsafe.Pointer) autonat.Option {
	return *(*autonat.Option)(pointer)
}

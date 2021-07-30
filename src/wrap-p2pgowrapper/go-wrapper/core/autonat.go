package core

//#include "../c_helper.h"
import "C"
import (
	"context"
	"fmt"
	"time"

	autonat "github.com/libp2p/go-libp2p-autonat"
	"github.com/libp2p/go-libp2p-core/network"
	host "github.com/libp2p/go-libp2p-host"
)

func CreateAutoNAT(ctx context.Context, node host.Host, options ...autonat.Option) autonat.AutoNAT {
	fmt.Println(len(options))
	nat, err := autonat.New(ctx, node, options...)
	if err != nil {
		panic(err)
	}
	return nat
}

func GetAutoNATAddress(nat autonat.AutoNAT) string {
	addr, err := nat.PublicAddr()
	if err != nil {
		panic(err)
	}
	return addr.String()
}

func GetAutoNATStatus(nat autonat.AutoNAT) int {
	return (int)(nat.Status())
}

func OptEnableService(net network.Network) autonat.Option {
	return autonat.EnableService(net)
}

func OptWithoutStartupDelay() autonat.Option {
	return autonat.WithoutStartupDelay()
}

func OptWithSchedule(retryInterval int32, refreshInterval int32) autonat.Option {
	return autonat.WithSchedule(time.Millisecond*time.Duration(retryInterval), time.Millisecond*time.Duration(refreshInterval))
}

// func OptEnableSelfDials() autonat.Option {
// 	return func(c *config) error {
// 		c.dialPolicy.allowSelfDials = true
// 		return nil
// 	}
// }

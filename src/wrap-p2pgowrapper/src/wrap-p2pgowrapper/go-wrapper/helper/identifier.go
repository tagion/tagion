package helper

import (
	"sync"
)

var id uint64
var mux sync.Mutex

const maxId = ^uint64(0)

func GetIdentifier() uint64 {
	defer mux.Unlock()
	mux.Lock()
	if id >= maxId { //manual overflow checking
		id = 1
	} else {
		id++
	}

	return id
}

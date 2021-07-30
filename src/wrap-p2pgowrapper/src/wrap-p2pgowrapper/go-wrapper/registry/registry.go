package registry

import (
	"strconv"
	"sync"
	"unsafe"
)

type pointerCounter struct {
	ptr   unsafe.Pointer
	count int
}

func (c *pointerCounter) inc() {
	c.count += 1
}
func (c *pointerCounter) dec() {
	c.count -= 1
}
func (c *pointerCounter) isUntracked() bool {
	return c.count <= 0
}
func (c *pointerCounter) String() string {
	return strconv.Itoa(c.count)
}

func newPointerCounter(ptr unsafe.Pointer) pointerCounter {
	return pointerCounter{ptr: ptr, count: 1}
}

var pointers map[unsafe.Pointer]pointerCounter = make(map[unsafe.Pointer]pointerCounter)
var mux sync.Mutex

func Register(pointer unsafe.Pointer) {
	mux.Lock()
	defer mux.Unlock()
	if pointerCounter, contains := pointers[pointer]; contains {
		pointerCounter.inc()
		pointers[pointer] = pointerCounter
	} else {
		pointers[pointer] = newPointerCounter(pointer)
	}
	// fmt.Println("FROM GO: registry: ", len(pointers))
}

func Unregister(pointer unsafe.Pointer) {
	mux.Lock()
	defer mux.Unlock()
	if pointerCounter, contains := pointers[pointer]; contains {
		pointerCounter.dec()
		pointers[pointer] = pointerCounter
		if pointerCounter.isUntracked() {
			delete(pointers, pointer)
		}
		// fmt.Println("FROM GO: unregistry: ", len(pointers))
	}
}

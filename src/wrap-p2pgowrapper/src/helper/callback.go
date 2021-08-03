package helper

//#include "../c_helper.h"
import "C"
import (
	"unsafe"
)

type Callback struct {
	CallbackFunction unsafe.Pointer
	Context          unsafe.Pointer
}

# HiBON API

The [HiBON](documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) is the fundametal data format use in Tagion network.
This document descript the requenment for the API to read and constuct a HiBON. 

The API should be able to add any HiBON types script in [HiBON](documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) and [HiBON_JSON_format](/documents/protocols/hibon/HiBON_JSON_format.md).

The library should implement a `class HiBON`  
This class should include method for set all types of HiBON. 
Sample of setting 
```
enum Types {
....
}
let h=new HiBON;
h.set("I32", Types.i32, -42);
```
Set an sub HiBON.
```
let sub_hibon=new HiBON;
let h=new HiBON;
h.set("sub_hibon", Types.document, sub_hibon);
```

To get from HiBON 
```
let val=h.get("i32", Types.i32);
```

The library should be able to produces the sample shown in [HiBON_JSON_format](/documents/protocols/hibon/HiBON_JSON_format.md).
- Note. The samples can be generated via `hibonutil --sample`.




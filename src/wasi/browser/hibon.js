export class HiBON {

  constructor(_instance, _ptr) {
    this.instance = _instance;
    this.ptr = _ptr;
    this.instance.exports.tagion_hibon_create(this.ptr);
  }

  #get_stuff(str) {
    // const encoder = new TextEncoder();
    // const encodedString = encoder.encode(str); // Encode the JavaScript string into Uint8Array
    // const length = encodedString.length;
    // const ptr = Module._malloc(length + 1); // Allocate memory in wasm module (+1 for null terminator)
    
    // // Copy the encoded string to the wasm memory
    // for (let i = 0; i < length; i++) {
    //     Module.HEAPU8[ptr + i] = encodedString[i];
    // }
    // Module.HEAPU8[ptr + length] = 0; // Null-terminate the string

    const encodedString = encoder.encode(str); // Encode the JavaScript string into Uint8Array
    const length = encodedString.length;
    const some_ptr = instance.exports.malloc(length);

    
    return { ptr: ptr, len: length };
  }

  addString(key, value) {


    
    // const keyStr = this.#get_stuff(key);
    // const valueStr = this.#get_stuff(value);
     
    const result = this.instance.exports.tagion_hibon_add_string(this.ptr, keyStr.ptr, keyStr.length, valueStr.ptr, valueStr.length);
    Module._free(keyStr.ptr); 
    Module._free(valueStr.ptr);
  }

  // toPretty() {
  //   const strPtrPtr = Module._malloc(4); 
  //   const strLenPtr = Module._malloc(4); 

  //   const result = this.instance.exports.tagion_hibon_get_text(this.ptr, 1, strPtrPtr, strLenPtr); 

  //   const strPtr = Module.getValue(strPtrPtr, 'i32');
  //   const strLen = Module.getValue(strLenPtr, 'i32');

  //   // Convert the C string to a JavaScript string
  //   const text = Module.UTF8ToString(strPtr, strLen);
  //   console.log(text);
  // }


    
  


  



}

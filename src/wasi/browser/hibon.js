export class HiBON {

  constructor(_instance, _ptr) {
    this.instance = _instance;
    this.ptr = _ptr;

    console.log("before tagion_hibon_create");
    this.instance.exports.tagion_hibon_create(this.ptr);
  }
  _allocateStr(toEncode) {
    const textEncoder = new TextEncoder();
    const encoded = textEncoder.encode(toEncode);
    console.log("before malloc");
    const ptr = this.instance.exports.mymalloc(encoded.byteLength);

    const memory = new Uint8Array(this.instance.exports.memory.buffer);
    memory.set(encoded, ptr);
    return { encoded: encoded, ptr: ptr, len: encoded.byteLength };
  }
  addString(key, value) {
    const _key = this._allocateStr(key);
    const _value = this._allocateStr(value);
    const res = this.instance.exports.tagion_hibon_add_string(this.ptr, _key.ptr, _key.len, _value.ptr, _value.len);
    console.log("tagion_hibon_add_string returned: ", res);
  }
  addBool(key, value) {
    const _key = this._allocateStr(key);
    const res = this.instance.exports.tagion_hibon_add_bool(this.ptr, _key.ptr, _key.len, value);
  }
  addInt32(key, value) {
    const _key = this._allocateStr(key);
    const res = this.instance.exports.tagion_hibon_add_int32(this.ptr, _key.ptr, _key.len, value);
  }
  // addInt64(key, value) {
  //   const _key = this._allocateStr(key);

  //   const buffer = new ArrayBuffer(8); // 8 bytes 
  //   const view = new DataView(buffer);
  //   view.setBigInt64(0, BigInt(value), true); // TODO: true for little endian what about big endian

  //   // Get the low and high 32-bit parts of the int64_t value
  //   const lowPart = view.getInt32(0, true); // true for little-endian
  //   const highPart = view.getInt32(4, true); // true for little-endian

  //   // Call the exported function with the low and high parts
  //   const res = this.instance.exports.tagion_hibon_add_int64(this.ptr, _key.ptr, _key.len, lowPart, highPart);
  // }


  toPretty() {
    const textFormat = 1;
    const strPtrPtr = this.instance.exports.mymalloc(4); // Pointer to char* (4 bytes)
    const strLenPtr = this.instance.exports.mymalloc(4); // Pointer to size_t (4 bytes)
    console.log("strPtrPtr ", strPtrPtr);
    console.log("strLenPtr ", strLenPtr);
    
    const result = this.instance.exports.tagion_hibon_get_text(this.ptr, textFormat, strPtrPtr, strLenPtr);
    console.log(result);
    const strPtr = new Uint32Array(this.instance.exports.memory.buffer, strPtrPtr, 1)[0];
    const strLen = new Uint32Array(this.instance.exports.memory.buffer, strLenPtr, 1)[0];

    
    const memory = new Uint8Array(this.instance.exports.memory.buffer);
    const stringBytes = memory.subarray(strPtr, strPtr + strLen);
    const decodedString = new TextDecoder().decode(stringBytes);
    console.log(decodedString);
    // TODO: free pointers
  }


  

}

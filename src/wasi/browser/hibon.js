export class HiBON {

  constructor(_instance, _ptr) {
    this.instance = _instance;
    this.ptr = _ptr;

    console.log("before tagion_hibon_create");
    this.instance.exports.tagion_hibon_create(this.ptr);
  }
  _allocateEncodedKey(toEncode) {
    const textEncoder = new TextEncoder();
    const encoded = textEncoder.encode(toEncode);
    console.log("before malloc");
    const ptr = this.instance.exports.mymalloc(encoded.byteLength);
    return { encoded: encoded, ptr: ptr, len: encoded.byteLength };
  }

  addString(key, value) {
    const _key = this._allocateEncodedKey(key);
    const _value = this._allocateEncodedKey(value);

    const memory = new Uint8Array(this.instance.exports.memory.buffer);
    memory.set(_key.encoded, _key.ptr);
    memory.set(_value.encoded, _value.ptr);

    const res = this.instance.exports.tagion_hibon_add_string(this.ptr, _key.ptr, _key.len, _value.ptr, _value.len);
    // TODO: free pointers

    console.log("tagion_hibon_add_string returned: ", res);
  }
  addBool(key, value) {
    const _key = this._allocateEncodedKey(key);
    const memory = new Uint8Array(this.instance.exports.memory.buffer);
    memory.set(_key.encoded, _key.ptr);

    const res = this.instance.exports.tagion_hibon_add_bool(this.ptr, _key.ptr, _key.len, value);
  }

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

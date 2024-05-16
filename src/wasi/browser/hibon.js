export class HiBON {

  static HIBONTSIZE = 4+4;

  constructor(_instance) {
    this.instance = _instance;

    this.ptr = this.instance.exports.mymalloc(HiBON.HiBONTSIZE);
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
    console.log("tagion_hibon_add_int32 returned ", res);
  }
  addInt64(key, value) {
    const _key = this._allocateStr(key);
    const valuePtr = this.instance.exports.mymalloc(8);
    const memory = new DataView(this.instance.exports.memory.buffer);
    memory.setBigInt64(valuePtr, value, true);
    const res = this.instance.exports.tagion_hibon_add_array_int64(this.ptr, _key.ptr, _key.len, valuePtr, 8);
    console.log("tagion_hibon_add_int64 returned ",res);
  }
  addUint32(key, value) {
    const _key = this._allocateStr(key);
    const valuePtr = this.instance.exports.mymalloc(4);
    const memory = new DataView(this.instance.exports.memory.buffer);
    memory.setUint32(valuePtr, value, true);
    const res = this.instance.exports.tagion_hibon_add_array_uint32(this.ptr, _key.ptr, _key.len, valuePtr, 4);
    console.log("tagion_hibon_add_uint32 returned: ", res);
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
    return decodedString;
    // TODO: free pointers
  }

  toDoc() {
    const bufPtrPtr = this.instance.exports.mymalloc(4); // pointer to uint8_t (4 bytes)
    const bufLenPtr = this.instance.exports.mymalloc(4); // pointer to size_t

    const result = this.instance.exports.tagion_hibon_get_document(this.ptr, bufPtrPtr, bufLenPtr);
    console.log("tagion_hibon_get_document returned: ", result);
    const bufPtr = new Uint32Array(this.instance.exports.memory.buffer, bufPtrPtr, 1)[0];
    const bufLen = new Uint32Array(this.instance.exports.memory.buffer, bufLenPtr, 1)[0];
    return { ptr: bufPtr, len: bufLen };
  }
  
}

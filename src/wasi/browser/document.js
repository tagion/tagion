export class Document {

  constructor(_instance, doc_ptr, doc_len) {
    this.instance = _instance;
    this.ptr = doc_ptr;
    this.len = doc_len;
  }

  // duplicated func
  _allocateStr(toEncode) {
    const textEncoder = new TextEncoder();
    const encoded = textEncoder.encode(toEncode);
    console.log("before malloc");
    const ptr = this.instance.exports.mymalloc(encoded.byteLength);

    const memory = new Uint8Array(this.instance.exports.memory.buffer);
    memory.set(encoded, ptr);
    return { encoded: encoded, ptr: ptr, len: encoded.byteLength };
  }

  _getDocElement(key) {
    const _key = this._allocateStr(key);

    // allocate the Document.Element ptr
    const doc_elem_ptr = this.instance.exports.mymalloc(4);


    const res = this.instance.exports.tagion_document(this.ptr, this.len, _key.ptr, _key.len, doc_elem_ptr);

    console.log("tagion_document returned: ", res);

    const docPtr = new Uint32Array(this.instance.exports.memory.buffer, doc_elem_ptr, 1)[0];

    console.log("docptr: ", docPtr);
    return docPtr;
  }

  getString(key) {
    const elemPtr = this._getDocElement(key);

    
    const strPtrPtr = this.instance.exports.mymalloc(4); // Pointer to char* (4 bytes)
    const strLenPtr = this.instance.exports.mymalloc(4); // Pointer to size_t (4 bytes)

    const res = this.instance.exports.tagion_document_get_string(elemPtr, strPtrPtr, strLenPtr);

    console.log("tagion_document_get_string returned: ", res);
    const strPtr = new Uint32Array(this.instance.exports.memory.buffer, strPtrPtr, 1)[0];
    const strLen = new Uint32Array(this.instance.exports.memory.buffer, strLenPtr, 1)[0];
    const memory = new Uint8Array(this.instance.exports.memory.buffer);
    const stringBytes = memory.subarray(strPtr, strPtr + strLen);
    const decodedString = new TextDecoder().decode(stringBytes);
    console.log(decodedString);

  }

  // addString(key, value) {
  //   const _key = this._allocateStr(key);
  //   const _value = this._allocateStr(value);
  //   const res = this.instance.exports.tagion_hibon_add_string(this.ptr, _key.ptr, _key.len, _value.ptr, _value.len);
  //   console.log("tagion_hibon_add_string returned: ", res);
  // }

}

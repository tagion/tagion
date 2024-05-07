export class HiBON {

  constructor(_instance, _ptr) {
    this.instance = _instance;
    this.ptr = _ptr;

    console.log("before tagion_hibon_create");
    this.instance.exports.tagion_hibon_create(this.ptr);
  }

  addString(key, value) {
    const textEncoder = new TextEncoder();
    const encodedKey = textEncoder.encode(key);
    const encodedValue = textEncoder.encode(value);

    console.log("before addstring malloc");
    const keyPtr = this.instance.exports.mymalloc(encodedKey.byteLength);
    const valuePtr = this.instance.exports.mymalloc(encodedValue.byteLength);

    const memory = new Uint8Array(this.instance.exports.memory.buffer);

    memory.set(encodedKey, keyPtr);
    memory.set(encodedValue, valuePtr);

    let res = this.instance.exports.tagion_hibon_add_string(this.ptr, keyPtr, encodedKey.byteLength, valuePtr, encodedValue.byteLength);

    console.log("tagion_hibon_add_string returned: ", res);
  }

}



encodeBase64url(_instance, ptr, len) {

    const memory = new Uint8Array(_instance.exports.memory.buffer);
    const stringBytes = memory.subarray(ptr, ptr + len);
    const decodedString = new TextDecoder().decode(stringBytes);


}

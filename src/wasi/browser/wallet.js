export class Wallet {
  static WALLETSIZE = 4+4;

  constructor(_instance) {
    this.instance = _instance;
    this.ptr = this.instance.exports.mymalloc(Wallet.WALLETSIZE);
    console.log("before wallet create instance");
    const res = this.instance.exports.tagion_wallet_create_instance(this.ptr);
    console.log("tagion_wallet_create_instance returned: ", res);
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

  createWallet(passphrase, pincode) {
    const _passphrase = this._allocateStr(passphrase);
    const _pincode = this._allocateStr(pincode);

    const res = this.instance.exports.tagion_wallet_create_wallet(this.ptr, _passphrase.ptr, _passphrase.len, _pincode.ptr, _pincode.len);

    console.log("tagion_wallet_create_wallet returned ", res);
  }

  getAccount() {
    const accountPtrPtr = this.instance.exports.mymalloc(4);
    const accountLenPtr = this.instance.exports.mymalloc(4);

    const result = this.instance.exports.tagion_wallet_get_account(this.ptr, accountPtrPtr, accountLenPtr);
    console.log("tagoin_wallet_get_account returned ", result);

    const accountPtr = new Uint32Array(this.instance.exports.memory.buffer, accountPtrPtr, 1)[0];
    const accountLen = new Uint32Array(this.instance.exports.memory.buffer, accountLenPtr, 1)[0];

    console.log(accountPtr, accountLen);
  }
  




}

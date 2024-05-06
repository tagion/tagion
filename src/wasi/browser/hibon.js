export class HiBON {

  constructor(_instance, _ptr) {
    this.instance = _instance;
    this.ptr = _ptr;

    console.log("first call");
    const woow = this.instance.exports.mymalloc(20);
    console.log("ptr ", woow);
    console.log("before tagion_hibon_create");
    this.instance.exports.tagion_hibon_create(this.ptr);
  }

  addString(key, value) {
    const textEncoder = new TextEncoder();
    const encodedKey = textEncoder.encode(key);
    const encodedValue = textEncoder.encode(value);


    console.log(this.instance.exports);
    console.log(this.instance.exports.rt_init);
    const x = 10;

    console.log("before addstring malloc");

    const woow = this.instance.exports.mymalloc(20);
    // const keyPtr = this.instance.exports.mymalloc(20);
    // console.log("keyPtr: ", keyPtr);

    // const memory = new Uint8Array(this.#instance.exports.memory.buffer);
    // const keyPtr = 10;
    // const valuePtr = keyPtr + encodedKey.byteLength;
    // memory.set(encodedKey, keyPtr);
    // memory.set(encodedValue, valuePtr);

		



  }

  // addString(key, value) {
  //   const textEncoder = new TextEncoder();

  //   const encodedKey = textEncoder.encode(key);
  //   const encodedValue = textEncoder.encode(value);

  //   try {
  //     const keyPtr = 10;
  //     const valuePtr = keyPtr + encodedKey.byteLength;


  //     console.log(keyPtr);
  //     console.log(valuePtr);

  //     const memory = new Uint8Array(this.instance.exports.memory.buffer);
      
  //     memory.set(encodedKey, keyPtr);
  //     memory.set(encodedValue, valuePtr);



     
  //     // // Allocate memory for the key string
  //     // const keyPtr = this.allocateString(encodedKey);

  //     // // Allocate memory for the value string
  //     // const valuePtr = this.allocateString(encodedValue);

  //     // Call the 'tagion_hibon_add_string' function in the Wasm module
  //     this.instance.exports.tagion_hibon_add_string(
  //       this.ptr,
  //       keyPtr,
  //       encodedKey.length, // Pass the length of the key string
  //       valuePtr,
  //       encodedValue.length // Pass the length of the value string
  //     );

  //     console.log('Strings added successfully');
  //   } catch (error) {
  //     console.error('Error adding strings:', error);
  //   }
  // }

  // allocateString(encodedString) {
  //   // Determine the byte length of the encoded string
  //   const byteLength = encodedString.byteLength;

  //   // Grow memory to accommodate the string if needed
  //   this.growMemoryIfNeeded(byteLength);

  //   // Get the memory buffer
  //   const memory = new Uint8Array(this.instance.exports.memory.buffer);

  //   // Allocate memory for the string at the end of the memory buffer
  //   const stringPtr = memory.length - byteLength;

  //   // Copy the encoded string bytes into the allocated memory
  //   memory.set(encodedString, stringPtr);

  //   return stringPtr;
  // }

  // growMemoryIfNeeded(byteLength) {
  //   const pageSize = 65536; // 64 KB per page
  //   const requiredPages = Math.ceil(byteLength / pageSize);

  //   // Attempt to grow memory by the required number of pages
  //   this.instance.exports.memory.grow(requiredPages);
  // }

}


// export class HiBON {

//   constructor(_instance, _ptr) {
//     this.instance = _instance;
//     this.ptr = _ptr;
//     this.instance.exports.tagion_hibon_create(this.ptr);
//   }

//   addString(key, value) {
//     const textEncoder = new TextEncoder();

//     // Encode the key and value strings to UTF-8
//     const encodedKey = textEncoder.encode(key);
//     const encodedValue = textEncoder.encode(value);

//     // Determine the byte length of the encoded strings
//     const keyByteLength = encodedKey.byteLength;
//     const valueByteLength = encodedValue.byteLength;

//     try {
//       // Calculate the number of pages needed to accommodate the encoded strings
//       const pageSize = 65536; // 64 KB per page
//       const requiredPages = Math.ceil((keyByteLength + valueByteLength) / pageSize);

//       // Attempt to grow memory by the required number of pages
//       this.instance.exports.memory.grow(requiredPages);

//       // Get the memory buffer
//       const memory = new Uint8Array(this.instance.exports.memory.buffer);

//       // Allocate memory for the key and value strings at the end of the memory buffer
//       const keyPtr = memory.length - keyByteLength;
//       const valuePtr = keyPtr - valueByteLength;

//       // Copy the encoded key and value bytes into the allocated memory
//       memory.set(encodedKey, keyPtr);
//       memory.set(encodedValue, valuePtr);

//       // Call the 'tagion_hibon_add_string' function in the Wasm module
//       console.log("before func");
//       this.instance.exports.tagion_hibon_add_string(
//         this.ptr,
//         keyPtr,
//         keyByteLength,
//         valuePtr,
//         valueByteLength
//       );

//       console.log('String added successfully');
//     } catch (error) {
//       console.error('Error adding string:', error);
//     }
//   }

// }

// // export class HiBON {

// //   constructor(_instance, _ptr) {
// //     this.instance = _instance;
// //     this.ptr = _ptr;
// //     this.instance.exports.tagion_hibon_create(this.ptr);
// //   }

// //   addString(key, value) {
// //     const textEncoder = new TextEncoder();

// //     const encodedKey = textEncoder.encode(key);
// //     const encodedValue = textEncoder.encode(value);

// //     const keyByteLength = encodedKey.byteLength;
// //     const valueByteLength = encodedValue.byteLength;




    

// //     // try {
// //     //   const keyPtr = this.instance.exports.memory.grow(Math.ceil(keyByteLength / 65536));
// //     //   const valuePtr = this.instance.exports.memory.grow(Math.ceil(valueByteLength / 65536));

// //     //   if (!keyPtr || !valuePtr) {
// //     //     throw new Error('Memory allocation failed');
// //     //   }

// //     //   const memory = new Uint8Array(this.instance.exports.memory.buffer);

// //     //   memory.set(encodedKey, keyPtr);
// //     //   memory.set(encodedValue, valuePtr);

// //     //   console.log(`${this.ptr}, ${keyPtr}, ${keyByteLength}, ${valuePtr}, ${valueByteLength}`);
// //     //   console.log(this.instance.exports.tagion_hibon_add_string);

// //     //   const test = this.instance.exports.tagion_hibon_add_string(
// //     //     this.ptr,
// //     //     keyPtr,
        
// //     //   );

// //     //   console.log('String added successfully');
// //     // } catch (error) {
// //     //   console.error('Error adding string:', error);
// //     // }
// //   }

// // }

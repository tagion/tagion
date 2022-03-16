module tagion.mobile;

// pragma(msg, "fixme(cbr): __sF is a hack to should the linking in Android");
// extern(C) {
//     void* __sF;
// // ./toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/unistd.h:76
//     char** environ;
// // ./toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/netdb.h:200
//     struct addrinfo;
//     void freeaddrinfo(addrinfo* __ptr) {
//         assert(0, "ERROR: Android freeaddrinfo link problem");
//     }
// }

import tagion.mobile.DocumentWrapperApi;
import tagion.utils.Gene;
import tagion.logger.Logger;
import core.thread.fiber;

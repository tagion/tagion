/// \file platform.d

module tagion.betterC.utils.platform;

public {

    extern(C) void _d_array_slice_copy(void* dst, size_t dstlen, void* src, size_t srclen, size_t elemsz) {
        version(LDC) {
            import ldc.intrinsics : llvm_memcpy;
            llvm_memcpy!size_t(dst, src, dstlen * elemsz, 0);
        }
    }

    // extern(C) void* __tls_get_addr (void* ptr) {
    //     import core.stdc.stdio;
    //     import core.stdc.stdlib;

    //     fprintf(stderr, "__tls_get_addr called\n");
    //     exit(0);
    //     return null;
    // }

    version (WebAssembly) {
        pragma(msg, "WebAssembler Memory");
    @nogc:
        void* calloc(size_t nmemb, size_t size);
        void* realloc(void* ptr, size_t size);
        void free(void* ptr);
        // void __assert(bool flag);
    }
    else {

        import core.stdc.stdlib : calloc, realloc, free;
        import core.stdc.stdio;
    }
}

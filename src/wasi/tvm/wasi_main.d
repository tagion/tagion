module tvm.wasi_main;
import core.stdc.stdio;
import core.internal.backtrace.unwind;
import core.runtime;
import core.sys.wasi.missing;
import core.sys.wasi.link;
extern (C) @nogc {
       // extern(C) int nativeCallback(dl_phdr_info* info, size_t, void* data)
    int dl_iterate_phdr(dl_iterate_phdr_cb __callback, void*__data) {
        printf("%s %p callback=%p\n", &__FUNCTION__[0], __data, &__callback);
        return __callback(null, 0, __data);
    }
    const(char)* getprogname() nothrow {
        return "_progname".ptr;
    }
    void _Unwind_Resume(void* x) {
        printf("%s\n", &__FUNCTION__[0]);
    }

    void _Unwind_DeleteException(_Unwind_Exception* exception_object) {
        printf("%s\n", &__FUNCTION__[0]);

    }

    _Unwind_Reason_Code _Unwind_RaiseException(_Unwind_Exception* exception_object) {
        printf("%s\n", &__FUNCTION__[0]);
        return _Unwind_Reason_Code(0);
    }

    _Unwind_Ptr _Unwind_GetIP(_Unwind_Context* context) {
        printf("%s\n", &__FUNCTION__[0]);
        return _Unwind_Ptr.init;
    }

    void _Unwind_SetIP(_Unwind_Context* context, _Unwind_Ptr new_value) {
        printf("%s\n", &__FUNCTION__[0]);
    }

    void _Unwind_SetGR(_Unwind_Context* context, int index, _Unwind_Word new_value) {
        printf("%s\n", &__FUNCTION__[0]);

    }

    _Unwind_Ptr _Unwind_GetRegionStart(_Unwind_Context* context) {
        printf("%s\n", &__FUNCTION__[0]);
        return _Unwind_Ptr.init;
    }

    void* _Unwind_GetLanguageSpecificData(_Unwind_Context*) {
        printf("%s\n", &__FUNCTION__[0]);
        return null;
    }

    import core.sys.wasi.dirent;

    dirent* readdir64(DIR*) {
        mixin WASIError;
        assert(0, wasi_error);
    }

    version (none) extern (C) void flockfile(FILE* file) {
        //printf("%s\n", &__FUNCTION__[0]);
    }

    version (none) extern (C) void funlockfile(FILE* file) {
        //printf("%s\n", &__FUNCTION__[0]);
    }

    extern (C) void tzset() {
        printf("%s\n", &__FUNCTION__[0]);
    }

    int _error_code;
    ref int _errno() {
        return _error_code;
    }

    int lockf(int x, int y, int z) {
        printf("%s\n", &__FUNCTION__[0]);
        assert(0, "Not implemented");
    }

    void __multi3(int, long, long, long, long) {
        printf("%s\n", &__FUNCTION__[0]);
        assert(0, "Not implemented");
    }

    import rt.sections_wasm : tls_index;

     void* __tls_get_addr(tls_index* ti) nothrow {
        return null;
    }

    FILE* tmpfile() {
        mixin WASIError;
        assert(0, wasi_error);
    }


    int getentropy(void *, size_t);
    size_t getrandom(void* buf, size_t size, uint) {
        getentropy(buf, size);
        return size;
    }

    int execv(const scope char*, const scope char**) {
        mixin WASIError;
        assert(0, wasi_error);
    }

    int execve(scope const(char)*, scope const(char*)*, scope const(char*)*) {
        mixin WASIError;
        assert(0, wasi_error);
    }

    int execvp(const scope char*, const scope char**) {
        mixin WASIError;
        assert(0, wasi_error);
    }
    import core.sys.wasi.unistd;
    pid_t   getpid() @trusted {
        mixin WASIError;
        printf("%s", &wasi_error[0]);
        return 42;
    }
}

extern (C) int _Dmain(char[][] args);
extern (C) void _start() {
    //rt_init;
    // scope(exit) {
    //  rt_term;
    // }
    //    printf("Hello _start\n");
    import rt.dmain2;

    //const run_ptr=&_d_run_main;
    //    printf("%p\n", run_ptr);
    _d_run_main(0, null, &_Dmain);
}

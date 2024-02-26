module foundation.wasi_main;
import core.stdc.stdio;

extern(C) @nogc {
void _Unwind_Resume(void* x) {
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
extern(C) void* __tls_get_addr(tls_index* ti) nothrow @nogc {
    return null;
}
}

extern(C) int _Dmain(char[][] args);
extern(C) void _start() {
    printf("Hello _start\n");
    import rt.dmain2;
    const run_ptr=&_d_run_main;
    printf("%p\n", run_ptr);
    _d_run_main(0, null, &_Dmain);
}

module hibon.utils.platform;


public {
version(WebAssembly) {
    pragma(msg, "WebAssembler Memory");
extern(C):
    @nogc:
    void* calloc(size_t nmemb, size_t size);
    void* realloc(void* ptr, size_t size);
    void free(void* ptr);
    void __assert(bool flag);
}
else {

        import core.stdc.stdlib : calloc,  realloc, free;
        import core.stdc.stdio;
    }
}

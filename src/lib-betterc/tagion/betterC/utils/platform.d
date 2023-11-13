module tagion.betterC.utils.platform;

public {

    extern (C) void _d_array_slice_copy(void* dst, size_t dstlen, void* src, size_t srclen, size_t elemsz) {
        import std.compiler;

        static if ((version_major == 2 && version_minor >= 100) || (vendor !is Vendor.llvm)) {
            pragma(msg, "Warning llvm_memcpy has not been enabled for ", vendor, " version ", version_major, ".", version_minor,);
        }
        else {
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

        import core.stdc.stdio;
        import core.stdc.stdlib : calloc, free, realloc;
    }
}

import std.meta;
import std.traits;

static void _static_call_all(string tocall, string namespace, Modules...)() {
    static foreach (module_; Modules) {
        {
            enum import_code = "import" ~ module_.stringof["module".length .. $] ~ ";";
            mixin(import_code);
            void _static_caller(string[] members, string namespace = null)() {
                static foreach (name; members) {
                    {
                        enum fullname = (namespace is null) ? name : namespace ~ "." ~ name;

                        static if ((name.length > tocall.length) && (
                                name[0 .. tocall.length] == tocall)) {
                            enum call_code = fullname ~ "();";
                            mixin(call_code);
                        }
                        else {
                            enum is_code = "enum isType =is(" ~ fullname ~ ");";
                            mixin(is_code);
                            static if (isType) {
                                {
                                    enum type_code = "alias Type =" ~ fullname ~ ";";
                                    mixin(type_code);

                                    _static_caller!([__traits(allMembers, Type)], fullname);
                                }
                            }
                        }
                    }
                }
            }

            _static_caller!([__traits(allMembers, module_)]);
        }
    }
}

alias _call_static_ctor(Modules...) = _static_call_all!("_staticCtor", "", Modules);

alias _call_static_dtor(Modules...) = _static_call_all!("_staticDtor", "", Modules);

/++
extern(C) int main() {
    import static_import_betterc, static_node_betterc;
    alias parent = __traits(parent, main);
    alias modules = AliasSeq!(static_import_betterc, static_node_betterc);
    _call_static_ctor!modules;
    scope(exit) {
        _call_static_dtor!modules;
    }
    return 0;
}
++/

import tagion.betterC.hibon.HiBON : HiBONT;
import tagion.betterC.utils.RBTree : RBTreeT;

alias HiBONT_RBTreeT = RBTreeT!(HiBONT.Member*).Node;
extern (C) HiBONT_RBTreeT _D6tagion7betterC5utils6RBTree__T7RBTreeTTPSQBqQBm5hibon5HiBON6HiBONT6MemberZQBs4NILLSQDgQDcQCxQCu__TQCqTQClZQCy4Node;

// extern(C) void  _D6tagion7betterC5utils6RBTree__T7RBTreeTTPSQBqQBm5hibon5HiBON6HiBONT6MemberZQBs20_staticCtor_L50_C5_1FNbNiNfZv() {
// }

pragma(msg, "HiBONT_RBTreeT ", _D6tagion7betterC5utils6RBTree__T7RBTreeTTPSQBqQBm5hibon5HiBON6HiBONT6MemberZQBs4NILLSQDgQDcQCxQCu__TQCqTQClZQCy4Node
        .sizeof);

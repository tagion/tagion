module tagion.betterC.mobile.DocumentWrapperApi;

import tagion.betterC.hibon.Document;
import tagion.betterC.hibon.HiBON;
import tagion.betterC.mobile.Recycle;
import tagion.betterC.utils.Memory;

// import tagion.basic.Recycle;
// import tagion.gossip.GossipNet;
// import tagion.betterC.wallet.Net : SecureNet;
// import tagion.wallet.KeyRecover;

// import core.runtime : rt_init, rt_term;
// import core.stdc.stdlib;
import std.conv;
import std.stdint;
import std.string;
import tagion.basic.Types : Buffer;

// import tagion.hibon.HiBONJSON;

public Recycle!Document recyclerDoc;

// static this() {
//     recyclerDoc = recyclerDoc.init;
// }

// {
//     auto recyclerDoc = new reecycle!Document;
//     recycleDoc._active .... -> fine;
//     free(recyclerDoc);
//     recyclerDoc._active -> fail;
// }

extern (C) {
    enum BAD_RESULT = 0;

    string[] parse_string(const char* str, const uint len) {
        string[] result;
        return result;
    }

    /// Functions called from d-lang through dart:ffi

    /// Creating Document by ubyte array
    // export uint32_t create_test_doc()
    // {
    //     auto hibon = HiBON();
    //     auto inner_hibon = HiBON();
    //     auto arr_hibon = HiBON();
    //     hibon["teststr"] = "test string";
    //     hibon["testnum"] = 123;
    //     hibon["testpk"] = cast(Buffer) [1,1,1,1];
    //     const testarr = ["first", "second", "third"];
    //     foreach(i, a; testarr){
    //         arr_hibon[i] = a;
    //     }
    //     hibon["testarr"] = Document(arr_hibon);
    //     inner_hibon["teststr"] = "inner test string";
    //     hibon["inner"] = Document(inner_hibon);
    //     auto doc = Document(hibon);
    //     if (doc.isInorder())
    //     {
    //         auto docId = recyclerDoc.create(doc);
    //         return docId;
    //     }
    //     return BAD_RESULT;
    // }
    /// Creating Document by ubyte array
    export uint32_t create_doc(const uint8_t* data_ptr, const uint32_t len) {
        // immutable(ubyte)[] data = cast(immutable(ubyte)[]) data_ptr[0 .. len];
        ubyte[] data;
        data.create(len);
        for (size_t i = 0; i < len; i++) {
            data[i] = data_ptr[i];
        }
        auto doc = Document(cast(immutable)(data));
        if (doc.isInorder()) {
            auto docId = recyclerDoc.create(doc);
            return docId;
        }
        return BAD_RESULT;
    }

    /// Deleting the specific Document
    export void delete_doc_by_id(const uint32_t id) {
        if (id !is BAD_RESULT) {
            recyclerDoc.erase(id);
        }
    }

    // /// Getting the int value from Document by integer index
    // export int32_t doc_get_int_by_id(const uint32_t doc_id, const uint32_t index)
    // {
    //     if (recyclerDoc(doc_id).hasMember(index))
    //     {
    //         return recyclerDoc(doc_id)[index].get;
    //     }
    //     return BAD_RESULT;
    // }

    /// Getting the int value from Document by string key
    export int32_t doc_get_int_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        // immutable key = cast(immutable)(key_str[0 .. len]);
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            return recyclerDoc(doc_id)[cast(string) key].get!int;
        }
        return BAD_RESULT;
    }
    /// Getting the ulong value from Document by string key
    export int64_t doc_get_ulong_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            return recyclerDoc(doc_id)[cast(string) key].get!ulong;
        }
        return BAD_RESULT;
    }
    // /// Getting the string value from Document by index
    // /// It uses UF-16 codding
    // export const(char*) doc_get_str_by_id(const uint32_t doc_id, const uint32_t index)
    // {
    //     if (recyclerDoc(doc_id).hasMember(index))
    //     {
    //         string str = recyclerDoc(doc_id)[index].get!string;
    //         return toStringz(str);
    //     }
    //     return null;
    // }

    // /// getting the string value from Document by string key
    // /// It uses UF-16 codding
    export const(char*) doc_get_str_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            string str = recyclerDoc(doc_id)[cast(string) key].get!string;
            return str.ptr;
        }
        return null;
    }

    // /// return doc as json
    // /// It uses UF-16 codding
    // export const(char*) doc_as_json(const uint32_t doc_id)
    // {
    //     auto doc = recyclerDoc(doc_id);
    //     const json = doc.toJSON.toString();
    //     return toStringz(json);
    // }

    //     /// Getting the Document value from Document by index
    // /// It uses UF-16 codding
    // export uint64_t doc_get_docLen_by_id(const uint32_t doc_id, const uint32_t index)
    // {
    //     if (recyclerDoc(doc_id).hasMember(index))
    //     {
    //         const doc = recyclerDoc(doc_id)[index].get!Document;
    //         return doc.serialize.length;
    //     }
    //     return BAD_RESULT;
    // }

    // /// getting the Document value from Document by string key
    // /// It uses UF-16 codding
    export uint64_t doc_get_docLen_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            const doc = recyclerDoc(doc_id)[cast(string) key].get!Document;
            return doc.serialize.length;
        }
        return BAD_RESULT;
    }

    // /// Getting the Document value from Document by index
    // /// It uses UF-16 codding
    // export uint8_t* doc_get_docPtr_by_id(const uint32_t doc_id, const uint32_t index)
    // {
    //     if (recyclerDoc(doc_id).hasMember(index))
    //     {
    //         const doc = recyclerDoc(doc_id)[index].get!Document;
    //         return cast(ubyte*) doc.serialize.ptr;
    //     }
    //     return null;
    // }

    // /// getting the Document value from Document by string key
    // /// It uses UF-16 codding
    export uint8_t* doc_get_docPtr_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            const doc = recyclerDoc(doc_id)[cast(string) key].get!Document;
            return cast(ubyte*) doc.serialize.ptr;
        }
        return null;
    }

    // /// getting the Document value
    // /// It uses UF-16 codding
    export uint64_t get_docLen(const uint32_t doc_id) {
        const doc = recyclerDoc(doc_id);
        return doc.serialize.length;
    }

    // /// getting the Document value
    // /// It uses UF-16 codding
    export uint8_t* get_docPtr(const uint32_t doc_id) {
        const doc = recyclerDoc(doc_id);
        return cast(ubyte*) doc.serialize.ptr;
    }

    // export uint64_t doc_get_bufferLen_by_id(const uint32_t doc_id, const uint32_t index)
    // {
    //     if (recyclerDoc(doc_id).hasMember(index))
    //     {
    //         const buf = recyclerDoc(doc_id)[index].get!Buffer;
    //         return buf.length;
    //     }
    //     return BAD_RESULT;
    // }

    export uint64_t doc_get_bufferLen_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            const buf = recyclerDoc(doc_id)[cast(string) key].get!Buffer;
            return buf.length;
        }
        return BAD_RESULT;
    }

    // export uint8_t* doc_get_bufferPtr_by_id(const uint32_t doc_id, const uint32_t index)
    // {
    //     if (recyclerDoc(doc_id).hasMember(index))
    //     {
    //         const doc = recyclerDoc(doc_id)[index].get!Buffer;
    //         return cast(ubyte*) doc.ptr;
    //     }
    //     return null;
    // }

    export uint8_t* doc_get_bufferPtr_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        char[] key;
        key.create(len);
        for (int i = 0; i < len; i++) {
            key[i] = key_str[i];
        }
        if (recyclerDoc(doc_id).hasMember(cast(string)(key))) {
            const doc = recyclerDoc(doc_id)[cast(string) key].get!Buffer;
            return cast(ubyte*) doc.ptr;
        }
        return null;
    }

    export uint64_t doc_get_memberCount(const uint32_t doc_id) {
        return recyclerDoc(doc_id).length;
    }
    // /// Getting the keys of Document
    // /// It uses UF-16 codding
    // export const(char*) doc_get_keys(const uint32_t doc_id)
    // {
    //     if (recyclerDoc.exists(doc_id))
    //     {
    //         string[] keys = recyclerDoc(doc_id).keys();
    //         string keysStr = join(keys, ";");
    //         return toStringz(keysStr);
    //     }
    //     return null;
    // }

    // unittest
    // {
    //     import std.stdio : writeln, writefln;
    //     import std.string : fromStringz;
    //     import tagion.hibon.HiBON : HiBON;

    //     // Aux HiBON for testing
    //     auto hib = new HiBON;
    //     hib["doc2"] = "test_str_with_key";

    //     // Tests for create_doc()
    //     {
    //         // Test for null request
    //         assert(create_doc(null, 0) is 1);

    //         // Test for empty array
    //         const(ubyte)[] empty_data = new ubyte[0];
    //         assert(create_doc(empty_data.ptr, 0) is 2);

    //         // Tests for ubytes' sequence
    //         const data1 = hib.serialize;
    //         const data2 = hib.serialize;

    //         //assert(create_doc(data1.ptr, data1.length) is 2);
    //         //assert(create_doc(data2.ptr, data2.length) is 3);
    //     }

    //     // Tests for delete_doc_by_id()
    //     {
    //         delete_doc_by_id(1);
    //         delete_doc_by_id(2);

    //         assert(!recyclerDoc.exists(0));
    //         assert(!recyclerDoc.exists(1));

    //         // Append two docs and check whether they exists by indicies
    //         const data = hib.serialize;
    //         create_doc(data.ptr, cast(uint) data.length);
    //         assert(recyclerDoc.exists(1));

    //         create_doc(data.ptr, cast(uint) data.length);
    //         assert(recyclerDoc.exists(0));
    //     }
    //     // Range of Document' indexes in RecyclerDoc [0 .. 3]

    //     // Tests for doc_get_int_by_key()
    //     {
    //         assert(doc_get_int_by_key(0, "doc1", 4) is 100);
    //         assert(doc_get_int_by_key(1, "doc1", 4) is 100);
    //         assert(doc_get_int_by_key(2, "doc1", 4) is 100);
    //         assert(doc_get_int_by_key(3, "doc1", 4) is 100);

    //         // Testing an absense of the key
    //         assert(doc_get_int_by_key(0, "doc", 3) is BAD_RESULT);
    //         assert(doc_get_int_by_key(1, "doc", 3) is BAD_RESULT);
    //         assert(doc_get_int_by_key(2, "doc", 3) is BAD_RESULT);
    //         assert(doc_get_int_by_key(3, "doc", 3) is BAD_RESULT);

    //         // Testing a wrong key size with correct key
    //         assert(doc_get_int_by_key(0, "doc1", 3) is BAD_RESULT);
    //         assert(doc_get_int_by_key(1, "doc1", 3) is BAD_RESULT);
    //         assert(doc_get_int_by_key(2, "doc1", 3) is BAD_RESULT);
    //         assert(doc_get_int_by_key(3, "doc1", 3) is BAD_RESULT);

    //         // Testing a wrong key size with incorrect key
    //         assert(doc_get_int_by_key(0, "doc", 10) is BAD_RESULT);
    //         assert(doc_get_int_by_key(1, "doc", 10) is BAD_RESULT);
    //         assert(doc_get_int_by_key(2, "doc", 10) is BAD_RESULT);
    //         assert(doc_get_int_by_key(3, "doc", 10) is BAD_RESULT);
    //     }

    //     // Tests for doc_get_int_by_id()
    //     {
    //         assert(doc_get_int_by_id(0, 1) is 101);
    //         assert(doc_get_int_by_id(1, 1) is 101);
    //         assert(doc_get_int_by_id(2, 1) is 101);
    //         assert(doc_get_int_by_id(3, 1) is 101);

    //         // Testing an absense of the key
    //         assert(doc_get_int_by_id(0, 3) is BAD_RESULT);
    //         assert(doc_get_int_by_id(1, 3) is BAD_RESULT);
    //         assert(doc_get_int_by_id(2, 3) is BAD_RESULT);
    //         assert(doc_get_int_by_id(3, 3) is BAD_RESULT);
    //     }

    //     // Tests for doc_get_str_by_id()
    //     {
    //         const(char)[] expected_str = "test_str_with_id";

    //         assert(fromStringz(doc_get_str_by_id(0, 2)) == expected_str);
    //         assert(fromStringz(doc_get_str_by_id(1, 2)) == expected_str);
    //         assert(fromStringz(doc_get_str_by_id(2, 2)) == expected_str);
    //         assert(fromStringz(doc_get_str_by_id(3, 2)) == expected_str);

    //         // Testing an existed document with wrong id
    //         assert(doc_get_str_by_id(0, 0) is null);
    //         assert(doc_get_str_by_id(1, 0) is null);
    //         assert(doc_get_str_by_id(2, 0) is null);
    //         assert(doc_get_str_by_id(3, 0) is null);
    //     }

    //     // Tests for doc_get_str_by_key()
    //     {
    //         const(char)[] expected_str = "test_str_with_key";

    //         assert(fromStringz(doc_get_str_by_key(0, "doc2", 4)) == expected_str);
    //         assert(fromStringz(doc_get_str_by_key(1, "doc2", 4)) == expected_str);
    //         assert(fromStringz(doc_get_str_by_key(2, "doc2", 4)) == expected_str);
    //         assert(fromStringz(doc_get_str_by_key(3, "doc2", 4)) == expected_str);

    //         // Testing an absense of the key
    //         assert(doc_get_str_by_key(0, "doc", 3) is null);
    //         assert(doc_get_str_by_key(1, "doc", 3) is null);
    //         assert(doc_get_str_by_key(2, "doc", 3) is null);
    //         assert(doc_get_str_by_key(3, "doc", 3) is null);

    //         // Testing a wrong key's size with correct key
    //         assert(doc_get_str_by_key(0, "doc2", 3) is null);
    //         assert(doc_get_str_by_key(1, "doc2", 3) is null);
    //         assert(doc_get_str_by_key(2, "doc2", 3) is null);
    //         assert(doc_get_str_by_key(3, "doc2", 3) is null);

    //         // Testing a wrong key's size with incorrect key
    //         assert(doc_get_str_by_key(0, "doc", 10) is null);
    //         assert(doc_get_str_by_key(1, "doc", 10) is null);
    //         assert(doc_get_str_by_key(2, "doc", 10) is null);
    //         assert(doc_get_str_by_key(3, "doc", 10) is null);
    //     }

    //     {
    //         import std.algorithm;
    //         auto hib1 = new HiBON;
    //         hib1["test"] = "test";
    //         hib["doc3"] = Document(hib1);
    //         const expected = hib1.serialize;

    //         const data = hib.serialize;
    //         auto index = create_doc(data.ptr, cast(uint) data.length);

    //         const docLen = doc_get_docLen_by_key(index, "test", 4);
    //         immutable docPtr = cast(immutable) doc_get_docPtr_by_key(index, "test", 4);
    //         const doc = Document(docPtr[0..cast(uint)docLen]);
    //         assert(equal(expected, doc.serialize));
    //     }
    // }
}

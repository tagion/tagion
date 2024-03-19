module tagion.mobile.DocumentWrapperApi;

import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.mobile.Recycle;

// import tagion.basic.Recycle;
// import tagion.gossip.GossipNet;
// import tagion.wallet.KeyRecover;
import tagion.crypto.SecureNet : StdHashNet;

// import tagion.wallet.KeyRecover;

import core.runtime : rt_init, rt_term;
import core.stdc.stdlib;
import std.stdint;
import std.string : fromStringz, toStringz;
import tagion.basic.Types : Buffer;
import tagion.hibon.HiBONJSON;

public static Recycle!Document recyclerDoc;

enum {
    BAD_RESULT = 0,
    OK_RESULT = 1,
}

string[] parse_string(const char* str, const uint len) {
    string[] result;
    return result;
}

/// Functions called from d-lang through dart:ffi
extern (C) {

    /// Creating Document by ubyte array
    export uint32_t create_test_doc() {
        HiBON hibon = new HiBON();
        HiBON inner_hibon = new HiBON();
        HiBON arr_hibon = new HiBON();
        hibon["teststr"] = "test string";
        hibon["testnum"] = 123;
        hibon["testpk"] = cast(Buffer)[1, 1, 1, 1];
        const testarr = ["first", "second", "third"];
        foreach (i, a; testarr) {
            arr_hibon[i] = a;
        }
        hibon["testarr"] = Document(arr_hibon);
        inner_hibon["teststr"] = "inner test string";
        hibon["inner"] = Document(inner_hibon);
        auto doc = Document(hibon);
        if (doc.isInorder()) {
            auto docId = recyclerDoc.create(doc);
            return docId;
        }
        return BAD_RESULT;
    }
    /// Creating Document by ubyte array
    export uint32_t create_doc(const uint8_t* data_ptr, const uint32_t len) {
        immutable(ubyte)[] data = cast(immutable(ubyte)[]) data_ptr[0 .. len];
        auto doc = Document(data);
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

    /// Getting the int value from Document by integer index
    export int32_t doc_get_int_by_id(const uint32_t doc_id, const uint32_t index) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            return recyclerDoc(doc_id)[index].get!int;
        }
        return BAD_RESULT;
    }

    export int32_t doc_get_int_by_id_(const uint32_t doc_id, const uint32_t index, int* result) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            *result = recyclerDoc(doc_id)[index].get!int;
            return OK_RESULT;
        }
        return BAD_RESULT;
    }

    /// Getting the int value from Document by string key
    export int32_t doc_get_int_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            return recyclerDoc(doc_id)[key].get!int;
        }
        return BAD_RESULT;
    }
    /// Getting the ulong value from Document by string key
    export uint64_t doc_get_ulong_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            return recyclerDoc(doc_id)[key].get!ulong;
        }
        return BAD_RESULT;
    }
    /// Getting the long value from Document by string key
    export int64_t doc_get_long_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            return recyclerDoc(doc_id)[key].get!long;
        }
        return BAD_RESULT;
    }
    /// Getting the string value from Document by index
    /// It uses UF-16 codding
    export const(char*) doc_get_str_by_id(const uint32_t doc_id, const uint32_t index) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            string str = recyclerDoc(doc_id)[index].get!string;
            return toStringz(str);
        }
        return null;
    }

    export uint32_t doc_get_str_by_id_(const uint32_t doc_id, const uint32_t index, const(char)** result_str, uint32_t* result_len) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            string str = recyclerDoc(doc_id)[index].get!string;
            /* pragma(msg, "str.ptr ", typeof(str.ptr), " result_str ", typeof(result_str)); */
            *result_str = cast(const(char)*) str.ptr;
            *result_len = cast(uint32_t) str.length;
            return OK_RESULT;
        }
        return BAD_RESULT;
    }

    /// getting the string value from Document by string key
    /// It uses UF-16 codding
    export const(char*) doc_get_str_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            string str = recyclerDoc(doc_id)[key].get!string;
            return toStringz(str);
        }
        return null;
    }

    /// return doc as json
    /// It uses UF-16 codding
    export const(char*) doc_as_json(const uint32_t doc_id) {
        auto doc = recyclerDoc(doc_id);
        const json = doc.toJSON.toString();
        return toStringz(json);
    }

    /// Getting the Document value from Document by index
    /// It uses UF-16 codding
    export uint64_t doc_get_docLen_by_id(const uint32_t doc_id, const uint32_t index) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            const doc = recyclerDoc(doc_id)[index].get!Document;
            return doc.serialize.length;
        }
        return BAD_RESULT;
    }

    /// getting the Document value from Document by string key
    /// It uses UF-16 codding
    export uint64_t doc_get_docLen_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            const doc = recyclerDoc(doc_id)[key].get!Document;
            return doc.serialize.length;
        }
        return BAD_RESULT;
    }

    /// Getting the Document value from Document by index
    /// It uses UF-16 codding
    export uint8_t* doc_get_docPtr_by_id(const uint32_t doc_id, const uint32_t index) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            const doc = recyclerDoc(doc_id)[index].get!Document;
            return cast(ubyte*) doc.serialize.ptr;
        }
        return null;
    }

    /// getting the Document value from Document by string key
    /// It uses UF-16 codding
    export uint8_t* doc_get_docPtr_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            const doc = recyclerDoc(doc_id)[key].get!Document;
            return cast(ubyte*) doc.serialize.ptr;
        }
        return null;
    }

    /// getting the Document value
    /// It uses UF-16 codding
    export uint64_t get_docLen(const uint32_t doc_id) {
        const doc = recyclerDoc(doc_id);
        return doc.serialize.length;
    }

    /// getting the Document value
    /// It uses UF-16 codding
    export uint8_t* get_docPtr(const uint32_t doc_id) {
        const doc = recyclerDoc(doc_id);
        return cast(ubyte*) doc.serialize.ptr;
    }

    export uint64_t doc_get_bufferLen_by_id(const uint32_t doc_id, const uint32_t index) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            const buf = recyclerDoc(doc_id)[index].get!Buffer;
            return buf.length;
        }
        return BAD_RESULT;
    }

    export uint64_t doc_get_bufferLen_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            const buf = recyclerDoc(doc_id)[key].get!Buffer;
            return buf.length;
        }
        return BAD_RESULT;
    }

    export uint8_t* doc_get_bufferPtr_by_id(const uint32_t doc_id, const uint32_t index) {
        if (recyclerDoc(doc_id).hasMember(index)) {
            const doc = recyclerDoc(doc_id)[index].get!Buffer;
            return cast(ubyte*) doc.ptr;
        }
        return null;
    }

    export uint8_t* doc_get_bufferPtr_by_key(const uint32_t doc_id, const char* key_str, const uint32_t len) {
        immutable key = cast(immutable)(key_str[0 .. len]);
        if (recyclerDoc(doc_id).hasMember(key)) {
            const doc = recyclerDoc(doc_id)[key].get!Buffer;
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
}

pragma(msg, "fixme(cbr): This unittest does not pass");
version (none) unittest {
    pragma(msg, "fixme(cbr): Fix this unittest ");
    import std.stdio : writefln, writeln;
    import std.string : fromStringz;
    import tagion.hibon.HiBON : HiBON;

    // Aux HiBON for testing
    auto hib = new HiBON;
    hib["doc2"] = "test_str_with_key";

    // Tests for create_doc()
    {
        // Test for null request
        assert(create_doc(null, 0) is 1);

        // Test for empty array
        const(ubyte)[] empty_data = new ubyte[0];
        assert(create_doc(empty_data.ptr, 0) is 2);

        // Tests for ubytes' sequence
        // const data1 = hib.serialize;
        // const data2 = hib.serialize;

        // const doc_id_data_1 = create_doc(data1.ptr, cast(uint)data1.length);
        // const doc_id_data_2 = create_doc(data2.ptr, cast(uint)data2.length);

        // writefln("doc_id_data_1=%d", doc_id_data_1);
        // writefln("doc_id_data_2=%d", doc_id_data_2);
        //assert(create_doc(data1.ptr, data1.length) is 2);
        //assert(create_doc(data2.ptr, data2.length) is 3);
    }

    // Tests for delete_doc_by_id()
    pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
    version (none) {

        assert(recyclerDoc.exists(1));
        assert(recyclerDoc.exists(2));

        delete_doc_by_id(1);
        delete_doc_by_id(2);

        assert(!recyclerDoc.exists(1));
        assert(!recyclerDoc.exists(2));

        // Append two docs and check whether they exists by indices
        const data = hib.serialize;
        const doc_id_data_a = create_doc(data.ptr, cast(uint) data.length);
        writefln("doc_id_0=%d", doc_id_data_a);
        assert(recyclerDoc.exists(doc_id_data_a));

        const doc_id_data_b = create_doc(data.ptr, cast(uint) data.length);
        writefln("doc_id_1=%d", doc_id_data_b);
        assert(recyclerDoc.exists(doc_id_data_b));
    }
    // Range of Document' indexes in RecyclerDoc [0 .. 3]

    // Tests for doc_get_int_by_key()
    pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
    version (none) {

        assert(doc_get_int_by_key(0, "doc1", 4) is 100);
        assert(doc_get_int_by_key(1, "doc1", 4) is 100);
        assert(doc_get_int_by_key(2, "doc1", 4) is 100);
        assert(doc_get_int_by_key(3, "doc1", 4) is 100);

        // Testing an absence of the key
        assert(doc_get_int_by_key(0, "doc", 3) is BAD_RESULT);
        assert(doc_get_int_by_key(1, "doc", 3) is BAD_RESULT);
        assert(doc_get_int_by_key(2, "doc", 3) is BAD_RESULT);
        assert(doc_get_int_by_key(3, "doc", 3) is BAD_RESULT);

        // Testing a wrong key size with correct key
        assert(doc_get_int_by_key(0, "doc1", 3) is BAD_RESULT);
        assert(doc_get_int_by_key(1, "doc1", 3) is BAD_RESULT);
        assert(doc_get_int_by_key(2, "doc1", 3) is BAD_RESULT);
        assert(doc_get_int_by_key(3, "doc1", 3) is BAD_RESULT);

        // Testing a wrong key size with incorrect key
        assert(doc_get_int_by_key(0, "doc", 10) is BAD_RESULT);
        assert(doc_get_int_by_key(1, "doc", 10) is BAD_RESULT);
        assert(doc_get_int_by_key(2, "doc", 10) is BAD_RESULT);
        assert(doc_get_int_by_key(3, "doc", 10) is BAD_RESULT);
    }

    // Tests for doc_get_int_by_id()
    pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
    version (none) {
        assert(doc_get_int_by_id(0, 1) is 101);
        assert(doc_get_int_by_id(1, 1) is 101);
        assert(doc_get_int_by_id(2, 1) is 101);
        assert(doc_get_int_by_id(3, 1) is 101);

        // Testing an absence of the key
        assert(doc_get_int_by_id(0, 3) is BAD_RESULT);
        assert(doc_get_int_by_id(1, 3) is BAD_RESULT);
        assert(doc_get_int_by_id(2, 3) is BAD_RESULT);
        assert(doc_get_int_by_id(3, 3) is BAD_RESULT);
    }

    // Tests for doc_get_str_by_id()
    pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
    version (none) {
        const(char)[] expected_str = "test_str_with_id";

        assert(fromStringz(doc_get_str_by_id(0, 2)) == expected_str);
        assert(fromStringz(doc_get_str_by_id(1, 2)) == expected_str);
        assert(fromStringz(doc_get_str_by_id(2, 2)) == expected_str);
        assert(fromStringz(doc_get_str_by_id(3, 2)) == expected_str);

        // Testing an existed document with wrong id
        assert(doc_get_str_by_id(0, 0) is null);
        assert(doc_get_str_by_id(1, 0) is null);
        assert(doc_get_str_by_id(2, 0) is null);
        assert(doc_get_str_by_id(3, 0) is null);
    }

    // Tests for doc_get_str_by_key()
    pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
    version (none) {
        const(char)[] expected_str = "test_str_with_key";

        assert(fromStringz(doc_get_str_by_key(0, "doc2", 4)) == expected_str);
        assert(fromStringz(doc_get_str_by_key(1, "doc2", 4)) == expected_str);
        assert(fromStringz(doc_get_str_by_key(2, "doc2", 4)) == expected_str);
        assert(fromStringz(doc_get_str_by_key(3, "doc2", 4)) == expected_str);

        // Testing an absence of the key
        assert(doc_get_str_by_key(0, "doc", 3) is null);
        assert(doc_get_str_by_key(1, "doc", 3) is null);
        assert(doc_get_str_by_key(2, "doc", 3) is null);
        assert(doc_get_str_by_key(3, "doc", 3) is null);

        // Testing a wrong key's size with correct key
        assert(doc_get_str_by_key(0, "doc2", 3) is null);
        assert(doc_get_str_by_key(1, "doc2", 3) is null);
        assert(doc_get_str_by_key(2, "doc2", 3) is null);
        assert(doc_get_str_by_key(3, "doc2", 3) is null);

        // Testing a wrong key's size with incorrect key
        assert(doc_get_str_by_key(0, "doc", 10) is null);
        assert(doc_get_str_by_key(1, "doc", 10) is null);
        assert(doc_get_str_by_key(2, "doc", 10) is null);
        assert(doc_get_str_by_key(3, "doc", 10) is null);
    }

    pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
    version (none) {
        import std.algorithm;

        auto hib1 = new HiBON;
        hib1["test"] = "test";
        hib["doc3"] = Document(hib1);
        const expected = hib1.serialize;

        const data = hib.serialize;
        auto index = create_doc(data.ptr, cast(uint) data.length);

        const docLen = doc_get_docLen_by_key(index, "test", 4);
        immutable docPtr = cast(immutable) doc_get_docPtr_by_key(index, "test", 4);
        const doc = Document(docPtr[0 .. cast(uint) docLen]);
        assert(equal(expected, doc.serialize));
    }
}

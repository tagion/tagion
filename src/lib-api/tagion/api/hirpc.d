/// C-API for creating hirpcs
module tagion.api.hirpc;

import tagion.api.basic;
import tagion.api.errors;
import tagion.api.wallet;

import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;
import tagion.hibon.Document;

version(unittest) {}
else {
extern(C):
nothrow:
}

/**
 * Create a hirpc from a document
 * Params:
 *   method = The name of the method
 *   method_len = The length of the method string
 *   param = Optional the document to use as the parameter
 *   param_len = The length of the document parameter
 *   out_doc = The resulting hirpc as a document
 *   out_doc_len = The length of the resulting document
 * Returns: [tagion.api.errors.ErrorCode]
 */
int tagion_hirpc_create_sender(
        const char* method,
        const size_t method_len,
        const ubyte* param,
        const size_t param_len,
        ubyte** out_doc,
        size_t* out_doc_len
) {
    try {
        const doc = Document(cast(immutable)param[0 .. param_len]);
        string method_name = cast(immutable)method[0 .. method_len];

        ubyte[] result_sender = cast(ubyte[])HiRPC(null).action(method_name, doc).serialize;
        *out_doc = &result_sender[0];
        *out_doc_len = result_sender.length;
        return ErrorCode.none;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
}

///
unittest {
    import tagion.api.hibon;
    import tagion.api.document;

    ubyte* doc_param_ptr = new ubyte;
    size_t doc_param_len;
    {
        HiBONT* hibon = new HiBONT;
        int rc = tagion_hibon_create(hibon);
        assert(rc == 0);
        scope(exit) tagion_hibon_free(hibon);
        const char[] key = "a";
        rc = tagion_hibon_add_int32(hibon, &key[0], key.length, 7);
        assert(rc == 0);

        rc = tagion_hibon_get_document(hibon, &doc_param_ptr, &doc_param_len);
        assert(rc == 0);
    }

    string method = "some_method";

    ubyte* result_doc_ptr = new ubyte;
    size_t result_doc_len;

    int rc = tagion_hirpc_create_sender(&method[0], method.length, doc_param_ptr, doc_param_len, &result_doc_ptr, &result_doc_len);
    assert(rc == 0);

    const doc = Document(result_doc_ptr[0 .. result_doc_len].idup);
    assert(doc.isInorder);
}

/**
 * Create a signed hirpc from a document
 * Params:
 *   method = The name of the method
 *   method_len = The length of the method string
 *   param = Optional the document to use as the parameter
 *   param_len = The length of the document parameter
 *   root_net = The root net used to sign the message
 *   deriver = Optional deriver key
 *   deriver_len = length of the optional deriver key
 *   out_doc = The resulting hirpc as a document
 *   out_doc_len = The length of the resulting document
 * Returns: [tagion.api.errors.ErrorCode]
 */
int tagion_hirpc_create_signed_sender(
        const char* method,
        const size_t method_len,
        const ubyte* param,
        const size_t param_len,
        const securenet_t* root_net,
        const ubyte* deriver,
        const size_t deriver_len,
        ubyte** out_doc,
        size_t* out_doc_len
) {
    try {
        if (root_net.magic_byte != MAGIC.SECURENET) {
            set_error_text = "The passed securenet is invalid";
            return ErrorCode.error;
        }

        const(StdSecureNet) get_secure_net() {
            const net_ = cast(StdSecureNet)root_net.securenet;
            if(deriver_len != 0) {
                const deriver_ = deriver[0 .. deriver_len];
                pragma(msg, __FILE__, " Is this the correct way to derive the public key");
                return cast(const(StdSecureNet))net_.derive(net_.HMAC(deriver_));
            }
            return net_;
        }

        const net_ = get_secure_net();

        const doc = Document(cast(immutable)param[0 .. param_len]);
        string method_name = cast(immutable)method[0 .. method_len];

        ubyte[] result_sender = cast(ubyte[])HiRPC(net_).action(method_name, doc).serialize;
        *out_doc = &result_sender[0];
        *out_doc_len = result_sender.length;
        return ErrorCode.none;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
}

///
unittest {
    import tagion.api.hibon;
    import tagion.api.document;

    ubyte* doc_param_ptr = new ubyte;
    size_t doc_param_len;
    {
        HiBONT* hibon = new HiBONT;
        int rc = tagion_hibon_create(hibon);
        assert(rc == 0);
        scope(exit) tagion_hibon_free(hibon);
        const char[] key = "a";
        rc = tagion_hibon_add_int32(hibon, &key[0], key.length, 7);
        assert(rc == 0);

        rc = tagion_hibon_get_document(hibon, &doc_param_ptr, &doc_param_len);
        assert(rc == 0);
    }

    string method = "some_method";

    securenet_t net;
    {
        const(char)[] passphrase = "ababab";
        const(char)[] pin = "babab";
        ubyte* device_doc_ptr = new ubyte;
        size_t device_doc_len;
        tagion_generate_keypair(&passphrase[0], passphrase.length, null, 0, &net, &pin[0], pin.length, &device_doc_ptr, &device_doc_len);
    }


    { // Signed hirpc with root key
        ubyte* result_doc_ptr = new ubyte;
        size_t result_doc_len;
        int rc = tagion_hirpc_create_signed_sender(&method[0], method.length, doc_param_ptr, doc_param_len, &net, null, 0, &result_doc_ptr, &result_doc_len);
        assert(rc == 0);

        const doc = Document(result_doc_ptr[0 .. result_doc_len].idup);
        assert(doc.isInorder);
    }

    { // Signed hirpc with a derived key
        ubyte* result_doc_ptr = new ubyte;
        size_t result_doc_len;

        ubyte[] tweak_word = [28,1,0,1];
        int rc = tagion_hirpc_create_signed_sender(&method[0], method.length, doc_param_ptr, doc_param_len, &net, &tweak_word[0], tweak_word.length, &result_doc_ptr, &result_doc_len);
        assert(rc == 0);

        const doc = Document(result_doc_ptr[0 .. result_doc_len].idup);
        assert(doc.isInorder);
    }
}

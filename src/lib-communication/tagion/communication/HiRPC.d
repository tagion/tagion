/** 
* HiBON Remote Pprocedure Call
*/
module tagion.communication.HiRPC;

import std.format;
import std.traits : EnumMembers;
import std.exception : assumeWontThrow;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONException;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;

import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature;
import tagion.basic.tagionexceptions : Check;
import tagion.Keywords;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.utils.Miscellaneous : toHexString;

/// HiRPC format exception
@safe
class HiRPCException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// UDA to make a RPC member
enum HiRPCMethod;

private static string[] _Callers(T)() {
    import std.traits : isCallable, hasUDA;
    import std.meta : ApplyRight, Filter;

    string[] result;
    static foreach (name; __traits(derivedMembers, T)) {
        {
            alias Overloads = __traits(getOverloads, T, name);
            static if (Overloads.length) {
                alias hasMethod = ApplyRight!(hasUDA, HiRPCMethod);
                static foreach (i; 0 .. Overloads.length) {
                    static if (hasUDA!(Overloads[i], HiRPCMethod)) {
                        result ~= name;
                    }
                }
            }
        }
    }
    return result;
}

enum Callers(T) = _Callers!T();

/// HiRPC handler
@safe
struct HiRPC {
    import tagion.hibon.HiBONRecord;

    /// HiRPC call method 
    struct Method {
        @label("*", true) @(filter.Initialized) uint id; /// RPC identifier
        @label("*", true) @filter(q{!a.empty}) Document params; /// RPC arguments
        @label("method") @(inspect.Initialized) string name; /// RPC method name

        mixin HiBONRecord;
    }
    /// HiRPC result from a method
    struct Response {
        @label("*", true) @(filter.Initialized) uint id; /// RPC response id, if given by the method
        Document result; /// Return data from the method request
        mixin HiBONRecord;
    }

    /// HiRPC error response for a method
    struct Error {
        @label("*", true) @(filter.Initialized) uint id; /// RPC response id, if given by the method 
        @label("$data", true) @filter(q{!a.empty}) Document data; /// Optional error response package
        @label("$msg", true) @(filter.Initialized) string message; /// Optional Error text message
        @label("$code", true) @(filter.Initialized) int code; /// Optional error code

        static bool valid(const Document doc) {
            enum codeName = GetLabel!(code).name;
            enum messageName = GetLabel!(message).name;
            enum dataName = GetLabel!(data).name;
            return doc.hasMember(codeName) || doc.hasMember(messageName) || doc.hasMember(dataName);
        }

        mixin HiBONRecord;
    }

    /// Get the id of the document doc
    /// Params:
    ///   doc = Method, Response or Error document.
    /// Returns: RPC id if given or else return id 0
    static uint getId(const Document doc) nothrow {
        enum idLabel = GetLabel!(Error.id).name;
        if (doc.hasMember(idLabel)) {
            return assumeWontThrow(doc[idLabel].get!uint);
        }
        return uint.init;
    }

    /// Check if is T is a message
    /// Params: T is message data type
    /// Returns: true if T is HiRPC message type
    enum isMessage(T) = is(T : const(Method)) || is(T : const(Response)) || is(T : const(Error));

    /// State of the signature in the HiRPC 
    enum SignedState {
        INVALID = -1, /// Incorrect signature
        NOSIGN = 0, /// HiRPC has no signature
        VALID = 1 /// HiRPC was signed correctly
    }

    /// Message type
    enum Type : uint {
        none, /// No valid Type
        method, /// HiRPC Action method
        result, /// HiRPC Respose message
        error /// HiRPC Error message
    }

    /// HiRPC Post direction
    enum Direction {
        SEND, /// Marks the HiRPC Post as a sender type
        RECEIVE /// Marks the HiRPC Post as a receiver type
    }

    /// get the message to of the message
    /// Params: T message data type
    /// Returns: The type of the HiRPC message 
    static Type getType(T)(const T message) if (isHiBONRecord!T) {
        static if (is(T : const(Method))) {
            return Type.method;
        }
        else static if (is(T : const(Response))) {
            return Type.result;
        }
        else static if (is(T : const(Error))) {
            return Type.error;
        }
        else {
            return getType(message.toDoc);
        }
    }

    /// Ditto 
    static Type getType(const Document doc) {
        import std.conv : to;

        enum messageName = GetLabel!(Sender.message).name;
        const message_doc = doc[messageName].get!Document;
        foreach (E; EnumMembers!(Type)[1 .. $]) {
            enum name = E.to!string;
            if (message_doc.hasMember(name)) {
                return E;
            }
        }
        return Type.none;
    }

    /// HiRPC Post (Sender,Receiver)
    @recordType("HiRPC")
    struct Post(Direction DIRECTION) {
        union Message {
            Method method;
            Response response;
            Error error;
            uint id;
        }

        static assert(Message.method.id.alignof == Message.id.alignof);
        static assert(Message.response.id.alignof == Message.id.alignof);
        static assert(Message.error.id.alignof == Message.id.alignof);

        @label("$sign", true) @(filter.Initialized) Signature signature; /// Signature of the message
        @label("$pkey", true) @(filter.Initialized) Pubkey pubkey; /// Owner key of the message
        @label("$msg") Document message; /// the HiRPC message
        @label("") immutable Type type;

        @nogc const pure nothrow {
            /// Returns: true if the message is a method
            bool isMethod() {
                return type is Type.method;
            }
            /// Returns: true if the message is a response
            bool isResponse() {
                return type is Type.result;
            }

            /// Returns: true of the message is an error
            bool isError() {
                return type is Type.error;
            }
        }

        bool supports(T)() const {
            import std.traits : isCallable;
            import std.algorithm.searching : canFind;

            return (type is Type.method) &&
                Callers!T.canFind(method.name);
        }

        bool verify(const Document doc) {
            if (pubkey.length) {
                check(signature.length !is 0, "Message Post has a public key without signature");
            }
            return true;
        }

        static if (DIRECTION is Direction.RECEIVE) {
            @label("") protected Message _message;
            @label("") immutable SignedState signed;
            enum signName = GetLabel!(signature).name;
            enum pubkeyName = GetLabel!(pubkey).name;
            enum messageName = GetLabel!(message).name;
            this(const Document doc) {
                this(null, doc);
            }

            this(const SecureNet net, const Document doc)
            in {
                if (signature.length) {
                    assert(net !is null, "The signature can't be veified because the SecureNet is missing");
                }
            }
            do {
                check(!doc.hasHashKey, "Document containing hashkey can not be used as a message in HiPRC");

                type = getType(doc);
                message = doc[messageName].get!Document;
                signature = doc.hasMember(signName) ? doc[signName].get!(Signature) : Signature.init;
                pubkey = doc.hasMember(pubkeyName) ? doc[pubkeyName].get!(Pubkey) : Pubkey.init;
                Pubkey used_pubkey;
                static SignedState verifySignature(const SecureNet net, const Document doc, const Signature sgn, const Pubkey pkey) {
                    if (sgn.length) {
                        //immutable fingerprint=net.hashOf(msg);
                        if (net is null) {
                            return SignedState.INVALID;
                        }
                        Pubkey used_pubkey = pkey;
                        if (!used_pubkey.length) {
                            used_pubkey = net.pubkey;
                        }
                        if (net.verify(doc, sgn, pkey)) {
                            return SignedState.VALID;
                        }
                        else {
                            return SignedState.INVALID;
                        }
                    }
                    return SignedState.NOSIGN;
                }

                void set_message() @trusted {
                    with (Type) {
                        final switch (type) {
                        case none:
                            check(0, "Invalid HiPRC message");
                            break;
                        case method:
                            _message.method = Method(message);
                            break;
                        case result:
                            _message.response = Response(message);
                            break;
                        case error:
                            _message.error = Error(message);
                        }
                    }
                }

                set_message;
                signed = verifySignature(net, message, signature, pubkey);
            }

            this(T)(const SecureNet net, T pack) if (isHiBONRecord!T) {
                this(net, pack.toDoc);
            }

            /** 
             * 
             * Returns: if the message type is an error it returns it
            * or else it throws an exception
             */
            @trusted const(Error) error() const pure {
                check(type is Type.error, format("Message type %s expected not %s", Type.error, type));
                return _message.error;
            }

            /** 
             * 
             * Returns: if the message type is an response it returns it
            * or else it throws an exception
             */
            @trusted const(Response) response() const pure {
                check(type is Type.result, format("Message type %s expected not %s", Type.result, type));
                return _message.response;
            }

            /** 
            * 
            * Returns: if the message type is an response it returns it
            * or else it throws an exception
            */
            @trusted const(Method) method() const pure {
                check(type is Type.method, format("Message type %s expected not %s", Type.method, type));
                return _message.method;
            }

            /** 
             * Create T with the method params and the arguments.
             *  T(args, method.param)
             * Params:
             *   args = arguments to the
             * Returns: the constructed T
             */
            const(T) params(T, Args...)(Args args) const if (isHiBONRecord!T) {
                return T(args, method.params);
            }

            const(T) result(T, Args...)(Args args) const if (isHiBONRecord!T) {
                return T(response.result);
            }

            @trusted
            bool isRecord(T)() const {
                with (Type) {
                    final switch (type) {
                    case none, error:
                        return false;
                    case method:
                        return T.isRecord(_message.method.params);
                    case result:
                        return T.isRecord(_message.response.result);
                    }
                }
                assert(0);
            }
        }
        else {
            this(T)(const SecureNet net, const T post) if (isHiBONRecord!T || is(T : const Document)) {
                static if (isHiBONRecord!T) {
                    message = post.toDoc;
                }
                else {
                    message = post;
                }
                type = getType(post);
                if (net !is null) {
                    // immutable signed=net.sign(message);
                    // fingerprint=signed.message;
                    signature = net.sign(message).signature;
                    pubkey = net.pubkey;
                }
            }

            Error error() const
            in {
                assert(type is Type.error, format("Message type %s expected not %s", Type.error, type));
            }
            do {
                return Error(message);
            }

            Response response() const
            in {
                assert(type is Type.result, format("Message type %s expected not %s", Type.result, type));
            }
            do {
                return Response(message);
            }

            Method method() const
            in {
                assert(type is Type.method, format("Message type %s expected not %s", Type.method, type));
            }
            do {
                return Method(message);
            }

            /++
             Checks if the message has been signed
             NOTE!! This does not mean that the signature is correct
             Returns:
             True if the message has been signed
             +/
            @nogc bool isSigned() const pure nothrow {
                return (signature.length !is 0);
            }
        }

        mixin HiBONRecord!("{}");
    }

    alias Sender = Post!(Direction.SEND);
    alias Receiver = Post!(Direction.RECEIVE);

    alias check = Check!HiRPCException;
    const SecureNet net;

    /* 
 * Generate a random id 
 * Returns: random id
 */
    const(uint) generateId() const {
        uint id = 0;
        import tagion.utils.Random;
        import stdrnd = std.random;

        auto rnd = Random!uint(stdrnd.unpredictableSeed);
        do {
            id = rnd.value();
        }
        while (id is 0 || id is uint.max);
        return id;
    }

    /** 
     * Creates a sender via opDispatch.method with argument params
     * Params:
     *   method = opDispatch method name
     *   params = argument for method
     *   id = optional id
     * Returns: The created sender
     */
    immutable(Sender) opDispatch(string method, T)(
            ref auto const T params,
            const uint id = uint.max) const {
        return action(method, params, id);
    }

    /** 
     * Creates a sender with a runtime method name 
     * Params:
     *   method = method name 
     *   params = argument for the method
     *   id = opitional id
     * Returns: 
     */
    immutable(Sender) action(string method, const Document params, const uint id = uint.max) const {
        Method message;
        message.id = (id is uint.max) ? generateId : id;
        if (!params.empty) {
            message.params = params;
        }
        message.name = method;
        message.params = params;
        auto sender = Sender(net, message);
        return sender;
    }

    /// Ditto
    immutable(Sender) action(T)(string method, T params, const uint id = uint.max) const
    if (isHiBONRecord!T) {
        return action(method, params.toDoc, id);
    }

    /// Ditto
    immutable(Sender) action(string method, const(HiBON) params = null, const uint id = uint.max) const {
        const doc = Document(params);
        return action(method, doc, id);
    }

    /**
     * Create a return sender including the return value
     * return_value:
     *   receiver = HiRPC receiver
     *   return_value = return value from method 
     * Returns:
     *   Response sender to be return to the caller
     */
    immutable(Sender) result(ref const(Receiver) receiver, const Document return_value) const {
        Response message;
        message.id = receiver.method.id;
        message.result = return_value;
        immutable sender = Sender(net, message);
        return sender;
    }

    /// Ditto
    immutable(Sender) result(T)(ref const(Receiver) receiver, T return_value) const
    if (isHiBONRecord!T) {
        return result(receiver, return_value.toDoc);
    }

    /// Ditto
    immutable(Sender) result(ref const(Receiver) receiver, const(HiBON) return_value) const {
        return result(receiver, Document(return_value));
    }

    /**
     * Creates error response sender from a receiver 
     * Params:
     *   receiver = HiRPC receiver 
     *   msg = error text message
     *   code = error code
     *   data = error data load
     * Returns: 
     *  Response error sender
     */
    immutable(Sender) error(ref const(Receiver) receiver, string msg, const int code = 0, Document data = Document()) const {
        return error(receiver.method.id, msg, code, data);
    }

    /// Ditto
    immutable(Sender) error(const uint id, string msg, const int code = 0, Document data = Document()) const {
        Error message;
        message.id = id;
        message.code = code;
        message.data = data;
        message.message = msg;
        return Sender(net, message);
    }

    /**
     * Creates a receiver from a Document doc 
     * Params:
     *   doc = HiBON Document
     * Returns: 
     *   A checked receiver
     */
    final immutable(Receiver) receive(Document doc) const {
        auto receiver = Receiver(net, doc);
        return receiver;
    }

    /// Ditto
    final immutable(Receiver) receive(T)(T sender) const if (isHiBONRecord!T) {
        auto receiver = Receiver(net, sender.toDoc);
        return receiver;
    }
}

///
unittest {
    import tagion.hibon.HiBONRecord;
    import tagion.crypto.SecureNet : StdSecureNet, BadSecureNet;
    import tagion.crypto.secp256k1.NativeSecp256k1;

    class HiRPCNet : StdSecureNet {
        this(string passphrase) {
            super();
            generateKeyPair(passphrase);
        }
    }

    immutable passphrase = "Very secret password for the server";
    enum func_name = "func_name";

    {
        HiRPC hirpc = HiRPC(new HiRPCNet(passphrase));
        HiRPC bad_hirpc = HiRPC(new BadSecureNet(passphrase));
        auto params = new HiBON;
        params["test"] = 42;
        // Create a send method name func_name and argument params
        const sender = hirpc.action(func_name, params);
        // Sender with bad credetials
        const invalid_sender = bad_hirpc.action(func_name, params, sender.method.id);

        const doc = sender.toDoc;
        const invalid_doc = invalid_sender.toDoc;

        // Convert the do to a received HiRPC
        const receiver = hirpc.receive(doc);
        const invalid_receiver = hirpc.receive(invalid_doc);

        assert(receiver.method.id is sender.method.id);
        assert(receiver.method.name == sender.method.name);
        // Check that the received HiRPC is sigen correctly
        assert(receiver.signed is HiRPC.SignedState.VALID);

        assert(invalid_receiver.method.id is sender.method.id);
        assert(invalid_receiver.method.name == sender.method.name);
        assert(invalid_receiver.signed is HiRPC.SignedState.INVALID);

        static struct ResultStruct {
            int x;
            mixin HiBONRecord;
        }

        { // Response
            auto hibon = new HiBON;
            hibon["x"] = 42;
            const send_back = hirpc.result(receiver, hibon);
            const result = ResultStruct(send_back.response.result);
            assert(result.x is 42);
        }

        { // Error
            const send_error = hirpc.error(receiver, "Some error", -1);
            assert(send_error.error.message == "Some error");
            assert(send_error.error.code == -1);
            assert(send_error.isSigned);
        }
    }

    {
        HiRPC hirpc;
        { /// Unsigend message (no permission)
            HiBON t = new HiBON();
            t["$test"] = 5;

            const sender = hirpc.action("action", t);

            auto test2 = sender.toDoc;
            // writeln(test2.toJSON);
            // writefln("sender.isSigned=%s", sender.isSigned);
            assert(!sender.isSigned, "This message is un-sigend, which is fine because the HiRPC does not contain a SecureNet");
            {
                const receiver = hirpc.receive(sender.toDoc);
                // writefln("receiver=%s", receiver);
                assert(receiver.method.id is sender.method.id);
                // writefln("receiver.method.name is sender.method.name", receiver.method.name, sender.method.name);
                assert(receiver.method.name == sender.method.name);
                assert(receiver.signed is HiRPC.SignedState.NOSIGN);

                const params = receiver.method.params;
                assert(params["$test"].get!int  is 5);
            }
        }
        // writefln("recever.verified=%s", recever.verified);
    }
}

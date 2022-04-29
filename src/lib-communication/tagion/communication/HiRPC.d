module tagion.communication.HiRPC;

//import std.stdio;
import std.format;
import std.traits : EnumMembers;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONException;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;

import tagion.basic.Basic : Buffer, Pubkey, Signature;
import tagion.basic.TagionExceptions : Check;
import tagion.Keywords;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.utils.Miscellaneous : toHexString;

@safe
class HiRPCException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

struct HiRPCMethod {
    string name;
}

private static string[] _Callers(T)() {
    import std.traits : isCallable, hasUDA, getUDAs;

    string[] result;
    static foreach (name; __traits(derivedMembers, T)) {
        {
            static if (is(typeof(__traits(getMember, T, name)))) {
                enum prot = __traits(getProtection,
                            __traits(getMember, T, name));
                static if (prot == "public") {
                    enum code = format(q{alias MemberA=T.%s;}, name);
                    mixin(code);
                    static if (hasUDA!(MemberA, HiRPCMethod)) {
                        enum hirpc_method = getUDAs!(MemberA, HiRPCMethod)[0];
                        result ~= name;
                    }
                }
            }
        }
    }
    return result;
}

enum Callers(T) = _Callers!T();

private static string[] _Methods(T)() {
    import std.traits : isCallable, hasUDA, getUDAs;

    string[] result;
    static foreach (name; __traits(derivedMembers, T)) {
        {
            static if (is(typeof(__traits(getMember, T, name)))) {
                enum prot = __traits(getProtection,
                            __traits(getMember, T, name));
                static if (prot == "public") {
                    enum code = format(q{alias MemberA=T.%s;}, name);
                    mixin(code);
                    static if (hasUDA!(MemberA, HiRPCMethod)) {
                        enum hirpc_method = getUDAs!(MemberA, HiRPCMethod)[0];
                        static if (hirpc_method.name) {
                            enum method_name = hirpc_method.name;
                        }
                        else {
                            enum method_name = name;
                        }
                        result ~= method_name;
                    }
                }
            }
        }
    }
    return result;
}

enum Methods(T) = _Methods!T();

@safe
struct HiRPC {
    import tagion.hibon.HiBONRecord;

    struct Method {
        @Label("*", true) @(Filter.Initialized) uint id;
        @Label("*", true) @Filter(q{!a.empty}) Document params;
        @Label("method") @(Inspect.Initialized) string name;

        mixin HiBONRecord;
    }

    struct Response {
        @Label("*", true) @(Filter.Initialized) uint id;
        Document result;
        mixin HiBONRecord;
    }

    struct Error {
        @Label("*", true) @(Filter.Initialized) uint id;
        @Label("*", true) @Filter(q{!a.empty}) Document data;
        @Label("*", true) @(Filter.Initialized) string message;
        @Label("*", true) @(Filter.Initialized) int code;

        static bool valid(const Document doc) {
            enum codeName = GetLabel!(code).name;
            enum messageName = GetLabel!(message).name;
            enum dataName = GetLabel!(data).name;
            return doc.hasMember(codeName) || doc.hasMember(messageName) || doc.hasMember(dataName);
        }

        mixin HiBONRecord;
    }

    enum isMessage(T) = is(T : const(Method)) || is(T : const(Response)) || is(T : const(Error));

    enum SignedState {
        INVALID = -1,
        NOSIGN = 0,
        VALID = 1
    }

    enum Type : uint {
        none, /// No valid Type
        method, /// Action method
        result, /// Respose
        error
    }

    enum Direction {
        SEND,
        RECEIVE
    }

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

    @RecordType("HiPRC")
    struct Post(Direction DIRECTION) {
        union Message {
            Method method;
            Response response;
            Error error;
        }

        @disable this();
        //        @Label("") SecureNet net;
        @Label("$sign", true) @(Filter.Initialized) Signature signature;
        @Label("$pkey", true) @(Filter.Initialized) Pubkey pubkey;
        @Label("$msg") Document message;
        @Label("") immutable Type type;

        @nogc const pure nothrow {
            bool isMethod() {
                return type is Type.method;
            }

            bool isResponse() {
                return type is Type.result;
            }

            bool isError() {
                return type is Type.method;
            }
        }

        bool supports(T)() const {
            import std.traits : isCallable, hasUDA, getUDAs;

            if (type is Type.method) {
            CaseMethod:
                switch (method.name) {
                    static foreach (name; __traits(derivedMembers, T)) {
                        {
                            static if (is(typeof(__traits(getMember, T, name)))) {
                                enum prot = __traits(getProtection,
                                            __traits(getMember, T, name));
                                static if (prot == "public") {
                                    enum code = format(q{alias MemberA=T.%s;}, name);
                                    mixin(code);
                                    static if (hasUDA!(MemberA, HiRPCMethod)) {
                                        enum hirpc_method = getUDAs!(MemberA, HiRPCMethod)[0];
                                        static if (hirpc_method.name) {
                                            enum method_name = hirpc_method.name;
                                        }
                                        else {
                                            enum method_name = name;
                                        }
                case method_name:
                                        return true;
                                    }
                                }
                            }
                        }
                    }
                default:
                    // empty
                }
            }
            return false;
        }

        bool verify(const Document doc) {
            if (pubkey.length) {
                check(signature.length !is 0, "Message Post has a public key without signature");
            }
            return true;
        }
        //        @Label("") protected Buffer fingerprint;
        static if (DIRECTION is Direction.RECEIVE) {
            @Label("") protected Message _message;
            @Label("") immutable SignedState signed;
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
                signature = doc.hasMember(signName) ? doc[signName].get!(
                        TypedefType!Signature) : null;
                pubkey = doc.hasMember(pubkeyName) ? doc[pubkeyName].get!(
                        TypedefType!Pubkey) : null;
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

            @trusted const(Error) error() const pure {
                check(type is Type.error, format("Message type %s expected not %s", Type.error, type));
                return _message.error;
            }

            @trusted const(Response) response() const pure {
                check(type is Type.result, format("Message type %s expected not %s", Type.result, type));
                return _message.response;
            }

            @trusted const(Method) method() const pure {
                check(type is Type.method, format("Message type %s expected not %s", Type.method, type));
                return _message.method;
            }

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

    const(Sender) opDispatch(string method, T)(ref auto const T params, const uint id = uint.max) const {
        return action(method, params, id);
    }

    const(Sender) action(string method, const Document params, const uint id = uint.max) const {
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

    const(Sender) action(T)(string method, T params, const uint id = uint.max) const
    if (isHiBONRecord!T) {
        return action(method, params.toDoc, id);
    }

    const(Sender) action(string method, const(HiBON) params = null, const uint id = uint.max) const {
        const doc = Document(params);
        return action(method, doc, id);
    }

    const(Sender) result(ref const(Receiver) receiver, const Document params) const {
        Response message;
        message.id = receiver.method.id;
        message.result = params;
        const method = receiver.method;
        auto sender = Sender(net, message);
        return sender;
    }

    const(Sender) result(T)(ref const(Receiver) receiver, T params) const
    if (isHiBONRecord!T) {
        return result(receiver, params.toDoc);
    }

    const(Sender) result(ref const(Receiver) receiver, const(HiBON) params) const {
        return result(receiver, Document(params));
    }

    const(Sender) error(ref const(Receiver) receiver, string msg, const int code = 0, Document data = Document()) const {
        Error message;
        message.id = receiver.method.id;
        message.code = code;
        message.data = data;
        message.message = msg;
        auto sender = Sender(net, message);
        return sender;
    }

    final const(Receiver) receive(Document doc) const {
        auto receiver = Receiver(net, doc);
        return receiver;
    }

    final const(Receiver) receive(T)(T sender) const if (isHiBONRecord!T) {
        auto receiver = Receiver(net, sender.toDoc);
        return receiver;
    }

    static void check_type(T)(Document doc, string key) {
        immutable msg = format("Wrong type of member '%s', expected type but the type was",
                key);
        enum E = Document.Value.asType!T;
        // immutable msg=format("Wrong type of member '%s', expected type %s but the type was %s",
        //     key, TypeString!T, doc[key].typeString);
        check(doc[key].type is E, msg);
    }

    static void check_element(T)(Document doc, string key) {
        check(doc.hasMember(key), format("Member '%s' missing", key));
        check_type!T(doc, key);
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
        const sender = hirpc.action(func_name, params);
        const invalid_sender = bad_hirpc.action(func_name, params, sender.method.id);

        const doc = sender.toDoc;
        const invalid_doc = invalid_sender.toDoc;

        const receiver = hirpc.receive(doc);
        const invalid_receiver = hirpc.receive(invalid_doc);

        assert(receiver.method.id is sender.method.id);
        assert(receiver.method.name == sender.method.name);
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

module tagion.communication.HiRPC;

import std.stdio;
import std.format;
import std.traits : EnumMembers;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONException;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;

import tagion.basic.Basic : Buffer, Pubkey, Signature;
import tagion.basic.TagionExceptions : Check;
import tagion.Keywords;
import tagion.crypto.SecureInterface : SecureNet;
import tagion.utils.Miscellaneous : toHexString;

@safe
class HiRPCException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}


enum HiRPC_version="2.0";
@safe
struct HiRPC {
    import tagion.hibon.HiBONRecord;
    struct Method {
        @Label("*", true) @(Filter.Initialized) uint id;
        @Label("*", true) @Filter(q{!a.empty}) Document params;
        @Label("method") @(Inspect.Initialized) string name;

        mixin HiBONRecord;
    }

    struct Result {
        @Label("*", true) @(Filter.Initialized) uint id;
        Document result;
        mixin HiBONRecord;
    }

    struct Error {
        @Label("*", true) @(Filter.Initialized) uint id;
        @Label("*", true) @Filter(q{!a.empty}) Document data;
        @Label("*", true) @(Filter.Initialized) string message;
        @Label("*", true) @(Filter.Initialized) uint code;


        bool verify(const Document doc) {
            return doc.hasMember(code.stringof) || doc.hasMember(message.stringof) || doc.hasMember(data.stringof);
        }
        mixin HiBONRecord;
    }

    enum isMessage(T)=is(T:const(Method)) || is(T:const(Result)) || is(T:const(Error));

    enum SignedState {
        INVALID = -1,
        NOSIGN = 0,
        VALID = 1
    }

    enum Type : uint {
        none,
        method,
        result,
        error
    }

    enum Direction {
        SEND,
        RECEIVE
    }

    static Type getType(T)(const T message) if(isHiBONRecord!T) {
        static if (is(T:const(Method))) {
            return Type.method;
        }
        else static if (is(T:const(Result))) {
            return Type.result;
        }
        else static if (is(T:const(Error))) {
            return Type.error;
        }
        else {
            return getType(message.toDoc);
        }
    }

    static Type getType(const Document doc) {
        import std.conv : to;
        writefln("getType.doc=", doc.toJSON.toPrettyString);
        enum messageName=GetLabel!(Sender.message).name;
        writefln("messageName=%s", messageName);
        writefln("doc.hasMember(messageName)=%s", doc.hasMember(messageName));
        writefln("doc[messageName].type=%s", doc[messageName].type);
        writefln("doc[messageName].data=%s", doc[messageName].data);
        writefln("doc[messageName].key=%s", doc[messageName].key);

        const message_doc=doc[messageName].get!Document;
        writefln("message_doc.data=%s", message_doc.data);
        writefln("message_doc.data.length=%s", message_doc.data.length);
        writefln("message_doc.length=%s", message_doc.length);

        writefln("message_doc.keys=%s", message_doc.keys);
        writefln("message_doc=%s", message_doc.toJSON.toPrettyString);
        foreach(E; EnumMembers!(Type)[1..$]) {
            enum name=E.to!string;
            writeln(name);
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
            Result result;
            Error error;
        }

        @disable this();
//        @Label("") SecureNet net;
        @Label("$sign", true) @(Filter.Initialized) Signature signature;
        @Label("$pkey", true) @(Filter.Initialized) Pubkey pubkey;
        @Label("$msg") Document message;
        @Label("") immutable Type type;

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
            this(const SecureNet net, const Document doc)
                in {
                    if (signature.length) {
                        assert(net !is null, "The signature can't be veified because the SecureNet is missing");
                    }
                }
            do {
                check(!doc.hasHashKey, "Document containing hashkey can not be used as a message in HiPRC");
                writefln("receiver.doc=%s", doc.toJSON.toPrettyString);

                type=getType(doc);
                writefln("type=%s", type);
                writefln("After receiver=%s", doc.toJSON.toPrettyString);

                enum signName=GetLabel!(signature).name;
                enum pubkeyName=GetLabel!(pubkey).name;
                enum messageName=GetLabel!(message).name;
                writefln("signName=%s", signName);
                writefln("pubkeyName=%s", pubkeyName);
                message=doc[messageName].get!Document;
                signature=doc.hasMember(signName)?doc[signName].get!(TypedefType!Signature):null;
                pubkey=doc.hasMember(pubkeyName)?doc[pubkeyName].get!(TypedefType!Pubkey):null;
                Pubkey used_pubkey;
                static SignedState verifySignature(const SecureNet net, const Document doc, const Signature sgn, const Pubkey pkey) {
                    if (sgn.length) {
                        //immutable fingerprint=net.hashOf(msg);
                        if (net is null) {
                            return SignedState.INVALID;
                        }
                        Pubkey used_pubkey=pkey;
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
                    writefln("set_message type=%s", type);
                    with (Type) {
                        final switch(type) {
                        case none:
                            check(0, "Invalid HiPRC message");
                            break;
                        case method:
                            writefln("Method=%s", message.toJSON.toPrettyString);
                            _message.method=Method(message);
                            break;
                        case result:
                            _message.result=Result(message);
                            break;
                        case error:
                            _message.error=Error(message);
                        }
                    }
                }
                set_message;
                signed=verifySignature(net, message, signature, pubkey);
            }
            this(T)(const SecureNet net, T pack) if (isHiBONRecord!T) {
                this(net, pack.toDoc);
            }
            @trusted const(Error) error() const {
                check(type is Type.error, format("Message type %s expected not %s", Type.error, type));
                return _message.error;
            }

            @trusted const(Result) result() const {
                check(type is Type.result, format("Message type %s expected not %s", Type.result, type));
                return _message.result;
            }

            @trusted const(Method) method() const {
                check(type is Type.method, format("Message type %s expected not %s", Type.method, type));
                return _message.method;
            }
        }
        else {
            this(T)(const SecureNet net, const T post) if (isHiBONRecord!T || is(T:const Document)) {
                static if (isHiBONRecord!T) {
                    message=post.toDoc;
                }
                else {
                    message=post;
                }
                type=getType(post);
                writefln("Post.type=%s", type);
                if (net !is null) {
                    immutable fingerprint=net.hashOf(message);
                    signature=net.sign(fingerprint);
                    pubkey=net.pubkey;
                }
            }
            Error error() const
                in {
                    assert(type is Type.error, format("Message type %s expected not %s", Type.error, type));
                }
            do {
                return Error(message);
            }

            Result result() const
                in {
                    assert(type is Type.result, format("Message type %s expected not %s", Type.result, type));
                }
            do {
                return Result(message);
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

    alias Sender=Post!(Direction.SEND);
    alias Receiver=Post!(Direction.RECEIVE);

    interface Supports {
        static bool supports(ref const(Receiver) receiver);
    }

    mixin template Support(Enum) {
        import tagion.communication.HiRPC : HiRPC;
        import std.traits : EnumMembers;
        static bool supports(const HiRPC.Method message) {
            switch (message.name) {
                static foreach(E; EnumMembers!Enum) {
                case E.stringof:
                    return true;
                }
            default:
                return false;
            }
            assert(0);
        }
    }

    alias check=Check!HiRPCException;
    SecureNet net;

    const(uint) generateId(){
        uint id = 0;
        import tagion.utils.Random;
        import stdrnd = std.random;
        auto rnd = Random!uint(stdrnd.unpredictableSeed);
        do {
            id = rnd.value();
        } while (id is 0);
        return id;
    }


    const(Sender) opDispatch(string method,T)(T params, const uint id=0) {
        pragma(msg, "method=",method, " T=", T);
        return action(method, params, id);
    }

    const(Sender) action(string method, const Document params, const uint id=0) {
        Method message;
        writefln("action doc method %s %s", method, params.keys);
        if (id is 0) {
            message.id=generateId;
        }
        if (!params.empty) {
            message.params=params;
        }
        message.name=method;
        message.params=params;
        auto sender= Sender(net, message);
        writefln("sender=%s", sender.toJSON.toPrettyString);
        return sender;
    }

    const(Sender) action(T)(string method, T params, const uint id = 0) if (isHiBONRecord!T) {
        return action(method, params.toDoc, id);
    }

    const(Sender) action(string method, const(HiBON) params=null, const uint id = 0)  {
        const doc=Document(params.serialize);
        writefln("action method %s %s", method, doc.keys);
        return action(method, doc, id);
    }

    const(Sender) result(ref const(Receiver) receiver, const Document params) const {
        Result message;
        message.id=receiver.method.id;
        message.result=params;
        const method = receiver.method;
        auto sender = Sender(net, message);
        return sender;
    }

    const(Sender) result(T)(ref const(Receiver) receiver, T params) const if (isHiBONRecord!T) {
        return result(receiver, params.toDoc);
    }

    const(Sender) result(ref const(Receiver) receiver, const(HiBON) params) const {
        return result(receiver, Document(params.serialize));
    }

    const(Sender) error(ref const(Receiver) receiver, string msg, const int code=0, Document data=Document()) const {
        Error message;
        message.id=receiver.method.id;
        message.code=code;
        message.data=data;
        message.message=msg;
        auto sender = Sender(net, message);
        return sender;
    }

    final const(Receiver) receive(Document doc) const {
        auto receiver=Receiver(net, doc);
        return receiver;
    }


    version(none)
    const(Sender) error(ref const(Receiver) receiver, HiBON params) const {
        Sender sender;
        with(sender) {
            message.id=receiver.message.id;
            hirpc=receiver.hirpc;
            type=HiRPCType.ERROR;
        }
        sender.error=params;
        return sender;
    }

    version(none)
    const(Sender) error(string message, const int code, HiBON hibon_data=null) const {
        Sender sender;
        auto hibon_error=new HiBON;
        hibon_error[Keywords.code]=code;
        hibon_error[Keywords.message]=message;
        if ( hibon_data ) {
            hibon_error[Keywords.data]=hibon_data;
        }
        with (sender) {
            hirpc=HiRPC_version;
            type=HiRPCType.ERROR;
        }
        sender.error=hibon_error;
        return sender;
    }

    // const(Receiver) receive(Document doc) const {
    //     auto receiver=
    //     return Receiver(net, doc);
    // }

    // const(HiBON) toHiBON(ref const(Sender) sender ) const {
    //     return sender.toHiBON(net);
    // }

    // alias Sender=HiRPCPost!HiBON;
    // alias Receiver=HiRPCPost!(const Document);

    static void check_type(T)(Document doc, string key) {
        immutable msg=format("Wrong type of member '%s', expected type but the type was",
            key);
        enum E=Document.Value.asType!T;
        // immutable msg=format("Wrong type of member '%s', expected type %s but the type was %s",
        //     key, TypeString!T, doc[key].typeString);
        check(doc[key].type is E, msg);
    }

    static void check_element(T)(Document doc, string key) {
        check(doc.hasMember(key), format("Member '%s' missing", key));
        check_type!T(doc, key);
    }

    version(none)
    struct HiRPCPost(DOCType) if (is(DOCType:const(Document)) || is(DOCType:HiBON))  {
        @Label("$sign", true) Buffer signature;
        @Label("$pkey", true) Pubkey pubkey;
        @Label("*", true) DOCType params;
        @Label("*", true) DOCType data; // Optional field for the error reporting
        HiRPCMessage message;
        string hirpc;
        struct HiRPCMessage {
            @Label("*", true) @(Filter.Initialized) uint id;
            string method;
            @Label("*", true) int code; // used for error codes
            mixin HiBONRecord;
        }
        static HiRPCPost undefined() {
            check(false, "Undefined HPRC package");
            assert(0);
        }
        static if (is(DOCType==HiBON)) {
            @Label("") HiRPCType type;
            HiBON toHiBON(const(SecureNet) net) const {
                auto message_hibon=new HiBON;
                // if ( message.id > 0 ) {
                //     message_hibon[Keywords.id]=message.id;
                // }

                with(HiRPCType) final switch(type) {
                    case ACTION:
                        message_hibon[Keywords.method]=message.method;
                        if ( params ) {
                            message_hibon[Keywords.params]=params;
                        }
                        break;
                    case RESULT:
                        message_hibon[Keywords.result]=result;
                        break;
                    case ERROR:
                        message_hibon[Keywords.error]=error;
                        if ( data ) {
                            message_hibon[Keywords.data]=data;
                        }
                        if ( message.code ) {
                            message_hibon[Keywords.code]=message.code;
                        }
                        break;
                    case NONE:
                        check(false, "The HiRPC does not contain a messaeg type");
                    }
                auto hibon=new HiBON;
                immutable message_data=message_hibon.serialize;
                auto message_doc=Document(message_data);
                hibon[Keywords.message]=message_doc;
                hibon[Keywords.hirpc]=HiRPC_version;
                if ( net ) {
                    immutable fingerprint=net.calcHash(message_data);
                    immutable signature=net.sign(fingerprint);
                    hibon[Keywords.signature]=signature;
                    hibon[Keywords.pubkey]=net.pubkey;
                }
                return hibon;
            }
            // Buffer serialize() const {
            //     return toHIBON.serialize;
            // }
        }
        else {
            alias result=params;
            alias error=params;
            @Label("") immutable HiRPCType type;
            @Label("") immutable bool verified;
            @Label("") immutable(Buffer) fingerprint;
            this(const(SecureNet) net, const(Document) doc) {
                check_element!Document(doc, Keywords.message);
                auto message_doc=doc[Keywords.message].get!Document;
                if ( doc.hasMember(Keywords.signature) ) {
                    signature=doc[Keywords.signature].get!Buffer;
                    check_element!Buffer(doc, Keywords.pubkey);
                    immutable pubkey_data=doc[Keywords.pubkey].get!Buffer.idup;
                    pubkey=pubkey_data;
                    if ( net ) {
                        fingerprint=net.calcHash(message_doc.data);
                        verified=net.verify(fingerprint, signature, pubkey);
                    }
                }
                if ( message_doc.hasMember(Keywords.id) ) {
                    check_type!uint(message_doc, Keywords.id);
                    message.id=message_doc[Keywords.id].get!uint;
                }

                check_element!string(doc, Keywords.hirpc);
                hirpc=doc[Keywords.hirpc].get!string;
                check(hirpc == HiRPC_version, format("HiRPC version %s not support use %s", hirpc, HiRPC_version));
                if ( message_doc.hasMember(Keywords.method) ) {
                    check(message.id > 0, "Message id must be defined and the value must be greather than 0");
                    type=HiRPCType.ACTION;
                    check_type!string(message_doc, Keywords.method);
                    message.method=message_doc[Keywords.method].get!string;
                    if ( message_doc.hasMember(Keywords.params) ) {
                        immutable doc_data_params=message_doc[Keywords.params].get!Document;
//                        auto test=Document(data_params);
                        params=Document(doc_data_params.data.idup);
                    }
                    else {
                        // None initailized value
                        params=Document(null);
                    }
                    // None initailized value
                    data=null;
                }
                else if ( message_doc.hasMember(Keywords.result) ) {
                    check(message.id > 0, "Message id must be defined and the value must be greather than 0");
                    type=HiRPCType.RESULT;
                    check_type!Document(message_doc, Keywords.result);
                    result=message_doc[Keywords.result].get!Document;
                    // None initailized value
                    //params=Document(null);
                    data=null;
                }
                else if ( message_doc.hasMember(Keywords.error) ) {
                    type=HiRPCType.ERROR;
                    check_type!Document(message_doc, Keywords.error);
                    error=message_doc[Keywords.error].get!Document;
                    if ( message_doc.hasMember(Keywords.data) ) {
                        check_type!Document(message_doc, Keywords.data);
                        data=message_doc[Keywords.data].get!Document;
                    }
                    else {
                        // None initailized value
                        data=null;
                        //params=Document(null);
                    }
                    if ( message_doc.hasMember(Keywords.code) ) {
                        message.code=message_doc[Keywords.code].get!int;
                    }
                }
                else {
                    // None initailized value
                    data=null;
                    params=Document(null);
                    check(false, format("The action member HPRC %s is missing for HiRPC", [Keywords.method, Keywords.result, Keywords.error]));
                }
            }
        }
        bool empty() pure const nothrow {
            return type is HiRPCType.NONE;
        }
    }
}

unittest {
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.crypto.secp256k1.NativeSecp256k1;

    class HiRPCNet : StdSecureNet {
        import tagion.hashgraph.HashGraph;
        this(string passphrase) {
            super();
            generateKeyPair(passphrase);
//        writefln("Pubkey %s:%d", (cast(Buffer)pubkey).toHexString!true, pubkey.length);
        }
    }

    immutable passphrase="Very secret password for the server";
    enum func_name="func_name";

    version(none)
    {
        writefln("Start");
        HiRPC hirpc;
        hirpc.net=new HiRPCNet(passphrase);

        auto params=new HiBON;
        params["test"]=42;
        writeln("Before action");
        const sender=hirpc.action(func_name, params);

        writeln("sender.toDoc");
        auto doc=sender.toDoc;

        writeln("after sender.toDoc");

        const recever=hirpc.receive(doc);

        writefln("recever.verified=%s", recever.method.id);
    }

    version(none)
    {
        writeln("my unit test");
        HiRPC hirpc;
        import tagion.hibon.HiBONJSON;
        // hirpc.net=new HiRPCNet(passphrase);

        // auto params=new HiBON;
        // params["$test"]=5;
        // const sender=hirpc.action("action", params);

        // auto doc=Document(hirpc.toHiBON(sender).serialize);

        // const json=doc.toJSON;
        // writeln(json);
        // assert(json.toString().length > 0);
        {
            HiBON t = new HiBON();
            t["$test"] = 5;
            const sender=hirpc.action("action", t);

            auto test2 = sender.toDoc;
            writeln(test2.toJSON);
            writefln("sender.isSigned=%s", sender.isSigned);
            assert(!sender.isSigned, "This message is un-sigend, which is fine because the HiRPC does not contain a SecureNet");
            {
                const receiver=hirpc.receive(sender.toDoc);
                writefln("receiver=%s", receiver.toPretty);
                assert(receiver.method.id is sender.method.id);
                writefln("receiver.method.name is sender.method.name", receiver.method.name, sender.method.name);
                assert(receiver.method.name is sender.method.name);
                writefln("receiver.signed=%s", receiver.signed);
            }
        }
        // writefln("recever.verified=%s", recever.verified);
    }
}

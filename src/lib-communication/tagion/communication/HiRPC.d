module tagion.communication.HiRPC;

import std.format;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONException;
import tagion.hibon.Document : Document;

import tagion.basic.Basic : Buffer, Pubkey;
import tagion.basic.TagionExceptions : Check;
import tagion.Keywords;
import tagion.gossip.InterfaceNet : SecureNet;

import std.stdio;
import tagion.utils.Miscellaneous : toHexString;


@safe
class HiRPCException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

enum HiRPC_version="2.0";
@safe
struct HiRPC {
    interface Supports {
        static bool supports(ref const(HiRPCReceiver) receiver);
    }

    mixin template Support(Enum) {
        static bool supports(ref const(HiRPCReceiver) receiver) {
            static foreach(method; EnumMembers!Enum) {
                if (method == receiver.message.method) {
                    return true;
                }
            }
            return false;
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

    const(HiRPCSender) opDispatch(string method)(HiBON params, uint id = 0) {
        return action(method, params, id);
    }

    const(HiRPCSender) action(string method, HiBON params, uint id = 0) {
        //     static assert(validate(method), format("RPC methode %s not supported", method));
        HiRPCSender sender;
        with (sender) {
            if (id is 0){
                id = generateId();
            }
            message.id=id;
            message.method=method;
            hirpc=HiRPC_version;
            type=HiRPCType.ACTION;
        }
        if ( params ) {
            sender.params=params;
        }
        return sender;
    }

    const(HiRPCSender) result(ref const(HiRPCReceiver) receiver, HiBON params) const {
        HiRPCSender sender;
        with (sender) {
            message.id=receiver.message.id;
            hirpc=receiver.hirpc;
            type=HiRPCType.RESULT;
        }
        sender.result=params;
        return sender;
    }

    const(HiRPCSender) error(ref const(HiRPCReceiver) receiver, HiBON params) const {
        HiRPCSender sender;
        with(sender) {
            message.id=receiver.message.id;
            hirpc=receiver.hirpc;
            type=HiRPCType.ERROR;
        }
        sender.error=params;
        return sender;
    }

    const(HiRPCSender) error(string message, const int code, HiBON hibon_data=null) const {
        HiRPCSender sender;
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

    const(HiRPCSender) error(ref const(HiRPCReceiver) receiver, string message, const int code, HiBON hibon_data=null) const {
        auto hibon_error=new HiBON;
        hibon_error[Keywords.code]=code;
        hibon_error[Keywords.message]=message;
        if ( hibon_data ) {
            hibon_error[Keywords.data]=hibon_data;
        }
        return error(receiver, hibon_error);
    }

    const(HiRPCReceiver) receive(Document doc) const {
        return HiRPCReceiver(net, doc);
    }

    const(HiBON) toHiBON(ref const(HiRPCSender) sender ) const {
        return sender.toHiBON(net);
    }

    alias HiRPCSender=HiRPCPost!HiBON;
    alias HiRPCReceiver=HiRPCPost!(const Document);
    enum HiRPCType {
        NONE,
        ACTION,
        RESULT,
        ERROR
    }

    static void check_type(T)(Document doc, string key) {
        immutable msg=format("Wrong type of member '%s', expected type but the type was",
            key);
        enum E=Document.Value.asType!T;
        // immutable msg=format("Wrong type of member '%s', expected type %s but the type was %s",
        //     key, TypeString!T, doc[key].typeString);
        check(doc[key].type is E, msg);
    }

    static void check_element(T)(Document doc, string key) {
        check(doc.hasElement(key), format("Member '%s' missing", key));
        check_type!T(doc, key);
    }

    struct HiRPCPost(DOCType) {
        Buffer signature;
        Pubkey pubkey;
        alias result=params;
        alias error=params;
        DOCType params;
        DOCType data; // Optional field for the error reporting
        HiRPCMessage message;
        string hirpc;
        struct HiRPCMessage {
            uint id;
            string method;
            int code; // used for error codes
        }
        static HiRPCPost undefined() {
            check(false, "Undefined HPRC package");
            assert(0);
        }
        static if (is(DOCType==HiBON)) {
            HiRPCType type;
            HiBON toHiBON(const(SecureNet) net) const {
                auto message_hibon=new HiBON;
                if ( message.id > 0 ) {
                    message_hibon[Keywords.id]=message.id;
                }

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
            immutable HiRPCType type;
            immutable bool verified;
            immutable(Buffer) fingerprint;
            this(const(SecureNet) net, const(Document) doc) {
                check_element!Document(doc, Keywords.message);
                auto message_doc=doc[Keywords.message].get!Document;
                if ( doc.hasElement(Keywords.signature) ) {
                    signature=doc[Keywords.signature].get!Buffer;
                    check_element!Buffer(doc, Keywords.pubkey);
                    immutable pubkey_data=doc[Keywords.pubkey].get!Buffer.idup;
                    pubkey=pubkey_data;
                    if ( net ) {
                        fingerprint=net.calcHash(message_doc.data);
                        verified=net.verify(fingerprint, signature, pubkey);
                    }
                }
                if ( message_doc.hasElement(Keywords.id) ) {
                    check_type!uint(message_doc, Keywords.id);
                    message.id=message_doc[Keywords.id].get!uint;
                }

                check_element!string(doc, Keywords.hirpc);
                hirpc=doc[Keywords.hirpc].get!string;
                check(hirpc == HiRPC_version, format("HiRPC version %s not support use %s", hirpc, HiRPC_version));
                if ( message_doc.hasElement(Keywords.method) ) {
                    check(message.id > 0, "Message id must be defined and the value must be greather than 0");
                    type=HiRPCType.ACTION;
                    check_type!string(message_doc, Keywords.method);
                    message.method=message_doc[Keywords.method].get!string;
                    if ( message_doc.hasElement(Keywords.params) ) {
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
                else if ( message_doc.hasElement(Keywords.result) ) {
                    check(message.id > 0, "Message id must be defined and the value must be greather than 0");
                    type=HiRPCType.RESULT;
                    check_type!Document(message_doc, Keywords.result);
                    result=message_doc[Keywords.result].get!Document;
                    // None initailized value
                    //params=Document(null);
                    data=null;
                }
                else if ( message_doc.hasElement(Keywords.error) ) {
                    type=HiRPCType.ERROR;
                    check_type!Document(message_doc, Keywords.error);
                    error=message_doc[Keywords.error].get!Document;
                    if ( message_doc.hasElement(Keywords.data) ) {
                        check_type!Document(message_doc, Keywords.data);
                        data=message_doc[Keywords.data].get!Document;
                    }
                    else {
                        // None initailized value
                        data=null;
                        //params=Document(null);
                    }
                    if ( message_doc.hasElement(Keywords.code) ) {
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
    import tagion.gossip.GossipNet;
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
    enum method="method";
    {
        HiRPC hirpc;
        hirpc.net=new HiRPCNet(passphrase);

        auto params=new HiBON;
        params["test"]=42;
        const sender=hirpc.action(method, params);

        auto doc=Document(hirpc.toHiBON(sender).serialize);

        const recever=hirpc.receive(doc);

        // writefln("recever.verified=%s", recever.verified);
    }
}

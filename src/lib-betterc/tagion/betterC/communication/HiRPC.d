module tagion.betterC.communication.HiRPC;

import std.format;
import std.traits : EnumMembers;
import tagion.basic.Types : Buffer;
import tagion.betterC.hibon.Document;
import tagion.betterC.hibon.HiBON;
import tagion.betterC.utils.Memory;
import tagion.betterC.wallet.Net;
import tagion.betterC.wallet.WalletRecords : GetLabel, Label;
import tagion.crypto.Types : Pubkey, Signature;

struct HiRPC {
    // import tagion.hibon.HiBONRecord;

    struct Method {
        @Label("*", true) uint id;
        @Label("*", true) Document params;
        @Label("method") string name;

        this(Document doc) {
            enum id_name = GetLabel!(id).name;
            enum params_name = GetLabel!(params).name;
            enum method_name = GetLabel!(name).name;

            id = doc[id_name].get!uint;
            params = doc[params_name].get!Document;
            name = doc[method_name].get!string;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            enum id_name = GetLabel!(id).name;
            enum params_name = GetLabel!(params).name;
            enum method_name = GetLabel!(name).name;

            hibon[id_name] = id;
            hibon[params_name] = params;
            hibon[method_name] = name;

            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    struct Response {
        @Label("*", true) uint id;
        Document result;

        this(Document doc) {
            enum id_name = GetLabel!(id).name;
            enum result_name = GetLabel!(result).name;

            id = doc[id_name].get!uint;
            result = doc[result_name].get!Document;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            enum id_name = GetLabel!(id).name;
            enum result_name = GetLabel!(result).name;

            hibon[id_name] = id;
            hibon[result_name] = result;

            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    struct Error {
        @Label("*", true) uint id;
        @Label("*", true) Document data;
        @Label("*", true) string message;
        @Label("*", true) int code;

        this(Document doc) {
            enum id_name = GetLabel!(id).name;
            enum data_name = GetLabel!(data).name;
            enum message_name = GetLabel!(message).name;
            enum code_name = GetLabel!(code).name;

            id = doc[id_name].get!uint;
            data = doc[data_name].get!Document;
            message = doc[message_name].get!string;
            code = doc[code_name].get!int;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();

            enum id_name = GetLabel!(id).name;
            enum data_name = GetLabel!(data).name;
            enum message_name = GetLabel!(message).name;
            enum code_name = GetLabel!(code).name;

            hibon[id_name] = id;
            hibon[data_name] = data;
            hibon[message_name] = message;
            hibon[code_name] = code;

            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }

        static bool valid(const Document doc) {
            enum codeName = GetLabel!(code).name;
            enum messageName = GetLabel!(message).name;
            enum dataName = GetLabel!(data).name;
            return doc.hasMember(codeName) || doc.hasMember(messageName) || doc.hasMember(dataName);
        }

    }

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

    struct Post(Direction DIRECTION) {
        union Message {
            Method method;
            Response response;
            Error error;
        }

        @disable this();
        @Label("$sign", true) immutable(ubyte)[] signature;
        @Label("$pkey", true) immutable(ubyte)[] pubkey;
        @Label("$msg") Document message;
        @Label("") immutable Type type;

        this(Document doc) {
            enum signature_name = GetLabel!(signature).name;
            enum pubkey_name = GetLabel!(pubkey).name;
            enum message_name = GetLabel!(message).name;
            enum type_name = GetLabel!(type).name;

            auto received_sign = doc[signature_name].get!Buffer;
            signature.create(received_sign.length);
            signature = received_sign;

            auto received_pubkey = doc[pubkey_name].get!Buffer;
            pubkey.create(received_pubkey.length);
            pubkey = received_pubkey;

            message = doc[message_name].get!Document;
            type = cast(Type) doc[type_name].get!uint;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();

            enum signature_name = GetLabel!(signature).name;
            enum pubkey_name = GetLabel!(pubkey).name;
            enum message_name = GetLabel!(message).name;
            enum type_name = GetLabel!(type).name;
            hibon[signature_name] = signature;
            hibon[pubkey_name] = pubkey;
            hibon[message_name] = message;
            hibon[type_name] = cast(uint) type;

            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }

        bool supports(T)() const {
            import std.algorithm.searching : canFind;
            import std.traits : isCallable;

            return (type is Type.method) &&
                Callers!T.canFind(method.name);
        }

        bool verify(const Document doc) {
            return true;
        }

        static if (DIRECTION is Direction.RECEIVE) {
            @Label("") protected Message _message;
            @Label("") immutable SignedState signed;
            enum signName = GetLabel!(signature).name;
            enum pubkeyName = GetLabel!(pubkey).name;
            enum messageName = GetLabel!(message).name;
            // this(const Document doc) {
            //     this(null, doc);
            // }

            this(const SecureNet net, const Document doc) {
                enum type_name = GetLabel!(type).name;
                type = cast(Type) doc[type_name].get!uint;
                message = doc[messageName].get!Document;

                enum signature_name = GetLabel!(signature).name;
                enum pubkey_name = GetLabel!(pubkey).name;
                auto received_sign = doc[signature_name].get!Buffer;
                signature.create(received_sign.length);
                signature = received_sign[0 .. $];

                auto received_pubkey = doc[pubkey_name].get!Buffer;
                pubkey.create(received_pubkey.length);
                pubkey = received_pubkey[0 .. $];
                static SignedState verifySignature(const SecureNet net, const Document doc, const(
                        ubyte[]) sgn, const(ubyte[]) pkey) {
                    if (sgn.length) {
                        //                 //immutable fingerprint=net.hashOf(msg);
                        if (net.verify(doc.serialize, sgn, pkey)) {
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

            //     this(T)(const SecureNet net, T pack) if (isHiBONRecord!T) {
            //         this(net, pack.toDoc);
            //     }

            @trusted const(Error) error() const pure {
                return _message.error;
            }

            @trusted const(Response) response() const pure {
                return _message.response;
            }

            @trusted const(Method) method() const pure {
                return _message.method;
            }

            const(T) params(T, Args...)(Args args) {
                return T(args, method.params);
            }

            const(T) result(T, Args...)(Args args) {
                return T(response.result);
            }

            // @trusted
            // bool isRecord(T)() const {
            //     with (Type) {
            //         final switch (type) {
            //         case none, error:
            //             return false;
            //         case method:
            //             return T.isRecord(_message.method.params);
            //         case result:
            //             return T.isRecord(_message.response.result);
            //         }
            //     }
            //     assert(0);
            // }
        }
        else {
            this(T)(const SecureNet net, const T post) {
                message = post;
                // type = getType(post);
                auto doc = post;
                enum type_name = GetLabel!(type).name;
                type = cast(Type) doc[type_name].get!uint;
                // immutable signed=net.sign(message);
                // fingerprint=signed.message;

                // signature = net.sign(message.serialize).signature;

                pubkey.create(net.pubkey.length);
                // pubkey = net.pubkey;
            }

            Error error() const {
                return Error(message);
            }

            Response response() const {
                return Response(message);
            }

            Method method() const {
                return Method(message);
            }

            /++
             Checks if the message has been signed
             NOTE!! This does not mean that the signature is correct
             Returns:
             True if the message has been signed
             +/
            bool isSigned() const pure {
                return (signature.length !is 0);
            }
        }

    }

    alias Sender = Post!(Direction.SEND);
    alias Receiver = Post!(Direction.RECEIVE);
    const SecureNet net;

    const(uint) generateId() const {
        uint id = 0;
        // import tagion.utils.Random;
        // import stdrnd = std.random;

        // auto rnd = Random!uint(stdrnd.unpredictableSeed);
        do {
            //     id = rnd.value();
        }
        while (id is 0 || id is uint.max);
        return id;
    }

    const(Sender) action(string method, const Document params, const uint id = uint.max) const {
        Method message;
        message.id = (id is uint.max) ? generateId : id;
        if (!params.empty) {
            message.params = params;
        }
        message.name = method;
        message.params = params;
        auto sender = Sender(net, message.toDoc);
        return sender;
    }

    const(Sender) action(string method, HiBONT params, const uint id = uint.max) const {
        const doc = Document(params);
        return action(method, doc, id);
    }

    final const(Receiver) receive(Document doc) const {
        auto receiver = Receiver(net, doc);
        return receiver;
    }

}

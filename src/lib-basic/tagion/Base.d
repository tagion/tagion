module tagion.Base;

import tagion.crypto.Hash;
import tagion.bson.BSONType;
private import tagion.hashgraph.ConsensusExceptions;
private import std.string : format, join, strip;
private import std.traits;
import std.bitmanip : BitArray;

// private import std.algorithm : splitter;

enum this_dot="this.";

import std.conv;

import std.typecons : Typedef, TypedefType;

enum BufferType {
    PUBKEY,
    PRIVKEY,
    SIGNATURE,
    HASHPOINTER,
    MESSAGE
}


alias Buffer=immutable(ubyte)[];
alias Pubkey     =Typedef!(Buffer, null, BufferType.PUBKEY.stringof);
version(none) {
alias Privkey    =Typedef!(Buffer, null, BufferType.PRIVKEY.stringof);
alias Signature  =Typedef!(Buffer, null, BufferType.SIGNATURE.stringof);
alias Message    =Typedef!(Buffer, null, BufferType.SIGNATURE.stringof);
alias HashPointer=Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);

}
//template isBufferType(T) {
//    alias isBuffer=true;
enum isBufferType(T)=is(T : immutable(ubyte[]) ) || is(TypedefType!T : immutable(ubyte[]) );

static unittest {
    static assert(isBufferType!(immutable(ubyte[])));
    static assert(isBufferType!(immutable(ubyte)[]));
    static assert(isBufferType!(Pubkey));
    pragma(msg, TypedefType!int);
}

unittest {
    immutable buf=cast(Buffer)"Hello";
    immutable pkey=Pubkey(buf);
}

BUF buf_idup(BUF)(immutable(Buffer) buffer) {
    return cast(BUF)(buffer.idup);
}


/**
   Return the position of first '.' in string and
 */
template find_dot(string str, size_t index=0) {
    static if ( index >= str.length ) {
        enum zero_index=0;
        alias zero_index find_dot;
    }
    else static if (str[index] == '.') {
        enum index_plus_one=index+1;
        static assert(index_plus_one < str.length, "Static name ends with a dot");
        alias index_plus_one find_dot;
    }
    else {
        alias find_dot!(str, index+1) find_dot;
    }
}

void set_bitarray(out BitArray bits, uint length) @trusted {
    bits.length=length;
}

string toText(const(BitArray) bits) @trusted {
    return bits.to!string;
}

/**
   Template function for removing the "this." prefix
 */
template basename(alias K) {
    enum name=K.stringof;
    static if (
        (name.length > this_dot.length) &&
        (name[0..this_dot.length] == this_dot) ) {
        alias name[this_dot.length..$] basename;
    }
    else {
        enum dot_pos=find_dot!(name);
        static if ( dot_pos > 0 ) {
            enum suffix=name[dot_pos..$];
            alias suffix basename;
        }
        else {
            alias name basename;
        }
    }
}

unittest {
    enum name_another="another";
    struct Something {
        mixin("int "~name_another~";");
        void check() {
            assert(find_dot!(this.another.stringof) == this_dot.length);
            assert(basename!(this.another) == name_another);
        }
    }
    Something something;
    static assert(find_dot!((something.another).stringof) == something.stringof.length+1);
    static assert(basename!(something.another) == name_another);
    something.check();
}

template EnumText(string name, string[] list, bool first=true) {
    static if ( first ) {
        enum begin="enum "~name~"{";
        alias EnumText!(begin, list, false) EnumText;
    }
    else static if ( list.length > 0 ) {
        enum k=list[0];
        enum code=name~k~" = "~'"'~k~'"'~',';
        alias EnumText!(code, list[1..$], false) EnumText;
    }
    else {
        enum code=name~"}";
        alias code EnumText;
    }
}

unittest {
    enum list=["red", "green", "blue"];
//    pragma(msg, EnumText!("Colour", list));
    mixin(EnumText!("Colour", list));
    static assert(Colour.red == list[0]);
    static assert(Colour.green == list[1]);
    static assert(Colour.blue == list[2]);

}

// enum ThreadState {
//     KILL = 9,
//     LIVE = 1
// }

enum Control{
//    KILL=9,
    LIVE=1,
    STOP,
    FAIL,
    ACK,
    REQUEST,
    END
};

@safe
immutable(Hash) hfuncSHA256(immutable(ubyte)[] data) {
    import tagion.crypto.SHA256;
    return SHA256(data);
}

@safe
template convertEnum(Enum, Consensus) {
    //   static if ( (is(Enum==enum)) && (is(Consensus:ConsensusException)) ) {
    const(Enum) convertEnum(uint enum_number, string file = __FILE__, size_t line = __LINE__) {
            if ( enum_number <= Enum.max) {
                return cast(Enum)enum_number;
            }
            throw new Consensus(ConsensusFailCode.NETWORK_BAD_PACKAGE_TYPE, file, line);
            assert(0);
        }
    // }
}

@safe
template consensusCheck(Consensus) {
    static if ( is(Consensus:ConsensusException) ) {
        void consensusCheck(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
            if (!flag) {
                throw new Consensus(code, file, line);
            }
        }
    }
}

@safe
template consensusCheckArguments(Consensus) {
    static if ( is(Consensus:ConsensusException) ) {
        ref auto consensusCheckArguments(A...)(A args) {
            struct Arguments {
                A args;
                void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) const {
                    if ( !flag ) {
                        immutable msg=format(consensus_error_messages[code], args);
                        throw new Consensus(msg, code, file, line);
                    }
                }
            }
            return const(Arguments)(args);
        }
    }
}

@safe
string cutHex(BUF)(BUF buf) if ( isBufferType!BUF )  {
    import std.format;
    enum LEN=8;
    if ( buf.length <= LEN ) {
        return format("EMPTY[%s]",buf.length);
    }
    else {
        return buf[0..LEN].toHexString;
    }
}

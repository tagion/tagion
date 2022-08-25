module tagion.basic.Types;

import std.typecons : Typedef, TypedefType;

enum BufferType
{
    PUBKEY, /// Public key buffer type
    PRIVKEY, /// Private key buffer type
    SIGNATURE, /// Signature buffer type
    HASHPOINTER, /// Hash pointre buffer type
    MESSAGE, /// Message buffer type
    PAYLOAD /// Payload buffer type
}

enum BillType
{
    NON_USABLE,
    TAGIONS,
    CONTRACTS
}

alias Buffer = immutable(ubyte)[]; /// General buffer
alias Pubkey = Typedef!(Buffer, null, BufferType.PUBKEY.stringof); // Buffer used for public keys
alias Signature = Typedef!(Buffer, null, BufferType.SIGNATURE.stringof);
alias Privkey = Typedef!(Buffer, null, BufferType.PRIVKEY.stringof);

alias Payload = Typedef!(Buffer, null, BufferType.PAYLOAD.stringof); // Buffer used fo the event payload
version (none)
{
    alias Message = Typedef!(Buffer, null, BufferType.MESSAGE.stringof);
    alias HashPointer = Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);
}

/+
 Returns:
 true if T is a buffer
+/
enum isBufferType(T) = is(T : const(ubyte[])) || is(TypedefType!T : const(ubyte[]));
enum isBufferTypeDef(T) = is(TypedefType!T : const(ubyte[])) && !is(T : const(ubyte[]));

static unittest
{
    static assert(isBufferType!(immutable(ubyte[])));
    static assert(isBufferType!(immutable(ubyte)[]));
    static assert(isBufferType!(Pubkey));
}

/++
 Genera signal
+/
enum Control
{
    LIVE = 1, /// Send to the ownerTid when the task has been started
    STOP, /// Send when the child task to stop task
    //    FAIL,   /// This if a something failed other than an exception
    END /// Send for the child to the ownerTid when the task ends
}

enum FileExtension
{
    json = "json", // JSON File format
    hibon = "hibon", // HiBON file format
    wasm = "wasm", // WebAssembler binary format
    wast = "wast", // WebAssembler text format
    dart = "drt", // DART data-base
    markdown = "md", // DART data-base
    dsrc = "d", // DART data-base
}

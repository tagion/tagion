module tagion.tools.boot.genesis;

import tagion.hibon.HiBONtoText : decode;
import tagion.crypto.Types : Pubkey;
import std.algorithm;
import std.array;

@safe:
void createGenesis(const(string[]) nodekey_text) {
    import std.stdio;

    const nodekeys = nodekey_text
        .map!(key => Pubkey(key.decode))
        .array;
    writefln("nodekeys=%(%(%02x%) %)", nodekeys);
}

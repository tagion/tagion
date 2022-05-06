module tagion.script.ScriptCrypto;

import std.bigint;
import tagion.script.Script;
import tagion.script.ScriptBase : Value, FunnelType, check, ScriptException;
import tagion.script.ScriptParser;

//import tagion.utils.BSON : BSON, HBSON, BSONException;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBON : HiBON;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.basic.Types : Buffer, Pubkey, Signature;
import tagion.basic.ConsensusExceptions;
import tagion.script.ScriptBuilder : ScriptBuilder;
import tagion.script.ScriptParser;
import tagion.script.ScriptBase;
import std.algorithm.sorting : sort;
import std.array : join;

import tagion.crypto.secp256k1.NativeSecp256k1 : NativeSecp256k1;

@safe
class CryptoNet : StdSecureNet {
    this() {
        super();
    }
}

@safe
class ScriptPay : ScriptElement {
    mixin ScriptElementTemplate!("PAY", 0);
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto bills = sc.pop.get!Number;
        return next;
    }
}

@safe
class ScriptCryptoVerify : ScriptElement {
    /*
        Verify a signature on a message by a public key
        message signature pubkey verify
    */
    mixin ScriptElementTemplate!("verify", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        try {
            auto message = sc.pop.get!Buffer;
            Signature signature = sc.pop.get!Buffer;
            Pubkey pubkey = sc.pop.get!Buffer;

            auto crypto_net = new CryptoNet();
            immutable res = crypto_net.verify(message, signature, cast(Pubkey) pubkey);

            sc.push(res);

            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this);
        }
        catch (ConsensusException ex) {
            return new ScriptError(name ~ " got an Consensus Exception: " ~ ex.msg, this);
        }
    }
}

version (none) unittest { // verify test
    assert("verify" in Script.opcreators);

    auto crypto_net = new CryptoNet(new NativeSecp256k1);
    Buffer msg = [2, 3, 4, 5, 5, 5];
    Buffer hash_msg = crypto_net.calcHash(msg);
    crypto_net.generateKeyPair("test123");
    Pubkey pubkey = crypto_net.pubkey;
    Buffer sig = crypto_net.sign(hash_msg);
    assert(crypto_net.verify(hash_msg, sig, pubkey));

    import std.string : join;

    string source = [
        "variable pubkey",
        "variable sig",
        "variable hash_msg",
        ": testverify",
        "hash_msg !",
        "sig !",
        "pubkey !",
        "pubkey @ sig @ hash_msg @ verify",
        ";"
    ].join("\n");

    Script script;
    /+
    auto script_builder=new ScriptBuilder();
    script_builder.build(script, source);
+/
    auto parser = ScriptParser(source);
    auto script_builder = ScriptBuilder(parser[]);
    script = script_builder.build(script, source);

    auto sc = new ScriptContext(10, 10, 10, 10);
    sc.push(Value(cast(Buffer)(pubkey)));
    sc.push(Value(sig));
    sc.push(Value(hash_msg));
    sc.trace = false;
    script.run("testverify", sc);

    assert(sc.peek.ftype is FunnelType.NUMBER);
    assert(sc.pop.get!Number == 1);
}

@safe
class ScriptCryptoHash256 : ScriptElement {
    /*
        Hash a byte[] by SHA256 bit
        data hash256
    */
    mixin ScriptElementTemplate!("hash256", 0);
    import std.stdio : writefln;

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        try {
            auto data = sc.pop.get!Buffer;



            .check(data.length is 0, "The data cannot be empty");

            auto crypto_net = new CryptoNet();
            auto h = crypto_net.calcHash(data);

            sc.push(h);

            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this);
        }
        catch (ConsensusException ex) {
            return new ScriptError(name ~ " got an Consensus Exception: " ~ ex.msg, this);
        }
    }
}

version (none) unittest { // hash256 test
    assert("hash256" in Script.opcreators);

    auto crypto_net = new CryptoNet(new NativeSecp256k1);
    Buffer seed = [2, 3, 4, 1];
    auto facit_hash = crypto_net.calcHash(seed);

    import std.string : join;

    string source = [
        "variable seed",
        "variable hash",
        ": testhash",
        "seed !",
        "seed @ hash256 hash !",
        "hash @",
        ";"
    ].join("\n");

    Script script;

    auto parser = ScriptParser(source);
    auto script_builder = ScriptBuilder(parser[]);
    script_builder.build(script, source);

    auto sc = new ScriptContext(10, 10, 10, 10);
    sc.push(Value(seed));

    script.run("testhash", sc);

    assert(sc.peek.ftype is FunnelType.BINARY);
    auto res_hash = sc.pop.get!Buffer;
    assert(res_hash == facit_hash);
}

@safe
class ScriptSortHash256 : ScriptElement {
    /*
        Sort an array of hashs, join and return a hash256
        hash_1 hash_2 hash_3...hash_k sorthash256
    */
    mixin ScriptElementTemplate!("sorthash256", 0);
    import std.stdio : writefln;

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        try {
            Buffer[] hashes;

            do {
                hashes ~= sc.pop.get!Buffer;
            }
            while (!sc.stack_empty);

            if (hashes.length < 1) {
                throw new ScriptException("It needs at least one input.");
            }

            hashes.sort();

            const seed = hashes.join();

            auto crypto_net = new CryptoNet();
            auto h = crypto_net.calcHash(seed);

            sc.push(h);

            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this);
        }
        catch (ConsensusException ex) {
            return new ScriptError(name ~ " got an Consensus Exception: " ~ ex.msg, this);
        }
    }
}

version (none) unittest { //sortHash256
    assert("sorthash256" in Script.opcreators);

    auto crypto_net = new CryptoNet(new NativeSecp256k1);
    Buffer seed_0 = [2, 3, 4, 1];
    Buffer seed_1 = [2, 3, 4, 1, 2];
    Buffer seed_2 = [2, 3, 4, 1, 3];

    Buffer seed_sorted = [
        seed_0, seed_2, seed_1
    ].sort.join;

    const facit_hash = crypto_net.calcHash(seed_sorted);

    import std.string : join;

    string source = [
        ": testsorthash256",
        "sorthash256",
        ";"
    ].join("\n");

    Script script;

    auto parser = ScriptParser(source);
    auto script_builder = new ScriptBuilder(parser[]);
    script_builder.build(script, source);

    auto sc = new ScriptContext(10, 10, 10, 10);
    sc.push(Value(seed_0));
    sc.push(Value(seed_1));
    sc.push(Value(seed_2));
    script.run("testsorthash256", sc);

    assert(sc.peek.ftype is FunnelType.BINARY);
    const res_hash = sc.pop.get!Buffer;
    assert(res_hash == facit_hash);

}

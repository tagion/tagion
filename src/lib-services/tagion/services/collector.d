/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/Collector)
module tagion.services.collector;

import tagion.actor.actor;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.Recorder : RecordFactory;
import tagion.services.messages;
import tagion.script.execute;
import tagion.script.common;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types;
import tagion.basic.Types;
import tagion.utils.pretend_safe_concurrency;

import std.typecons;

@safe
struct CollectorOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

import std.stdio;

@safe
struct CollectorService {
    immutable SecureNet net;
    const string dart_task_name;
    const string tvm_task_name;

    // Queue!CollectedSignedContract collections;
    CollectedSignedContract[uint] collections;

    void task() {
        assert(net !is null, "No secure net");
        assert(dart_task_name !is string.init && tvm_task_name !is string.init, "no task names");
        run(&signed_contract, &recorder, &rpc_contract);
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @trusted {
        auto doc = Document(receiver.method.params);
        if (!doc.isRecord!SignedContract) {
            return;
        }
        signed_contract(inputContract(), cast(immutable) SignedContract(doc));
    }

    void signed_contract(inputContract, immutable(SignedContract) s_contract) @trusted {
        auto req = dartReadRR();

        // collections.put(req.id, CollectedSignedContract());
        // collections.peek(req.id).sign_contract = cast(SignedContract) s_contract;
        collections[req.id] = CollectedSignedContract();
        collections[req.id].sign_contract = cast(SignedContract) s_contract;

        import std.algorithm.iteration : map;
        import std.range;

        writefln("Reguesting reads: %s", s_contract.contract.reads.map!(a => format("%(%x%)", a)).array);
        locate(dart_task_name).send(req, s_contract.contract.reads);
        // writefln("Reguesting inputs: %s",  s_contract.contract.inputs.map!(a => format("%(%x%)", a)).array);
        writefln("Reguesting inputs: %s", s_contract.contract.inputs.map!(a => format("%(%x%)", a)).array);
        locate(dart_task_name).send(req, s_contract.contract.inputs);
    }

    void recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) @safe {
        import std.range;
        import tagion.dart.DARTBasic : dartFingerprint;
        import std.algorithm.iteration : map;

        // auto collection = collections.peek(res.id);
        auto collection = res.id in collections;

        const archives = recorder[];
        writefln("recieved fingerprints %s", archives.map!(a => format("%(%x%)", a.fingerprint)).array);
        const s_contract = collection.sign_contract;
        if (s_contract.contract.reads == archives.map!(a => a.fingerprint).array) {
            collection.reads = archives.map!(a => a.toDoc).array.dup;
        }
        if (s_contract.contract.inputs == archives.map!(a => a.fingerprint).array) {
            foreach (dartindex, sign, archive; zip(s_contract.contract.inputs, s_contract.signs, recorder[])) {
                Pubkey pkey = archive.filed[StdNames.owner].get!Buffer;
                // bool verify(const Fingerprint message, const Signature signature, const Pubkey pubkey)
                if (!net.verify(dartFingerprint(dartindex), sign, pkey)) {
                    writefln("Could not verify \nfingerprint %(%x%) \nsignarture %(%x%) \npkey: %(%x%)\n", dartindex, sign, pkey);
                    return;
                }
            }
            collection.inputs = archives.map!(a => a.toDoc).array.dup;
        }
        writefln("%s, %s", collection.inputs is Document[].init, collection.reads is Document[].init);
        if (collection.inputs.length == 0) {
            return;
        }

        (() @trusted => locate(tvm_task_name).send(signedContract(), cast(immutable) collection))();
        // locate(tvm_task_name).send(signedContract(), collections.giveme(res.id));
    }
}

private struct Queue(T) {
    import std.container.dlist;

    private struct Data {
        uint id;
        T payload;
    }

    private DList!Data list;

    void put(uint id, T val) {
        list.insert(Data(id, val));
    }

    immutable(T*) giveme(uint id) @trusted {
        scope (exit) {
            list.removeFront;
        }
        while (list.front.id != id && !list.empty) {
            list.removeFront;
        }

        if (list.front.id == id) {
            return &cast(immutable) list.front.payload;
        }
        assert(0, format("%s, doesn't exist in stack", id));
    }

    T peek(uint id) {
        foreach_reverse (n; list) {
            if (n.id == id) {
                return n.payload;
            }
        }
        assert(0, format("%s, doesn't exist in stack", id));
    }
}

alias CollectorServiceHandle = ActorHandle!CollectorService;

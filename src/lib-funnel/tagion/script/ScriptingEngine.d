module tagion.script.ScriptingEngine;

import std.concurrency;
import tagion.Base : Control, Pubkey, Buffer;
import std.stdio : writeln, writefln;
import tagion.utils.BSON : Document;
import tagion.hashgraph.ConsensusExceptions;
import tagion.utils.BSON;
import core.thread : Thread, seconds;
import std.path;
import std.file;
import tagion.hashgraph.Net : StdSecureNet;
import tagion.hashgraph.GossipNet : SecureNet;
import tagion.crypto.secp256k1.NativeSecp256k1;
import std.string : format;
import tagion.Keywords;
import tagion.Options;
import tagion.script.Script;
import tagion.script.ScriptBuilder;

@safe
void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new ScriptingEngineConsensusException(code, file, line);
    }
}


@safe
class SecureScriptingEngineNet : StdSecureNet {
    import tagion.hashgraph.HashGraph;
    override void request(HashGraph hashgraph, immutable(ubyte[]) fingerprint) {
        assert(0, "Not implement for this test");
    }

    this(NativeSecp256k1 crypt=new NativeSecp256k1()) {
        super(crypt);
    }

    void verifySignatures(immutable(ubyte)[] trans_scrip_obj_data, Document payers, Document signatures) {
        foreach( i; 0..payers.length ) {
            auto payer=payers[i].get!Document;
            auto pub_key=payer[Keywords.pubkey].get!(immutable(ubyte[]));

            auto signatur=signatures[i].get!Document[Keywords.signatur].get!(immutable(ubyte[]));

            auto message = this.calcHash(trans_scrip_obj_data);

            check(this.verify(message, signatur, cast(Pubkey)pub_key),
            ConsensusFailCode.SCRIPTING_ENGINE_SIGNATUR_FAULT);
        }
    }
}


void runScriptingEngine() {
    bool run_scripting_engine=true;

    void handleState (Control ctrl) nothrow pure const {
        with(Control) switch (ctrl) {
            case STOP:
                run_scripting_engine=false;
            break;
            case LIVE:
                run_scripting_engine=true;
            break;
            default:
                assert(0);
        }
    }


    void execute (immutable(ubyte)[] scripting_engine_obj_data) {
        writeln("execute");
        /*
            The data is a binary bson object with a transaction object and the bills in.
            1. Ensure number of bills corresponds to the number of inputs and signatures
            2. Verify each bill's signatur
            3. Execute script
            4. Check input is larger than output
            5. Send bson binary response obj. back.
        */

        auto scr_eng_obj=Document(scripting_engine_obj_data);

        check(scr_eng_obj.isInOrder, ConsensusFailCode.SCRIPTING_ENGINE_HBSON_FORMAT_FAULT);

        check(scr_eng_obj.hasElement(Keywords.bills), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto bills= scr_eng_obj[Keywords.bills].get!Document;
        immutable number_of_bills = bills.length;

        check(scr_eng_obj.hasElement(Keywords.transaction_obj), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto trans=scr_eng_obj[Keywords.transaction_obj].get!Document;

        check(trans.hasElement(Keywords.signatures), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto signatures=trans[Keywords.signatures].get!Document;
        immutable number_of_signatures = signatures.length;

        check(trans.hasElement(Keywords.transaction_scripting_obj), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto trans_scrip_obj =trans[Keywords.transaction_scripting_obj].get!Document;

        check(trans_scrip_obj.hasElement(Keywords.payers), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto payers=trans_scrip_obj[Keywords.payers].get!Document;
        immutable number_of_payers = payers.length;

        //Check number of bills, payers and signatures are the same and the bills match the payers.
        check(number_of_payers == number_of_signatures, ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        check(number_of_payers == number_of_bills, ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);

        void checkBillsMatchPayers() {
            foreach( i; 0..number_of_payers ) {
                auto bill=bills[i].get!Document[Keywords.bill].get!Document;
                auto payer=payers[i].get!Document;

                check(bill[Keywords.bill_number].get!(immutable(ubyte[])) == payer[Keywords.bill_number].get!(immutable(ubyte[])),
                ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
            }
        }

        checkBillsMatchPayers;
        //Verify each signatur
        auto sec_scr_eng_net = new SecureScriptingEngineNet(new NativeSecp256k1);
        sec_scr_eng_net.verifySignatures(trans_scrip_obj.data, payers, signatures);
        //Execute script.

        //To-Do: Only for debug mode:
        auto file_path = buildPath(options.scripting_engine.tmp_debug_dir, options.scripting_engine.tmp_debug_bills_filename);
        writeln("File path: ", expandTilde(file_path));
        write(file_path, bills.data);

    }

    writefln("Started scripting engine, with value: %s", run_scripting_engine);

    do {
        receive (
            &execute,
            &handleState
        );


    } while (run_scripting_engine );
}

module tagion.script.ScriptingEngine;

import std.concurrency;
import tagion.Base : Control, Pubkey;
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
        for( ushort i; i < payers.length ; i++) {
            auto payer=payers[i].get!Document;
            auto pub_key=payer["pub_key"].get!(immutable(ubyte)[]);

            auto signatur=signatures[i].get!Document["signatur"].get!(immutable(ubyte[]));

            auto message = this.calcHash(trans_scrip_obj_data);

            check(this.verify(message, signatur, cast(Pubkey)pub_key),
            ConsensusFailCode.SCRIPTING_ENGINE_SIGNATUR_FAULT);
        }
    }
}


void runScriptingEngine() {
    immutable temp_dir= expandTilde("~/tmp/");
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


    void execute (immutable(ubyte)[] scripting_engine_obj_data){
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

        check(scr_eng_obj.hasElement("bills"), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto bills= scr_eng_obj["bills"].get!Document;
        auto number_of_bills = bills.length;

        check(scr_eng_obj.hasElement("transaction_obj"), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto trans=scr_eng_obj["transaction_obj"].get!Document;

        check(trans.hasElement("signatures"), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto signatures=trans["signatures"].get!Document;
        auto number_of_signatures = signatures.length;

        check(trans.hasElement("transaction_scripting_obj"), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto trans_scrip_obj =trans["transaction_scripting_obj"].get!Document;

        check(trans_scrip_obj.hasElement("payers"), ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        auto payers=trans_scrip_obj["payers"].get!Document;
        auto number_of_payers = payers.length;

        //Check number of bills, payers and signatures are the same and the bills match the payers.
        check(number_of_payers == number_of_signatures, ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
        check(number_of_payers == number_of_bills, ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);

        void checkBillsMatchPayers() {
            for( ushort i; i < number_of_payers ; i++) {
                auto bill=bills[i].get!Document["bill"].get!Document;
                auto payer=payers[i].get!Document;

                check(bill["bill_number"].get!(immutable(ubyte[])) == payer["bill_number"].get!(immutable(ubyte[])),
                ConsensusFailCode.SCRIPTING_ENGINE_DATA_VALIDATION_FAULT);
            }
        }

        checkBillsMatchPayers;
        //Verify each signatur
        auto sec_scr_eng_net = new SecureScriptingEngineNet(new NativeSecp256k1);
        sec_scr_eng_net.verifySignatures(trans_scrip_obj.data, payers, signatures);

        //Execute script.


        auto file_path = temp_dir~"bills_doc.bson";
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
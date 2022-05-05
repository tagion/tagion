module tagion.tools.dartutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists;
import std.format;
import std.conv : to;
import std.array;
import std.algorithm;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.BlockFile;
import tagion.basic.Basic;

import tagion.communication.HiRPC;
import tagion.dart.DARTSynchronization;
import tagion.gossip.GossipNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;

import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.dart.Recorder;
import tagion.script.StandardRecords;

// import tagion.revision;
import tagion.tools.Basic;

mixin Main!_main;

int _main(string[] args) {
    immutable program = args[0];

    string dartfilename = "/tmp/default.drt";
    string inputfilename = "";
    string outputfilename = tempfile;
    ushort fromAngle = 0;
    ushort toAngle = 0;
    bool version_switch;

    bool useFakeNet = false;
    bool dump = false;

    bool dartread = false;
    string[] dartread_args;
    bool dartmodify = false;
    bool dartrim = false;
    bool dartrpc = false;
    bool generate = false;

    ubyte ringWidth = 4;
    int rings = 4;
    bool initialize = false;
    string passphrase = "verysecret";
    string nncupdatename, nncreadname;

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "dartfilename|drt", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
            "initialize", "Create a dart file", &initialize,
            "inputfile|i", "Sets the HiBON input file name", &inputfilename,
            "outputfile|o", "Sets the output file name", &outputfilename,
            "from", format("Sets from angle: default %s", (fromAngle == toAngle) ? "full" : fromAngle.to!string), &fromAngle,
            "to", format("Sets to angle: default %s", (fromAngle == toAngle) ? "full" : toAngle.to!string), &toAngle,
            "useFakeNet|fn", format("Enables fake hash test-mode: default %s", useFakeNet), &useFakeNet,
            "read|r", format("Excutes a DART read sequency: default %s", dartread), &dartread_args,
            "rim", format("Performs DART rim read: default %s", dartrim), &dartrim,
            "modify|m", format("Excutes a DART modify sequency: default %s", dartmodify), &dartmodify,
            "rpc", format("Excutes a HiPRC on the DART: default %s", dartrpc), &dartrpc,
            "generate", "Generate a fake test dart (recomended to use with --useFakeNet)", &generate,
            "dump", "Dumps all the arcvives with in the given angle", &dump,
            "width|w", "Sets the rings width and is used in combination with the generate", &ringWidth,
            "rings", "Sets the rings height and is used in  combination with the generate", &rings,
            "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
            "nncupdate", "Update existing NetworkNameCard with given name", &nncupdatename,
            "nncread", "Read NetworkNameCard with given name", &nncreadname,
    );

    dartread = !dartread_args.empty;
    bool nncupdate = !nncupdatename.empty;
    bool nncread = !nncreadname.empty;

    if (version_switch) {
        // writefln("version %s", REVNO);
        // writefln("Git handle %s", HASH);
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s <command> [<option>...]", program),
            "",
            "Where:",
            "<command>           one of [--read, --rim, --modify, --rpc]",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }

    SecureNet createNet() {
        SecureNet result;
        if (useFakeNet) {
            import tagion.dart.DARTFakeNet;

            result = new DARTFakeNet;
        }
        else {
            result = new StdSecureNet;
        }
        result.generateKeyPair(passphrase);
        return result;
    }

    const net = createNet;
    // else net = new StdSecureNet(crypt);
    const hirpc = HiRPC(net);
    // DART db;

    void writeResponse(Buffer data) {
        // if(dump) db.dump(true);
        writeln("OUTPUT: ", outputfilename);
        fwrite(outputfilename, data);
    }

    if (initialize) {
        if (dartfilename.length == 0) {
            dartfilename = tempfile ~ "tmp";
            writeln("DART filename: ", dartfilename);
        }
        enum BLOCK_SIZE = 0x80;
        BlockFile.create(dartfilename, DARTFile.stringof, BLOCK_SIZE);
    }

    auto db = new DART(net, dartfilename, fromAngle, toAngle);
    if (generate) {
        import tagion.dart.DARTFakeNet : SetInitialDataSet;

        auto fp = SetInitialDataSet(db, ringWidth, rings);
        writeln("GENERATED DART. EYE: ", fp.cutHex);
    }
    if (dump)
        db.dump(true);

    static const(HiRPCSender) readFromDB(Buffer[] fingerprints, HiRPC hirpc, DART db) {
        const sender = DART.dartRead(fingerprints, hirpc);
        auto receiver = hirpc.receive(sender.toDoc);
        return db(receiver, false);
    }

    static const(HiRPCSender) writeToDB(RecordFactory.Recorder recorder, HiRPC hirpc, DART db) {
        const sender = DART.dartModify(recorder, hirpc);
        auto receiver = hirpc.receive(sender);
        return db(receiver, false);
    }

    NetworkNameCard readNNC(string name, HiRPC hirpc, DART db) {
        NetworkNameCard nnc_find;
        nnc_find.name = name;

        auto result = readFromDB([net.hashOf(nnc_find.toDoc)], hirpc, db);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder(result.message["result"].get!Document);

        if (recorder[].empty) {
            return NetworkNameCard();
        }
        else {
            return NetworkNameCard(recorder[].front.filed); 
        }
    }

    NetworkNameRecord readNRC(Buffer nrc_hash, HiRPC hirpc, DART db) {
        auto result = readFromDB([nrc_hash], hirpc, db);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder(result.message["result"].get!Document);

        if (recorder[].empty) {
            return NetworkNameRecord();
        }
        else {
            return NetworkNameRecord(recorder[].front.filed);
        }
    }

    const onehot = dartrpc + dartread + dartrim + dartmodify + nncupdate + nncread;

    if (onehot > 1) {
        stderr.writeln("Only one of the dartrpc, dartread, dartrim, dartmodify, nncupdate and nncread switched alowed");
        return 1;
    }
    if (!inputfilename.exists) {
        stderr.writefln("No input file '%s'", inputfilename);
    }

    if (dartrpc) {
        if (!inputfilename.exists) {
            writeln("No input file");
        }
        else {
            Buffer inputBuffer = cast(immutable(ubyte)[]) fread(inputfilename);
            auto doc = Document(inputBuffer);
            auto received = hirpc.receive(doc);
            auto result = db(received);
            auto tosendResult = result.response.result[Keywords.result].get!Document;
            writeResponse(tosendResult.serialize);
        }
    }
    else if (dartread) {
        if (!inputfilename.exists) {
            writeln("No input file");
        }
        else {
            auto fingerprints = dartread_args.map!(hash => decode(hash)).array;

            const sender = DART.dartRead(fingerprints, hirpc);
            auto receiver = hirpc.receive(sender.toDoc);
            auto result = db(receiver, false);
            auto tosend = hirpc.toHiBON(result);
            auto tosendResult = tosend.method.params;
            if (dump)
                db.dump(true);
            writeResponse(tosendResult.serialize);
            writeln("Result: %s", result.message.toJSON.toPrettyString);

            // auto inputBuffer = cast(immutable(ubyte)[])fread(inputfilename);
            // auto params=new HiBON;
            // auto params_fingerprints=new HiBON;
            // auto input_doc = Document(inputBuffer);
            // if(input_doc.isInorder){
            //     auto fps = (input_doc[DARTFile.Params.branches].get!Document)[DARTFile.Params.fingerprints].get!Document;
            //     auto i = 0;
            //     foreach(fp; fps[]){
            //         params_fingerprints[i] = fp.get!Buffer;
            //         i++;
            //     }
            // }else{
            // writeln(3);
            //     foreach(i, b; (cast(string)inputBuffer).split("\n")) {
            //         auto fp = decode(b);
            //         if ( b.length !is 0 ) {
            //             params_fingerprints[i]=fp;
            //         }
            //     }
            // }
            // params[DARTFile.Params.fingerprints]=params_fingerprints;
            // auto sended = hirpc.dartRead(params).toHiBON(net).serialize;
            // auto doc = Document(sended);
            // auto received = hirpc.receive(doc);
            // auto result = db(received);
            // auto tosend = hirpc.toHiBON(result);
            // auto tosendResult = (tosend[Keywords.message].get!Document)[Keywords.result].get!Document;
            // writeResponse(tosendResult.serialize);
        }
    }
    else if (dartrim) {
        // Buffer root_rims;
        // auto params=new HiBON;
        // if(!inputfilename.exists) {
        //     writefln("Input file: %s not exists", inputfilename);
        //     root_rims = [];
        // }else{
        //     auto inputBuffer = cast(immutable(char)[])fread(inputfilename);
        //     if(inputBuffer.length){
        //         root_rims = decode(inputBuffer);
        //         writeln(root_rims);
        //     }else{
        //         root_rims = [];
        //     }
        // }
        // params[DARTFile.Params.rims]=root_rims;
        // auto sended = hirpc.dartRim(params).toHiBON(net).serialize;
        // auto doc = Document(sended);
        // auto received = hirpc.receive(doc);
        // auto result = db(received);
        // auto tosend = hirpc.toHiBON(result);
        // auto tosendResult = (tosend[Keywords.message].get!Document)[Keywords.result].get!Document;
        // writeResponse(tosendResult.serialize);
    }
    else if (dartmodify) {
        auto inputBuffer = cast(immutable(ubyte)[]) fread(inputfilename);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder(Document(inputBuffer));
        auto sended = DART.dartModify(recorder, hirpc);
        auto received = hirpc.receive(sended);
        auto result = db(received, false);
        auto tosend = hirpc.toHiBON(result);
        auto tosendResult = tosend.method.params;
        if (dump)
            db.dump(true);
        writeResponse(tosendResult.serialize);
    }
    else if (nncread) {
        auto nnc = readNNC(nncreadname, hirpc, db);
        if (nnc == NetworkNameCard.init) {
            writefln("No NetworkNameCard with name '%s' in DART", nncreadname);
        }
        else {
            writefln("NetworkNameCard: %s", nnc.toDoc.toJSON.toPrettyString);

            auto nrc = readNRC(nnc.record, hirpc, db);
            if (nrc == NetworkNameRecord.init) {
                writefln("No NetworkNameRecord with hash '%s' in DART", nnc.record.cutHex);
            }
            else {
                writefln("NetworkNameRecord: %s", nrc.toDoc.toJSON.toPrettyString);
            }
        }
    }
    else if (nncupdate) {
        auto nnc = readNNC(nncupdatename, hirpc, db);
        if (nnc == NetworkNameCard.init) {
            writefln("No NetworkNameCard with name '%s' in DART", nncupdatename);
        }
        else {
            auto nrc = readNRC(nnc.record, hirpc, db);
            if (nrc == NetworkNameRecord.init) {
                writefln("No associated NetworkNameRecord (hash='%s') with NetworkNameCard '%s' in DART", nnc.record.cutHex, nnc.name);
            }
            else {
                // Remove old NNC
                auto factory = RecordFactory(net);
                auto recorder = factory.recorder;
                
                recorder.remove(nnc);
                writeToDB(recorder, hirpc, db);

                // Create and add new NNC and NRC
                NetworkNameCard nnc_new;
                nnc_new.name = nnc.name;
                nnc_new.lang = nnc.lang;
                // nnc_new.time = current_time?

                NetworkNameRecord nrc_new;
                nrc_new.name = net.hashOf(nnc_new.toDoc);
                nrc_new.previous = nnc.record;
                nrc_new.index = nrc.index + 1;

                nnc_new.record = net.hashOf(nrc_new.toDoc);
        
                auto recorder_new = factory.recorder;
                recorder_new.add(nnc_new);
                recorder_new.add(nrc_new);

                writeToDB(recorder_new, hirpc, db);

                writefln("Updated NetworkNameCard with name '%s'", nnc.name);

                if (dump)
                    db.dump(true);
            }

        }
    }
    return 0;
}

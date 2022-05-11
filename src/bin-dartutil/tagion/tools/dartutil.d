module tagion.tools.dartutil;

import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.conv : to;
import std.array;
import std.algorithm;
import std.typecons;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.BlockFile;
import tagion.basic.Types : Buffer;
import tagion.basic.Basic : tempfile;

import tagion.communication.HiRPC;
import tagion.dart.DARTSynchronization;
import tagion.gossip.GossipNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : fread, fwrite;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;

import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.dart.Recorder;
import tagion.script.StandardRecords;

// import tagion.revision;
import tagion.tools.Basic;

alias UpdateRecorders=Tuple!(RecordFactory.Recorder, "remove", RecordFactory.Recorder, "add");

pragma(msg, "fixme(ib): move to new library when it will be merged from cbr");
UpdateRecorders updateNetworkNameCard(const HashNet net, NetworkNameCard nnc, NetworkNameRecord nrc, HashRecord hr) {
    auto factory = RecordFactory(net);
    UpdateRecorders update_recorders = [factory.recorder, factory.recorder]; 

    // Remove old NNC and signature
    update_recorders.remove.remove(nnc);
    update_recorders.remove.remove(hr);

    // Create new NNC, NRC and signature
    NetworkNameCard nnc_new;
    nnc_new.name = nnc.name;
    nnc_new.lang = nnc.lang;
    // nnc_new.time = current_time?

    NetworkNameRecord nrc_new;
    nrc_new.name = net.hashOf(nnc_new.toDoc);
    nrc_new.previous = net.hashOf(nrc.toDoc);
    nrc_new.index = nrc.index + 1;

    nnc_new.record = net.hashOf(nrc_new.toDoc);

    auto hr_new = HashRecord(net, nnc_new);

    update_recorders.add.add(nnc_new);
    update_recorders.add.add(nrc_new);
    update_recorders.add.add(hr_new);

    return update_recorders;
}

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
    bool eye;

    ubyte ringWidth = 4;
    int rings = 4;
    bool initialize = false;
    string passphrase = "verysecret";
    string nncupdatename, nncreadname;

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
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
            "eye", "Prints the bullseye", &eye,
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

    // void writeResponse(Buffer data) {
    //     // if(dump) db.dump(true);
    //     writeln("OUTPUT: ", outputfilename);
    //     fwrite(outputfilename, data);
    // }

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
    if (dump) {
        db.dump(true);
    }
    else if (eye) {
        writefln("EYE: %s", db.fingerprint.hex);
    }

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

    Nullable!T readRecord(T)(Buffer hash, HiRPC hirpc, DART db) if (isHiBONRecord!T) {
        auto result = readFromDB([hash], hirpc, db);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder(result.message["result"].get!Document);

        if (recorder[].empty) {
            return Nullable!T.init;
        }
        else {
            return Nullable!T(T(recorder[].front.filed));
        }
    }

    Nullable!NetworkNameCard readNNC(string name, HiRPC hirpc, DART db) {
        NetworkNameCard nnc_find;
        nnc_find.name = name;

        return readRecord!NetworkNameCard(net.hashOf(nnc_find.toDoc), hirpc, db);
    }

    bool verifyNNCSignature(NetworkNameCard nnc, HiRPC hirpc, DART db) {
        auto check_hr = HashRecord(net, nnc);
        auto found_hr = readRecord!HashRecord(net.hashOf(check_hr.toDoc), hirpc, db);
        return !found_hr.isNull;
    }

    const onehot = dartrpc + dartread + dartrim + dartmodify + nncupdate + nncread;

    if (onehot > 1) {
        stderr.writeln("Only one of the dartrpc, dartread, dartrim, dartmodify, nncupdate and nncread switched alowed");
        return 1;
    }
    // if (!inputfilename.exists) {
    //     stderr.writefln("No input file '%s'", inputfilename);
    // }

    if (dartrpc) {
        if (!inputfilename.exists) {
            writeln("No input file");
        }
        else {
            const doc = inputfilename.fread;
            auto received = hirpc.receive(doc);
            auto result = db(received);
            const tosendResult = result.response.result[Keywords.result].get!Document;
            outputfilename.fwrite(tosendResult);
        }
    }
    else if (dartread) {
        // if (!inputfilename.exists) {
        //     writeln("No input file");
        // }
        // else {
            auto fingerprints = dartread_args.map!(hash => decode(hash)).array;

            const sender = DART.dartRead(fingerprints, hirpc);
            auto receiver = hirpc.receive(sender.toDoc);
            auto result = db(receiver, false);
            auto tosend = hirpc.toHiBON(result);
            const tosendResult = tosend.method.params;
            if (dump)
                db.dump(true);
            outputfilename.fwrite(tosendResult);
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
        // }
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
//        auto inputBuffer = cast(immutable(ubyte)[]) fread(inputfilename);

        const doc = inputfilename.fread;
        auto factory = RecordFactory(net);
//        const recorder = inputfilename.fread!(RecordFactory.Recorder)(factory.net);
        auto recorder = factory.recorder(doc);
        auto sended = DART.dartModify(recorder, hirpc);
        auto received = hirpc.receive(sended);
        auto result = db(received, false);
        auto tosend = hirpc.toHiBON(result);
        auto tosendResult = tosend.method.params;
        if (dump)
            db.dump(true);
        outputfilename.fwrite(tosendResult);
    }
    else if (nncread) {
        auto nnc_read = readNNC(nncreadname, hirpc, db);
        if (nnc_read.isNull) {
            writefln("No NetworkNameCard with name '%s' in DART", nncreadname);
        }
        else {
            auto nnc = nnc_read.get;
            writefln("NetworkNameCard: %s", nnc.toDoc.toJSON.toPrettyString);

            writeln;
            if (verifyNNCSignature(nnc, hirpc, db))
                writefln("Signature for NetworkNameCard '%s' is verified", nnc.name);
            else {
                writefln("WARNING: Signature for NetworkNameCard '%s' is not verified!", nnc.name);
            }
            writeln;

            auto nrc_read = readRecord!NetworkNameRecord(nnc.record, hirpc, db);
            if (nrc_read.isNull) {
                writefln("No associated NetworkNameRecord (hash='%s') with NetworkNameCard '%s' in DART", nnc.record.cutHex, nnc.name);
            }
            else {
                writefln("NetworkNameRecord: %s", nrc_read.get.toDoc.toJSON.toPrettyString);
            }
        }
    }
    else if (nncupdate) {
        auto nnc_read = readNNC(nncupdatename, hirpc, db);
        if (nnc_read.isNull) {
            writefln("No NetworkNameCard with name '%s' in DART", nncupdatename);
        }
        else {
            auto nnc = nnc_read.get;
            auto nrc_read = readRecord!NetworkNameRecord(nnc.record, hirpc, db);
            if (nrc_read.isNull) {
                writefln("No associated NetworkNameRecord (hash='%s') with NetworkNameCard '%s' in DART", nnc.record.cutHex, nnc.name);
            }
            else {
                auto nrc = nrc_read.get;

                auto check_hr = HashRecord(net, nnc);
                auto found_hr = readRecord!HashRecord(net.hashOf(check_hr.toDoc), hirpc, db);
                if (found_hr.isNull) {
                    writefln("WARNING: Signature for NetworkNameCard '%s' is not verified! Unable to update record\nAbort", nnc.name);
                }
                else {
                    auto update_recorders = updateNetworkNameCard(net, nnc, nrc, found_hr.get);
                    
                    writeToDB(update_recorders.remove, hirpc, db);
                    writeToDB(update_recorders.add, hirpc, db);

                    writefln("Updated NetworkNameCard with name '%s'", nnc.name);

                    if (dump)
                        db.dump(true);
                }
            }

        }
    }
    return 0;
}

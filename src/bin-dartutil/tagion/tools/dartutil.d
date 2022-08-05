module tagion.tools.dartutil;

import std.getopt;
import std.stdio;
import std.file : exists;
import std.path : setExtension;
import std.format;
import std.conv : to;
import std.array;
import std.algorithm;
import std.typecons;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.Basic : tempfile;
import tagion.basic.TagionExceptions : TagionException;

import tagion.communication.HiRPC;
import tagion.dart.DARTSynchronization;
import tagion.gossip.GossipNet;
import tagion.gossip.AddressBook;
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
import tagion.script.NameCardScripts : readStandardRecord;

import tagion.tools.Basic;
pragma(msg, "fixme(ib): move to new library when it will be merged from cbr");
void updateAddNetworkNameCard(const HashNet net, NetworkNameCard nnc, NetworkNameRecord nrc, RecordFactory
        .Recorder recorder)
{
    recorder.remove(HashLock(net, nnc));

    // Create new NNC, NRC and signature
    NetworkNameCard nnc_new;
    nnc_new.name = nnc.name;
    nnc_new.lang = nnc.lang;
    // nnc_new.time = current_time?

    NetworkNameRecord nrc_new;
    nrc_new.name = net.hashOf(nnc_new.toDoc);
    nrc_new.previous = net.hashOf(nrc.toDoc);
    nrc_new.index = nrc.index + 1;
    nrc_new.node = nrc.node; // update NodeAddress?

    nnc_new.record = net.hashOf(nrc_new.toDoc);

    auto hr_new = HashLock(net, nnc_new);

    recorder.add(nnc_new);
    recorder.add(nrc_new);
    recorder.add(hr_new);
}

void updateRemoveHashKeyRecord(const HashNet net, const RecordFactory.Recorder src, RecordFactory
        .Recorder dest)
in
{
    assert(dest !is null);
}
do
{
    auto hash_filter = src[].filter!(a => a.isAdd && a.filed.hasHashKey);
    dest.insert(hash_filter, Archive.Type.REMOVE);

    // WRONG: removing NEW lock instead of OLD
    // auto hash_locks = hash_filter.map!(a => HashLock(net, a.filed));
    // dest.insert(hash_locks, Archive.Type.REMOVE);
}

pragma(msg, "fixme(ib): move to new library when it will be merged from cbr");
void updateAddEpochBlock(const HashNet net, EpochBlock epoch_block, RecordFactory.Recorder recorder)
{
    EpochBlock epoch_block_new;
    epoch_block_new.epoch = epoch_block.epoch + 1;
    epoch_block_new.previous = net.hashOf(epoch_block);

    auto le_block_new = LastEpochRecord(net, epoch_block_new);

    recorder.add(epoch_block_new);
    recorder.add(le_block_new);
}

mixin Main!_main;

enum ExitCode : int {
    none, /// No errors
        create_file, /// Error while creating the DART file
}
int _main(string[] args)
{
    immutable program = args[0];

    string dartfilename = "/tmp/default".setExtension(FileExtension.dart);
    string inputfilename = "";
    string outputfilename = tempfile;
    ushort fromAngle = 0;
    ushort toAngle = 0;
    bool version_switch;
    auto logo = import("logo.txt");

    bool useFakeNet = false;
    bool dump = false;

    bool dartread = false;
    string[] dartread_args;
    bool dartmodify = false;
    bool dartrim = false;
    bool dartrpc = false;
    bool generate = false;
    bool eye;
    bool verbose;

    ubyte ringWidth = 4;
    int rings = 4;
    bool initialize = false;
    string passphrase = "verysecret";
    string nncupdatename, nncreadname;
    uint testaddblocks;
    int testdumpblocks = -1;

    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
        "initialize", "Create a dart file", &initialize,
        "inputfile|i", "Sets the HiBON input file name", &inputfilename,
        "outputfile|o", "Sets the output file name", &outputfilename,
        "from", format("Sets from angle: default %s", (fromAngle == toAngle) ? "full"
            : fromAngle.to!string), &fromAngle,
        "to", format("Sets to angle: default %s", (fromAngle == toAngle) ? "full"
            : toAngle.to!string), &toAngle,
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
        "verbose|v", "Print output to console", &verbose,
        "testaddblocks", "DEBUG MODE: Add N epoch blocks in chain", &testaddblocks,
        "testdumpblocks", "DEBUG MODE: Dump last N epoch blocks in chain. Set 0 to dump all blocks in chain", &testdumpblocks,
    );

    dartread = !dartread_args.empty;
    bool nncupdate = !nncupdatename.empty;
    bool nncread = !nncreadname.empty;
    bool testdumpblocks_enabled = testdumpblocks > -1;

    if (version_switch)
    {
        // writefln("version %s", REVNO);
        // writefln("Git handle %s", HASH);
        return 0;
    }

    if (main_args.helpWanted)
    {
        writeln(logo);
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

    SecureNet createNet()
    {
        SecureNet result;
        if (useFakeNet)
        {
            import tagion.dart.DARTFakeNet;

            result = new DARTFakeNet;
        }
        else
        {
            result = new StdSecureNet;
        }
        result.generateKeyPair(passphrase);
        return result;
    }

    const net = createNet;
    const hirpc = HiRPC(net);

    writeln("!!! Here");
    if (initialize)
    {
        if (dartfilename.length == 0)
        {
            dartfilename = tempfile ~ "tmp";
            writeln("DART filename: ", dartfilename);
        }
        try {
            writeln("Before");
            DART.create(dartfilename);
            writeln("After");
        }
        catch (Exception e) {
            stderr.writefln("Unable to create DART file %s", dartfilename);
            stderr.writeln(e.msg);
            return ExitCode.create_file;
        }
    }

    try {

    auto db = new DART(net, dartfilename, fromAngle, toAngle);
    if (generate)
    {
        import tagion.dart.DARTFakeNet : SetInitialDataSet;

        auto fp = SetInitialDataSet(db, ringWidth, rings);
        writeln("GENERATED DART. EYE: ", fp.cutHex);
    }
    if (dump)
    {
        db.dump(true);
    }
    else if (eye)
    {
        writefln("EYE: %s", db.fingerprint.hex);
    }

    static const(HiRPCSender) readFromDB(Buffer[] fingerprints, HiRPC hirpc, DART db)
    {
        const sender = DART.dartRead(fingerprints, hirpc);
        auto receiver = hirpc.receive(sender.toDoc);
        return db(receiver, false);
    }

    static const(HiRPCSender) writeToDB(RecordFactory.Recorder recorder, HiRPC hirpc, DART db)
    {
        const sender = DART.dartModify(recorder, hirpc);
        auto receiver = hirpc.receive(sender);
        return db(receiver, false);
    }

    Nullable!T readRecord(T)(Buffer hash, HiRPC hirpc, DART db) if (isHiBONRecord!T)
    {
        auto result = readFromDB([hash], hirpc, db);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder(result.message["result"].get!Document);

        if (recorder[].empty)
        {
            return Nullable!T.init;
        }
        else
        {
            return Nullable!T(T(recorder[].front.filed));
        }
    }

    Nullable!EpochBlock readLastEpochBlock(HiRPC hirpc, DART db)
    {
        auto epoch_top_read = readRecord!LastEpochRecord(LastEpochRecord.dartHash(net), hirpc, db);
        if (epoch_top_read.isNull)
        {
            return Nullable!EpochBlock.init;
        }

        return readRecord!EpochBlock(epoch_top_read.get.top, hirpc, db);
    }

    void toConsole(T)(T doc, bool indent_line = false, string alternative_text = "")
            if (isHiBONRecord!T || is(T == Document))
    {
        if (verbose)
        {
            if (indent_line)
                writeln;
            writefln("%s: %s", T.stringof, doc.toPretty);
        }
        else if (!alternative_text.empty)
        {
            writeln(alternative_text);
        }
    }

    const onehot = dartrpc + dartread + dartrim + dartmodify + nncupdate + nncread + (
        testaddblocks > 0) + testdumpblocks_enabled;

    if (onehot > 1)
    {
        stderr.writeln(
            "Only one of the dartrpc, dartread, dartrim, dartmodify, nncupdate and nncread switched alowed");
        return 1;
    }
    // if (!inputfilename.exists) {
    //     stderr.writefln("No input file '%s'", inputfilename);
    // }

    if (dartrpc)
    {
        if (!inputfilename.exists)
        {
            writeln("No input file");
        }
        else
        {
            const doc = inputfilename.fread;
            auto received = hirpc.receive(doc);
            auto result = db(received);
            const tosendResult = result.response.result[Keywords.result].get!Document;
            outputfilename.fwrite(tosendResult);
        }
    }
    else if (dartread)
    {
        auto fingerprints = dartread_args.map!(hash => decode(hash)).array;

        const sender = DART.dartRead(fingerprints, hirpc);
        auto receiver = hirpc.receive(sender.toDoc);
        auto result = db(receiver, false);
        auto tosend = hirpc.toHiBON(result);
        const tosendResult = tosend.method.params;

        outputfilename.fwrite(tosendResult);

        toConsole!Document(result.message);
    }
    else if (dartrim)
    {
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
    else if (dartmodify)
    {
        const doc = inputfilename.fread;
        auto factory = RecordFactory(net);
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
    else if (nncread)
    {
        auto nnc_out = readStandardRecord!NetworkNameCard(net, hirpc, db, NetworkNameCard.dartHash(net, nncreadname));

        if (nnc_out.isNull)
        {
            writeln;
            writefln("No %s with name '%s' in DART", typeof(nnc_out.get).stringof, nncreadname);
        }
        else
        {
            auto nnc = nnc_out.get;
            toConsole(nnc, true, format("\nFound %s '%s'", typeof(nnc).stringof, nncreadname));

            auto signature_out = readStandardRecord!HashLock(net, hirpc, db, net.hashOf(HashLock(net, nnc)));
            writeln;
            if (signature_out.isNull)
                writefln("WARNING: Signature for %s '%s' is not verified!", typeof(nnc).stringof, nnc
                        .name);
            else
                writefln("Signature for %s '%s' is verified", typeof(nnc).stringof, nnc.name);

            auto nrc_out = readStandardRecord!NetworkNameRecord(net, hirpc, db, nnc.record);
            if (nrc_out.isNull)
            {
                writeln;
                writefln("No associated %s (hash='%s') with %s '%s' in DART", typeof(nrc_out.get)
                        .stringof, typeof(nnc).stringof, nnc.record.cutHex, nnc.name);
            }
            else
            {
                toConsole(nrc_out.get, true, format("\nFound %s for %s '%s'", typeof(nrc_out.get).stringof, typeof(
                        nnc).stringof, nncreadname));

                auto node_addr_out = readStandardRecord!NodeAddress(net, hirpc, db, nrc_out
                        .get.node);
                if (node_addr_out.isNull)
                {
                    writeln;
                    writefln("No associated %s (hash='%s') with %s '%s' in DART", typeof(node_addr_out.get)
                            .stringof, typeof(nnc).stringof, nrc_out.get.node.cutHex, nnc.name);
                }
                else
                    toConsole(node_addr_out.get, true, format("\nFound %s for %s '%s'", typeof(
                            node_addr_out.get).stringof, typeof(nnc).stringof, nncreadname));
            }
        }
    }
    else if (nncupdate)
    {
        auto nnc_out = readStandardRecord!NetworkNameCard(net, hirpc, db, NetworkNameCard.dartHash(net, nncupdatename));
        if (nnc_out.isNull)
        {
            writeln;
            writefln("No %s with name '%s' in DART", typeof(nnc_out.get).stringof, nncupdatename);
        }
        else
        {
            auto nnc = nnc_out.get;
            auto nrc_out = readStandardRecord!NetworkNameRecord(net, hirpc, db, nnc.record);
            if (nrc_out.isNull)
            {
                writefln("No associated %s (hash='%s') with %s '%s' in DART", typeof(nrc_out.get)
                        .stringof, typeof(nnc).stringof, nnc.record.cutHex, nnc.name);
            }
            else
            {
                auto nrc = nrc_out.get;

                auto signature = readStandardRecord!HashLock(net, hirpc, db, net.hashOf(HashLock(net, nnc)));
                if (signature.isNull)
                {
                    writefln("WARNING: Signature for %s '%s' is not verified! Unable to update record\nAbort", typeof(
                            nnc).stringof, nnc.name);
                }
                else
                {
                    auto factory = RecordFactory(net);
                    auto recorder_add = factory.recorder;
                    updateAddNetworkNameCard(net, nnc, nrc, recorder_add);
                    auto recorder_remove = factory.recorder;
                    updateRemoveHashKeyRecord(net, recorder_add, recorder_remove);

                    db.modify(recorder_remove);
                    db.modify(recorder_add);

                    writeln;
                    writefln("Updated %s with name '%s'", typeof(nnc).stringof, nnc.name);

                    if (verbose)
                    {
                        writeln;
                        writefln("Recorder add %s", recorder_add.toPretty);
                        writeln;
                        writefln("Recorder remove %s", recorder_remove.toPretty);
                    }

                    if (dump)
                    {
                        writeln;
                        db.dump(true);
                    }
                }
            }
        }
    }
    else if (testaddblocks > 0)
    {
        foreach (i; 0 .. testaddblocks)
        {
            writef("Adding block %d... ", i + 1);

            auto last_epoch_block_read = readLastEpochBlock(hirpc, db);
            if (last_epoch_block_read.isNull)
            {
                writefln("DART is corrupted! Top epoch block in chain was not found. Abort");
                return 1;
            }

            auto factory = RecordFactory(net);
            auto recorder_add = factory.recorder;
            updateAddEpochBlock(net, last_epoch_block_read.get, recorder_add);
            auto recorder_remove = factory.recorder;
            updateRemoveHashKeyRecord(net, recorder_add, recorder_remove);

            db.modify(recorder_remove);
            db.modify(recorder_add);

            writeln("Done!");

            if (verbose)
            {
                writeln;
                writefln("Recorder add %s", recorder_add.toPretty);
                writeln;
                writefln("Recorder remove %s", recorder_remove.toPretty);
            }
        }
    }
    else if (testdumpblocks_enabled)
    {
        import tagion.dart.DARTFile : hash_null;

        auto last_epoch_block_read = readLastEpochBlock(hirpc, db);
        if (last_epoch_block_read.isNull)
        {
            writefln("DART is corrupted! Top epoch block in chain was not found. Abort");
            return 1;
        }

        toConsole(last_epoch_block_read.get, true, "Last block is read successfully.");
        auto previous_hash = last_epoch_block_read.get.previous;

        int i = 1;
        const has_count_limit = testdumpblocks > 0; // testdumpblocks = 0 means no limit in blocks count
        while (!has_count_limit || i < testdumpblocks)
        {
            if (previous_hash == hash_null)
            {
                writefln("Reached first block in chain. Stop");
                break;
            }

            auto current_block_read = readRecord!EpochBlock(previous_hash, hirpc, db);
            if (current_block_read.isNull)
            {
                writefln("DART is corrupted! Epoch block in chain was not found. Abort");
                return 1;
            }

            toConsole(current_block_read.get, true, format("N-%d epoch block is read successfully.", i));
            previous_hash = current_block_read.get.previous;

            i += 1;
        }
    }
    }
    catch (TagionException e) {
        stderr.writeln(e);
        return 1;
    }
    catch (Exception e) {
        stderr.writeln(e);
        return 2;
    }
    return ExitCode.none;
}

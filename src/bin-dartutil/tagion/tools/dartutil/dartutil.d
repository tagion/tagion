module tagion.tools.dartutil.dartutil;

import std.algorithm;
import std.array;
import std.conv : to;
import std.file : exists, mkdirRecurse, rmdirRecurse, tempDir;
import std.format;
import std.getopt;
import std.path : baseName, buildPath, dirName, setExtension, stripExtension;
import std.stdio;
import std.typecons;
import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.dart.DART : DART;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTFile;
import tools = tagion.tools.toolsexception;
import CRUD = tagion.dart.DARTcrud; // : dartRead, dartModify;

import tagion.basic.basic : tempfile;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.BlockFile : BlockFile;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.gossip.AddressBook;
import tagion.gossip.GossipNet;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.tools.dartutil.synchronize;

//import tagion.utils.Miscellaneous;
import std.exception;
import std.uni : toLower;
import tagion.Keywords;
import tagion.dart.DARTFakeNet;
import tagion.dart.DARTRim;
import tagion.dart.Recorder;
import tagion.hibon.HiBONtoText : decode, encodeBase64;
import tagion.script.NameCardScripts : readStandardRecord;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.dart.BlockFile : Index;

/**
 * @brief tool for working with local DART database
 */

mixin Main!_main;

int _main(string[] args) {
    immutable program = args[0];

    string dartfilename;
    string inputfilename;
    string destination_dartfilename;
    string outputfilename;
    string journal_path = buildPath(tempDir, "dart_journals");
    bool version_switch;
    const logo = import("logo.txt");

    bool print;

    bool standard_output;
    string[] dartread_args;
    string angle_range;
    string exec;
    uint depth;
    bool strip;
    bool dartmodify;
    string dartrim;
    bool dartrpc;
    bool sync;
    bool eye;
    bool fake;
    bool force;
    bool dump;
    bool dump_branches;
    bool initialize;
    string passphrase = "verysecret";

    GetoptResult main_args;
    SectorRange sectors;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, //   "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
                "verbose|v", "Prints verbose information to console", &__verbose_switch,
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
                "I|initialize", "Create a dart file", &initialize,
                "o|outputfile", "Sets the output file name", &outputfilename,
                "r|read", "Excutes a DART read sequency", &dartread_args,
                "rim", "Performs DART rim read", &dartrim,
                "m|modify", "Excutes a DART modify sequency", &dartmodify,
                "rpc", "Excutes a HiPRC on the DART", &dartrpc,
                "strip", "Strips the dart-recoder dumps archives", &strip,
                "f|force", "Force erase and create journal and destination DART", &force,
                "print", "prints all the archives with in the given angle", &print,
                "dump", "Dumps all the archives with in the given angle", &dump,
                "dump-branches", "Dumps all the archives and branches with in the given angle", &dump_branches,
                "eye", "Prints the bullseye", &eye,
                "sync", "Synchronize src.drt to dest.drt", &sync,
                "e|exec", "Execute string to be used for remote access", &exec,
                "P|passphrase", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
                "R|range", "Sets angle range from:to (Default is full range)", &angle_range,
                "depth", "Set limit on dart rim depth", &depth,
                "fake", format(
                    "Use fakenet instead of real hashes : default :%s", fake), &fake,
        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        standard_output = (outputfilename.empty);
        if (standard_output) {
            vout = stderr;
        }
        if (main_args.helpWanted) {
            writeln(logo);
            defaultGetoptPrinter(
                    [
                    // format("%s version %s", program, REVNO),
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] file.drt <files>", program),
                    "",
                    "Example synchronizing src.drt on to dst.drt",
                    format("%s --sync src.drt dst.drt", program),
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }

        if (!exec.empty) {
            writeln("%s", exec);
            writefln(exec, "hirpc.hibon", "response.hibon");
        }
        if (!angle_range.empty) {
            import std.bitmanip;

            ushort _from, _to;
            const fields =
                angle_range.formattedRead("%x:%x", _from, _to)
                    .ifThrown(0);
            tools.check(fields == 2,
                    format("Angle range shoud be ex. --range A0F0:B0F8 not %s", angle_range));
            verbose("Angle from %04x to %04x", _from, _to);
            sectors = SectorRange(_from, _to);
        }
        foreach (file; args[1 .. $]) {
            if (file.hasExtension(FileExtension.hibon)) {
                tools.check(inputfilename is null,
                        format("Input file '%s' has already been declared", inputfilename));
                inputfilename = file;
                continue;
            }
            if (file.hasExtension(FileExtension.dart)) {
                if (dartfilename is null) {
                    dartfilename = file;
                    continue;
                }
                tools.check(destination_dartfilename is null,
                        format("Source '%s' and destination '%s' DART file has already been define",
                        dartfilename, destination_dartfilename));
                destination_dartfilename = file;
            }
        }
        SecureNet net;

        tools.check(!dartfilename.empty, "Missing dart file");

        if (dartfilename.exists) {
            auto blockfile = BlockFile(dartfilename, Yes.read_only);
            scope (exit) {
                blockfile.close;
            }
            fake = blockfile.headerBlock.checkId(DARTFakeNet.hashname);
        }
        if (fake) {
            net = new DARTFakeNet(passphrase);
        }
        else {
            net = new StdSecureNet;
            net.generateKeyPair(passphrase);
        }

        const hirpc = HiRPC(net);

        if (initialize) {
            DART.create(dartfilename, net);
            return 0;
        }

        Exception dart_exception;
        auto db = new DART(net, dartfilename, dart_exception, Yes.read_only);
        if (dart_exception !is null) {
            stderr.writefln("Fail to open DART: %s. Abort.", dartfilename);
            error(dart_exception);
            return 1;
        }

        if (sync) {
            if (!destination_dartfilename.exists) {

                DART.create(destination_dartfilename, net);
                writefln("DART %s created", destination_dartfilename);
            }
            auto dest_db = new DART(net, destination_dartfilename, dart_exception);
            writefln("Open destination %s", destination_dartfilename);
            if (dart_exception !is null) {
                writefln("Fail to open destination DART: %s. Abort.", destination_dartfilename);
                error(dart_exception);
                return 1;
            }
            immutable _journal_path = buildPath(journal_path,
                    destination_dartfilename.baseName.stripExtension);

            verbose("journal path %s", journal_path);
            if (journal_path.exists) {
                journal_path.rmdirRecurse;
            }
            journal_path.mkdirRecurse;
            writefln("Synchronize journals %s", _journal_path);
            synchronize(dest_db, db, _journal_path);
            return 0;
        }

        if (print) {
            db.dump(sectors, Yes.full, depth);
        }
        else if (eye) {
            writefln("EYE: %(%02x%)", db.fingerprint);
        }
        else if (dump || dump_branches) {
            File fout;
            fout = stdout;
            bool dartTraverse(const(Document) doc, const Index index, const uint rim, Buffer rim_path) {
                if (dump && DARTFile.Branches.isRecord(doc)) {
                    return false;
                }
                fout.rawWrite(doc.serialize);
                return false;
            }

            db.traverse(&dartTraverse, sectors, depth);
            return 0;
        }

        const dartread = dartread_args.length > 0;
        const onehot = dartrpc + dartread + !dartrim.empty + dartmodify;

        tools.check(onehot <= 1,
                "Only one of the dartrpc, dartread, dartrim, dartmodify switched alowed");

        if (dartrpc) {
            tools.check(!inputfilename.empty, "Missing input file for DART-rpc");
            const doc = inputfilename.fread;
            auto received = hirpc.receive(doc);
            auto result = db(received);
            const tosendResult = result.response.result[Keywords.result].get!Document;
            outputfilename.fwrite(tosendResult);
            return 0;
        }
        if (dartread) {
            File fout;
            fout = stdout;
            DARTIndex[] dart_indices;
            foreach (read_arg; dartread_args) {
                import tagion.tools.dartutil.dartindex : dartIndexDecode;

                auto dart_index = net.dartIndexDecode(read_arg);
                verbose("%s\n%s\n%(%02x%)", read_arg, dart_index.encodeBase64, dart_index);
                dart_indices ~= dart_index;
            }

            const sender = CRUD.dartRead(dart_indices, hirpc);
            if (!outputfilename.empty) {
                fout = File(outputfilename, "w");
            }
            scope (exit) {
                if (fout !is stdout) {
                    fout.close;
                }
            }
            if (dry_switch) {
                fout.rawWrite(sender.serialize);
            }
            auto receiver = hirpc.receive(sender);
            auto response = db(receiver, false);

            if (strip) {

                auto recorder = db.recorder(response.result);
                foreach (arcive; recorder[]) {
                    fout.rawWrite(arcive.filed.serialize);
                }
                return 0;
            }
            fout.rawWrite(response.toDoc.serialize);
            return 0;
        }
        if (!dartrim.empty) {
            File fout;
            fout = stdout;
            Rims rims;
            Buffer keys;
            if (dartrim != "root") {
                auto rim_and_keys = dartrim.split(":");
                auto rim_path = rim_and_keys.front;
                rim_and_keys.popFront;
                auto rim_decimals = rim_path.split(",");
                if (!rim_decimals.empty && rim_decimals.length > 1) {
                    rim_path = format("%(%02x%)", rim_decimals
                            .until!(key => key.empty)
                            .map!(key => key.to!ubyte));
                }
                rims = Rims(rim_path.decode);
                if (!rim_and_keys.empty) {
                    string keys_hex = rim_and_keys.front;
                    auto keys_decimals = keys_hex.split(",");
                    if (keys_decimals.length > 1) {

                        keys_hex = format("%(%02x%)", keys_decimals
                                .until!(key => key.empty)
                                .map!(key => key.to!ubyte));

                    }
                    keys = keys_hex.decode;
                }
            }
            verbose("Rim : %(%02x %):%(%02x %)", rims.rims, keys);
            const sender = CRUD.dartRim(rims, hirpc);
            if (!outputfilename.empty) {
                fout = File(outputfilename, "w");
            }
            scope (exit) {
                if (fout !is stdout) {
                    fout.close;
                }
            }
            if (dry_switch) {
                fout.rawWrite(sender.serialize);
                return 0;
            }
            auto receiver = hirpc.receive(sender);
            auto response = db(receiver, false);

            if (strip) {
                fout.rawWrite(response.result.serialize);
                return 0;
            }
            fout.rawWrite(response.toDoc.serialize);
            return 0;
        }
        if (dartmodify) {
            db.close;
            db = new DART(net, dartfilename);
            tools.check(!inputfilename.empty, "Missing input file DART-modify");
            const doc = inputfilename.fread;
            auto factory = RecordFactory(net);
            auto recorder = factory.recorder(doc);
            auto sended = CRUD.dartModify(recorder, hirpc);
            auto received = hirpc.receive(sended);
            auto result = db(received, false);
            auto tosend = hirpc.toHiBON(result);
            auto tosendResult = tosend.method.params;
            if (!outputfilename.empty) {
                outputfilename.fwrite(tosendResult);
            }
            return 0;
        }
    }
    catch (Exception e) {
        error(e);
        return 1;
    }

    return 0;
}

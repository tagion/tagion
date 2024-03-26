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
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.dart.BlockFile : Index;
import tagion.utils.Term;
import std.range;
import tagion.basic.range;

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
    string test_dart;
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
    bool flat_disable;
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
                "r|read", "Executes a DART read sequency", &dartread_args,
                "rim", "Performs DART rim read", &dartrim,
                "m|modify", "Executes a DART modify sequency", &dartmodify,
                "rpc", "Executes a HiPRC on the DART", &dartrpc,
                "strip", "Strips the dart-recoder dumps archives", &strip,
                "f|force", "Force erase and create journal and destination DART", &force,
                "print", "prints all the archives with in the given angle", &print,
                "dump", "Dumps all the archives with in the given angle", &dump,
                "dump-branches", "Dumps all the archives and branches with in the given angle", &dump_branches,
                "eye", "Prints the bullseye", &eye,
                "sync", "Synchronize src.drt to dest.drt", &sync,
                "e|exec", "Execute string to be used for remote access", &exec,
                "P|passphrase", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
                "A|angle", "Sets angle range from:to (Default is full range)", &angle_range,
                "depth", "Set limit on dart rim depth", &depth,
                "fake", format(
                    "Use fakenet instead of real hashes : default :%s", fake), &fake,
                "test", "Generate a test dart with specified number of archives total:bundle", &test_dart,
                "flat-disable", "Disable flat branch hash", &flat_disable,
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
                    "Documentation: https://docs.tagion.org/",
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
                    format("Angle range should be ex. --range A0F0:B0F8 not %s", angle_range));
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
            const flat = (flat_disable) ? No.flat : Yes.flat;
            DART.create(filename : dartfilename, net:
                    net, flat:
                    flat);
            return 0;
        }
        if (!test_dart.empty) {
            import std.random;
            import std.datetime.stopwatch;

            auto test_params = test_dart.split(':').map!(param => param.to!ulong);
            const number_of_archives = test_params.eatOne;
            const bundle_size = test_params.eatOne(ulong(1000));
            auto test_db = new DART(net, dartfilename);
            scope (exit) {
                test_db.close;
            }
            static struct TestDoc {
                string text;
                mixin HiBONRecord;
            }

            static const(Document) test_doc(const ulong x) {
                TestDoc _test_doc;
                _test_doc.text = format("Test document %d", x);
                return _test_doc.toDoc;
            }

            const(Document) function(const ulong) doc_gen = &test_doc;
            if (fake) {
                doc_gen = &DARTFakeNet.fake_doc;
            }
            //enum bundle_size = 1000;
            size_t count;
            auto rnd = Random(unpredictableSeed);

            enum line_length = 40;
            void progress(const size_t s, const(char[]) color) {
                nobose("\r%s%-(%s%)%s%s%s", GREEN, '#'.repeat(s % line_length), color, "#", RESET);
            }

            auto rec_time = StopWatch(AutoStart.no);
            auto dart_time = StopWatch(AutoStart.no);
            long prev_dart_time;
            foreach (no; 0 .. (number_of_archives / bundle_size) + 1) {
                count += bundle_size;
                const N = (number_of_archives < count) ? number_of_archives % bundle_size : bundle_size;
                auto rec = test_db.recorder;
                progress(no, RED);
                rec_time.start;
                foreach (i; 0 .. N) {
                    const random_doc_no = uniform(ulong.min, ulong.max, rnd);
                    rec.add(doc_gen(random_doc_no));
                }
                rec_time.stop;
                progress(no, YELLOW);
                dart_time.start;
                test_db.modify(rec);
                dart_time.stop;
                progress(no, GREEN);
                if ((no + 1) % line_length == 0) {
                    const current_dart_time = dart_time.peek.total!"usecs";
                    const delta_dart_time = current_dart_time - prev_dart_time;
                    prev_dart_time = current_dart_time;
                    nobose(" dart %.3fmsec per archive %.3fmsec blocks %d",
                            double(delta_dart_time) / 1000.0,
                            double(delta_dart_time) / (1000.0 * line_length * bundle_size),
                            count);
                    vout.writeln;
                }
            }
            return 0;
        }

        Exception dart_exception;
        auto db = new DART(net, dartfilename, dart_exception, Yes.read_only);
        if (dart_exception !is null) {
            error("Fail to open DART: %s. Abort.", dartfilename);
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

        File fout;
        fout = stdout;
        if (!outputfilename.empty) {
            fout = File(outputfilename, "w");
            verbose("Output file %s", outputfilename);
        }
        scope (exit) {
            if (fout !is stdout) {
                fout.close;
            }
        }
        if (print) {
            db.dump(sectors, Yes.full, depth);
        }
        else if (eye) {
            writefln("EYE: %(%02x%)", db.fingerprint);
        }
        else if (dump || dump_branches) {
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
                "Only one of the dartrpc, dartread, dartrim, dartmodify switched allowed");

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
            DARTIndex[] dart_indices;
            foreach (read_arg; dartread_args) {
                import tagion.tools.dartutil.dartindex : dartIndexDecode;

                auto dart_index = net.dartIndexDecode(read_arg);
                verbose("%s\n%s\n%(%02x%)", read_arg, dart_index.encodeBase64, dart_index);
                dart_indices ~= dart_index;
            }

            const sender = CRUD.dartRead(dart_indices, hirpc);
            if (dry_switch) {
                fout.rawWrite(sender.serialize);
            }
            auto receiver = hirpc.receive(sender);
            auto response = db(receiver, false);

            if (strip) {

                auto recorder = db.recorder(response.result);
                foreach (archive; recorder[]) {
                    fout.rawWrite(archive.filed.serialize);
                }
                return 0;
            }
            fout.rawWrite(response.toDoc.serialize);
            return 0;
        }
        if (!dartrim.empty) {
            Rims rims;
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
                string keys_hex;
                if (!rim_and_keys.empty) {
                    keys_hex = rim_and_keys.front;
                    auto keys_decimals = keys_hex.split(",");
                    if (keys_decimals.length > 1) {

                        keys_hex = format("%(%02x%)", keys_decimals
                                .until!(key => key.empty)
                                .map!(key => key.to!ubyte));

                    }
                    //         rim_keys = keys_hex.decode;
                }
                rims = Rims(rim_path.decode, keys_hex.decode);
            }
            verbose("Rim : %(%02x %):%(%02x %)", rims.path, rims.key_leaves);
            const sender = CRUD.dartRim(rims, hirpc);
            verbose("sender %s", sender.toPretty);
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
            if (fout != stdout) {
                fout.rawWrite(tosendResult.serialize);
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

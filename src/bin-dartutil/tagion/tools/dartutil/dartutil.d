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
import std.range;
import std.exception;

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

import tagion.Keywords;
import tagion.dart.DARTFakeNet;
import tagion.dart.DARTRim;
import tagion.dart.Recorder;
import tagion.hibon.HiBONtoText : decode, encodeBase64;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.dart.BlockFile : Index;
import tagion.utils.Term;
import tagion.basic.range;

/**
 * @brief tool for working with local DART database
 */

mixin Main!_main;

private struct Operation {
    bool initialize;
    bool sync;
    bool flat_disable;
    bool strip;
    SectorRange sectors;
    string inputfilename;
    string outputfilename;

    bool print;
    bool eye;
    bool dump;
    bool dump_branches;
    uint depth;

    bool oneread() => print + eye + dump + dump_branches <= 1;
    bool anyread() => print || eye || dump || dump_branches;

    bool dartrpc;
    string[] dartread_args;
    string dartrim_arg;
    bool dartmodify;

    bool dartrim() => !dartrim_arg.empty;
    bool dartread() => dartread_args.length > 0;
    bool onecrud() => dartrpc + dartread + dartrim + dartmodify <= 1;
    bool anycrud() => dartrpc || dartread || dartrim || dartmodify;

    bool any() => anycrud || anyread;

    void checkCompatible() {
        tools.check(sync ^ any, "The sync operation is not compatible any read or crud operation");
        tools.check(onecrud, "Only one crud operation is possible at a time");
        tools.check(oneread, "Only one read operation is possible at a time");
    }
}

int _main(string[] args) {
    immutable program = args[0];

    Operation op;
    string[] dart_filenames;
    string journal_path = buildPath(tempDir, "dart_journals");
    bool version_switch;
    const logo = import("logo.txt");

    string test_dart;
    string angle_range;
    string exec;
    bool fake;
    string passphrase = "verysecret";

    GetoptResult main_args;
    try {
        main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "verbose|v", "Prints verbose information to console", &__verbose_switch,
            "dry", "Dry-run this will not save the wallet", &__dry_switch,
            "I|initialize", "Create a dart file", &op.initialize,
            "o|outputfile", "Sets the output file name", &op.outputfilename,
            "r|read", "Executes a DART read sequency", &op.dartread_args,
            "rim", "Performs DART rim read", &op.dartrim_arg,
            "m|modify", "Executes a DART modify sequency", &op.dartmodify,
            "rpc", "Executes a HiPRC on the DART", &op.dartrpc,
            "strip", "Strips the dart-recoder dumps archives", &op.strip,
            "print", "prints all the archives with in the given angle", &op.print,
            "dump", "Dumps all the archives with in the given angle", &op.dump,
            "dump-branches", "Dumps all the archives and branches with in the given angle", &op.dump_branches,
            "eye", "Prints the bullseye", &op.eye,
            "sync", "Synchronize src.drt to dest.drt", &op.sync,
            "e|exec", "Execute string to be used for remote access", &exec,
            "P|passphrase", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
            "A|angle", "Sets angle range from:to (Default is full range)", &angle_range,
            "depth", "Set limit on dart rim depth", &op.depth,
            "fake", format(
                "Use fakenet instead of real hashes : default :%s", fake), &fake,
            "test", "Generate a test dart with specified number of archives total:bundle", &test_dart,
            "flat-disable", "Disable flat branch hash", &op.flat_disable,
        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (op.outputfilename.empty) {
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
            op.sectors = SectorRange(_from, _to);
        }
        foreach (file; args[1 .. $]) {
            if (file.hasExtension(FileExtension.hibon)) {
                tools.check(op.inputfilename is null,
                    format("Input file '%s' has already been declared", op.inputfilename));
                op.inputfilename = file;
                continue;
            }
            if (file.hasExtension(FileExtension.dart)) {
                dart_filenames ~= file;
            }
        }

        SecureNet net;

        tools.check(!dart_filenames.empty, "No dart files were specified");

        if (dart_filenames[0].exists) {
            auto blockfile = BlockFile(dart_filenames[0], Yes.read_only);
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

        if (!test_dart.empty) {
            import std.random;
            import std.datetime.stopwatch;

            auto test_params = test_dart.split(':').map!(param => param.to!ulong);
            const number_of_archives = test_params.eatOne;
            const bundle_size = test_params.eatOne(ulong(1000));
            auto test_db = new DART(net, dart_filenames[0]);
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
                const N = (number_of_archives < count) ? number_of_archives % bundle_size
                    : bundle_size;
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

        op.checkCompatible();

        File fout;
        if (!op.outputfilename.empty) {
            fout = File(op.outputfilename, "w");
            verbose("Output file %s", op.outputfilename);
        }
        else {
            fout = stdout;
        }
        scope (exit) {
            if (fout !is stdout) {
                fout.close;
            }
        }

        Exception dart_exception;
        if (op.sync) {
            tools.check(dart_filenames.length == 2,
                    "A source and a destination dart file is required for the sync operation");
            string src_dart_filename = dart_filenames[0];
            string dst_dart_filename = dart_filenames[1];

            if (!dst_dart_filename.exists) {
                DART.create(dst_dart_filename, net);
                writefln("DART %s created", dst_dart_filename);
            }
            auto dest_db = new DART(net, dst_dart_filename, dart_exception);
            writefln("Open destination %s", dst_dart_filename);
            if (dart_exception !is null) {
                writefln("Fail to open destination DART: %s. Abort.", dst_dart_filename);
                error(dart_exception);
                return 1;
            }
            auto src_db = new DART(net, src_dart_filename, dart_exception, Yes.read_only);
            if (dart_exception !is null) {
                error("Fail to open DART: %s. Abort.", src_dart_filename);
                error(dart_exception);
                return 1;
            }

            immutable _journal_path = buildPath(journal_path, dst_dart_filename.baseName.stripExtension);

            verbose("journal path %s", journal_path);
            if (journal_path.exists) {
                journal_path.rmdirRecurse;
            }
            journal_path.mkdirRecurse;
            writefln("Synchronize journals %s", _journal_path);
            synchronize(dest_db, src_db, _journal_path);
            return 0;
        }
        else {
            foreach(filename; dart_filenames) {
                verbose("%s:", filename);
                dartutil_operation(op, filename, net, fout);
            }
        }
    }
    catch (Exception e) {
        error(e);
        return 1;
    }

    return 0;
}

int dartutil_operation(Operation op, string dartfilename, const SecureNet net, ref File fout) {
    with(op) {
        if (initialize) {
            const flat = (flat_disable) ? No.flat : Yes.flat;
            DART.create(filename : dartfilename, net: net, flat: flat);
        }

        Exception dart_exception;
        auto db = new DART(net, dartfilename, dart_exception, Yes.read_only);
        if (dart_exception !is null) {
            error("Fail to open DART: %s. Abort.", dartfilename);
            error(dart_exception);
            return 1;
        }

        if (print) {
            db.dump(sectors, Yes.full, depth);
        }
        else if (eye) {
            writefln("%s%(%02x%)", DARTFile.eye_prefix, db.fingerprint);
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
        }

        const hirpc = HiRPC(net);

        if (dartrpc) {
            tools.check(!inputfilename.empty, "Missing input file for DART-rpc");
            const doc = inputfilename.fread;
            const received = hirpc.receive(doc);
            const result = db(received);
            const tosendResult = result.response.result[Keywords.result].get!Document;
            op.outputfilename.fwrite(tosendResult);
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
        if (dartrim) {
            Rims rims;
            if (dartrim_arg != "root") {
                auto rim_and_keys = dartrim_arg.split(":");
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
    return 0;
}

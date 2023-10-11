/// \file dartutil.d

module tagion.tools.dartutil.dartutil;

import std.getopt;
import std.stdio;
import std.file : exists, tempDir, mkdirRecurse, rmdirRecurse;
import std.path : setExtension, buildPath, baseName, stripExtension, dirName;
import std.format;
import std.conv : to;
import std.array;
import std.algorithm;
import std.typecons;

import tools = tagion.tools.toolsexception;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile;
import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTcrud : dartRead, dartModify;

import tagion.basic.basic : tempfile;

import tagion.communication.HiRPC;
import tagion.prior_services.DARTSynchronization;

import tagion.gossip.GossipNet;
import tagion.gossip.AddressBook;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.dart.BlockFile : BlockFile;
import tagion.tools.dartutil.synchronize;

import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;

//import tagion.utils.Miscellaneous;
import tagion.hibon.HiBONtoText : decode, encodeBase64;
import tagion.Keywords;
import tagion.dart.Recorder;
import tagion.script.prior.StandardRecords;
import tagion.script.NameCardScripts : readStandardRecord;

import tagion.tools.Basic;
import tagion.dart.DARTFakeNet;
import tagion.tools.revision;

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

    bool dump;

    //   bool dartread;
    string[] dartread_args;
    bool dartmodify;
    bool dartrim;
    bool dartrpc;
    bool sync;
    bool eye;
    bool fake;
    bool force;

    bool initialize;
    string passphrase = "verysecret";

    GetoptResult main_args;

    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, //   "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
                "i|inputfile", "Sets the HiBON input file name", &inputfilename,
                "I|initialize", "Create a dart file", &initialize,
                "o|outputfile", "Sets the output file name", &outputfilename,
                "r|read", "Excutes a DART read sequency", &dartread_args,
                "rim", "Performs DART rim read", &dartrim,
                "m|modify", "Excutes a DART modify sequency", &dartmodify,
                "f|force", "Force erase and create journal and destination DART", &force,
                "rpc", "Excutes a HiPRC on the DART", &dartrpc,
                "dump", "Dumps all the archives with in the given angle", &dump,
                "eye", "Prints the bullseye", &eye,
                "sync", "Synchronize src.drt to dest.drt", &sync,
                "P|passphrase", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
                "verbose|v", "Print output to console", &__verbose_switch,
                "fake", format("Use fakenet instead of real hashes : default :%s", fake), &fake,
        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
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
        if (!dartfilename.empty) {
            writefln("Deprecation notice: the -d / --dartfilename is deprecated. \n Please use dartutil FILENAME switches instead");
        }

        if (!inputfilename.empty) {
            writefln("Deprecation notice: the -i / --inputfilename is deprecated. \n Please use dartutil FILENAME switches instead");
        }
        //        dartread = !dartread_args.empty;
        foreach (file; args[1 .. $]) {
            if (file.hasExtension(FileExtension.hibon)) {
                tools.check(inputfilename is null, format("Input file '%s' has already been declared", inputfilename));
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
            auto blockfile = BlockFile(dartfilename);
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
        auto db = new DART(net, dartfilename, dart_exception);
        if (dart_exception !is null) {
            writefln("Fail to open DART: %s. Abort.", dartfilename);
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

        if (dump) {
            db.dump(true);
        }
        else if (eye) {
            writefln("EYE: %s", db.fingerprint.hex);
        }

        const dartread = dartread_args.length > 0;
        const onehot = dartrpc + dartread + dartrim + dartmodify;

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
            DARTIndex[] dart_indices;
            writefln("%s", dartread_args);
            foreach (read_arg; dartread_args) {
                import tagion.dart.DARTBasic : dartIndexDecode;

                auto dart_index = net.dartIndexDecode(read_arg);
                verbose("%s\n%s\n%(%02x%)", read_arg, dart_index.encodeBase64, dart_index);
                dart_indices ~= dart_index;
            }

            const sender = dartRead(dart_indices, hirpc);
            auto receiver = hirpc.receive(sender.toDoc);
            auto result = db(receiver, false);
            auto tosend = hirpc.toHiBON(result);
            const tosendResult = tosend.method.params;
            if (outputfilename.empty) {
                stdout.rawWrite(tosendResult.serialize);
                return 0;
            }
            outputfilename.fwrite(tosendResult);
            return 0;
        }
        if (dartrim) {
            version (none) {
                if (!inputfile_switch) {
                    writeln("No input file provided. Use -i to specify input file");
                }
                else {
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
            }
            return 1;
        }
        if (dartmodify) {
            tools.check(!inputfilename.empty, "Missing input file DART-modify");
            const doc = inputfilename.fread;
            auto factory = RecordFactory(net);
            auto recorder = factory.recorder(doc);
            auto sended = dartModify(recorder, hirpc);
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

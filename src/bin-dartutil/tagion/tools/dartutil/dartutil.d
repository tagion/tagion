/// \file dartutil.d

module tagion.tools.dartutil.dartutil;

import std.getopt;
import std.stdio;
import std.file : exists, tempDir, mkdirRecurse;
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

import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.dart.Recorder;
import tagion.script.StandardRecords;
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
    string outputfilename = tempfile;
    bool version_switch;
    const logo = import("logo.txt");

    bool dump;

    bool dartread;
    string[] dartread_args;
    bool dartmodify;
    bool dartrim;
    bool dartrpc;
    bool sync;
    bool eye;
    bool fake;

    bool initialize;
    string passphrase = "verysecret";

    GetoptResult main_args;

    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
                "initialize", "Create a dart file", &initialize,
                "inputfile|i", "Sets the HiBON input file name", &inputfilename,
                "outputfile|o", "Sets the output file name", &outputfilename,
                "read|r", "Excutes a DART read sequency", &dartread_args,
                "rim", "Performs DART rim read", &dartrim,
                "modify|m", "Excutes a DART modify sequency", &dartmodify,
                "rpc", "Excutes a HiPRC on the DART: default %s", &dartrpc,
                "dump", "Dumps all the arcvives with in the given angle", &dump,
                "eye", "Prints the bullseye", &eye,
                "sync", "Synchronize src.drt to dest.drt", &sync,
                "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
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
                    format("%s --sync src.drt dst.drt]", program),
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }

        dartread = !dartread_args.empty;
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

        if (dartfilename.empty) {
            stderr.writefln("Error: Missing dart file");
        }

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
            writefln("Open dest_db %s", destination_dartfilename);
            if (dart_exception !is null) {
                writeln("Fail to open destination DART: %s. Abort.", destination_dartfilename);
                error(dart_exception);
                return 1;
            }
            immutable jounal_path = buildPath(tempDir, "dart_sync",
                    destination_dartfilename.baseName.stripExtension);

            jounal_path.dirName.mkdirRecurse;
            writefln("Synchronize");
            synchronize(dest_db, db, jounal_path);
        }

        if (dump) {
            db.dump(true);
        }
        else if (eye) {
            writefln("EYE: %s", db.fingerprint.hex);
        }

        /**
     * Prints document to console depending on parameters
     * @param doc - document to output
     * @param indent_line - flag to put indent line in console before printing doc
     * @param alternative_text - text to replace doc output when flag verbose is off
     */
        void toConsole(T)(T doc, bool indent_line = false, string alternative_text = "")
                if (isHiBONRecord!T || is(T == Document)) {
            if (verbose_switch) {
                if (indent_line)
                    writeln;
                writefln("%s: %s", T.stringof, doc.toPretty);
            }
            else if (!alternative_text.empty) {
                writeln(alternative_text);
            }
        }

        const onehot = dartrpc + dartread + dartrim + dartmodify;

        if (onehot > 1) {
            stderr.writeln(
                    "Only one of the dartrpc, dartread, dartrim, dartmodify switched alowed");
            return 1;
        }

        bool inputfile_switch = !inputfilename.empty;
        if (inputfile_switch) {
            if (!inputfilename.exists) {
                writefln("Can't open input file '%s'. Abort", inputfilename);
                return 1;
            }
        }

        if (dartrpc) {
            if (!inputfile_switch) {
                writeln("No input file provided. Use -i to specify input file");
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
            DARTIndex[] fingerprints;
            fingerprints = dartread_args
                .map!(hash => DARTIndex(decode(hash))).array;

            const sender = dartRead(fingerprints, hirpc);
            auto receiver = hirpc.receive(sender.toDoc);
            auto result = db(receiver, false);
            auto tosend = hirpc.toHiBON(result);
            const tosendResult = tosend.method.params;

            outputfilename.fwrite(tosendResult);
            writefln("Result has been written to '%s'", outputfilename);

            toConsole!Document(result.message);
        }
        else if (dartrim) {
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
        else if (dartmodify) {
            if (!inputfile_switch) {
                writeln("No input file provided. Use -i to specify input file");
            }
            else {
                const doc = inputfilename.fread;
                auto factory = RecordFactory(net);
                auto recorder = factory.recorder(doc);
                auto sended = dartModify(recorder, hirpc);
                auto received = hirpc.receive(sended);
                auto result = db(received, false);
                auto tosend = hirpc.toHiBON(result);
                auto tosendResult = tosend.method.params;
                if (dump)
                    db.dump(true);
                outputfilename.fwrite(tosendResult);
            }
        }
    }
    catch (Exception e) {
        error(e);
        // writefln("Error parsing argument list: %s Abort", e.msg);
        return 1;
    }

    return 0;
}

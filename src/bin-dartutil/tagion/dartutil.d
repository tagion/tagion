module tagion.dartutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists;
import std.format;
import std.conv : to;
import std.array;

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

import tagion.utils.Miscellaneous;
import tagion.Keywords;
// import tagion.revision;

pragma(msg, "fixme(cbr): This import is dummy force the tub to link liboption");
import tagion.utils.Gene;
import tagion.utils.Miscellaneous;

int main(string[] args) {
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
    bool dartmodify = false;
    bool dartrpc = false;
    bool generate = false;

    ubyte ringWidth = 4;
    int rings = 4;
    bool initialize = false;
    string passphrase = "verysecret";

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "dartfilename|drt", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
            "initialize", "Create a dart file", &initialize,
            "inputfile|i", "Sets the HiBON input file name", &inputfilename,
            "outputfile|o", "Sets the output file name", &outputfilename,
            "from", format("Sets from angle: default %s", (fromAngle == toAngle) ? "full"
            : fromAngle.to!string), &fromAngle,
            "to", format("Sets to angle: default %s", (fromAngle == toAngle) ? "full"
            : toAngle.to!string), &toAngle,
            "useFakeNet|fn", format("Enables fake hash test-mode: default %s", useFakeNet), &useFakeNet,
            "read|r", format("Excutes a DART read sequency: default %s", dartread), &dartread,
            "modify|m", format("Excutes a DART modify sequency: default %s", dartmodify), &dartmodify,
            "rpc", format("Excutes a HiPRC on the DART: default %s", dartrpc), &dartrpc,
            "generate", "Generate a fake test dart (recomended to use with --useFakeNet)", &generate,
            "dump", "Dumps all the arcvives with in the given angle", &dump,
            "width|w", "Sets the rings width and is used in combination with the generate", &ringWidth,
            "rings", "Sets the rings height and is used in  combination with the generate", &rings,
            "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase
    );

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

    const onehot = dartrpc + dartread + dartmodify;

    if (onehot > 1) {
        stderr.writeln("Only one of the dartrpc, dartread and dartmodify switched alowed");
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
            auto inputBuffer = cast(immutable(ubyte)[])fread(inputfilename);
            auto params=new HiBON;
            auto params_fingerprints=new HiBON;
            foreach(i, b; (cast(string)inputBuffer).split("\n")) {
                auto fp = decode(b);
                if ( b.length !is 0 ) {
                    params_fingerprints[i]=fp;
                }
            }
            
            params[DARTFile.Params.fingerprints]=params_fingerprints;
            auto sended = hirpc.dartRead(params).toDoc;
            auto received = hirpc.receive(sended);
            auto result = db(received);
            auto tosend = hirpc.toHiBON(result);
            auto tosendResult = tosend.method.params;
            writeResponse(tosendResult.serialize);
        }
    }
    else if (dartmodify) {
        auto inputBuffer = cast(immutable(ubyte)[]) fread(inputfilename);
        import tagion.dart.Recorder;

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder(Document(inputBuffer));
        auto sended = hirpc.dartModify(recorder);
        auto received = hirpc.receive(sended.toDoc);
        auto result = db(received, false);
        auto tosend = hirpc.toHiBON(result);
        auto tosendResult = tosend.method.params;
        if (dump)
            db.dump(true);
        writeResponse(tosendResult.serialize);
    }
    return 0;
}

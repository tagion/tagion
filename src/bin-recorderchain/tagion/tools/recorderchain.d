/// \file recorderchain.d
module tagion.tools.recorderchain;

/**
 * @brief tool replay whole recorder chain in DART database
 */

import std.array;
import std.file : copy, exists;
import std.format;
import std.getopt;
import std.path;
import std.stdio;
import tagion.basic.Types : FileExtension;
import tagion.basic.tagionexceptions;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
// import tagion.prior_services.RecorderService;
import tagion.recorderchain.RecorderChain;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;
import tagion.tools.Basic;
import tagion.utils.Miscellaneous : cutHex, toHexString;

auto logo = import("logo.txt");

mixin Main!(_main, "tagionrecorderchain");

int _main(string[] args) {
    immutable program = args[0];

    if (args.length == 1) {
        writeln("Error: No arguments provided for ", baseName(args[0]), "!");
        return 1;
    }

    /** Net for DART database creation */
    SecureNet secure_net = new StdSecureNet;
    /** Net for recorder factory creation */
    const hash_net = new StdHashNet;
    /** Used for create recorder */
    auto factory = RecordFactory(hash_net);
    /** Passphrase for generate key pair for secure net */
    string passphrase = "verysecret";
    secure_net.generateKeyPair(passphrase);
    /** Directory for recorder block chain */
    string chain_directory;
    /** Directory for DART database */
    string dart_file;
    /** Directory for genesis DART */
    string gen_dart_file;

    bool interactive_mode;

    
    GetoptResult main_args;

    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "chaindirectory|c", "Path to recorder chain directory", &chain_directory,
                "dartfile|d", "Path to dart file", &dart_file,
                "genesisdart|g", "Path to genesis dart file", &gen_dart_file,
                "interactive|i", "Go through the recorder in interactive mode", &interactive_mode,
        );

        if (main_args.helpWanted) {
            writeln(logo);
            defaultGetoptPrinter(
                    [
                // format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...]", program),
                "",
                "Examples:",
                "# To run recorer chain specify 3 required parameters",
                format("%s -с chain_directory -d new_dart.drt -g genesis_dart.drt", program),
                "",
                "<option>:",

            ].join("\n"),
                    main_args.options);
            return 0;
        }
    }
    catch (Exception e) {
        stderr.writefln(e.msg);
        return 1;
    }

    // Check genesis DART file 
    if (!gen_dart_file.exists || gen_dart_file.extension != FileExtension.dart) {
        writefln("Incorrect genesis DART file '%s'", gen_dart_file);
        return 1;
    }

    // Copy genesis DART as base for DART that is being recovered
    gen_dart_file.copy(dart_file);

    // Open new DART file
    DART dart;
    try {
        dart = new DART(secure_net, dart_file);
    }
    catch (Exception e) {
        writefln("Invalid format of genesis DART file '%s'", gen_dart_file);
        return 1;
    }

    // Check existence of recorder chain directory
    if (!chain_directory.exists) {
        writefln("Recorder chain directory '%s' does not exist", chain_directory);
        return 1;
    }

    RecorderChainStorage storage = new RecorderChainFileStorage(chain_directory, hash_net);
    auto recorder_chain = new RecorderChain(storage);

    // Check validity of recorder chain
    if (!recorder_chain.isValidChain) {
        writeln("Recorder block chain is not valid!\nAbort");
        return 1;
    }

    // Collect info from chain directory
    auto blocks_count = recorder_chain.storage.getHashes.length;
    if (blocks_count == 0) {
        writeln("No recorder chain files");
        return 1;
    }
    import core.stdc.stdio;


    import tagion.hibon.HiBONJSON;
    try {
        recorder_chain.replay((RecorderChainBlock block) {
            writefln("current bullseye<%s>", dart.bullseye.toHexString);
            if (interactive_mode) {
                writefln("recorder that will be added:\n%s", block.recorder_doc.toPretty);
                const input = getchar;
            }

            auto recorder = factory.recorder(block.recorder_doc);
            dart.modify(recorder);
            if (block.bullseye != dart.bullseye) {
                stderr.writeln(format("ERROR: expected bullseye: %s \ngot %s", 
                    block.bullseye.toHexString, 
                    dart.bullseye.toHexString));
            }
        });
    }
    catch(TagionException e) {
        writefln("%s. Abort", e.msg);
        return 1;
    }    

    

    // // Recover DART using blocks
    // try {
    //     recorder_chain.replay((RecorderChainBlock block) {
    //         auto recorder = factory.recorder(block.recorder_doc);
    //         dart.modify(recorder);
    //         writefln("replaying %s", block.getHash.toHexString);
    //         if (block.bullseye != dart.bullseye) {
    //             throw new TagionException(
    //                 "DART fingerprint must be the same as recorder block bullseye");
    //         }
    //     });
    // }
    // catch (TagionException e) {
    //     writefln("%s. Abort", e.msg);
    //     return 1;
    // }

    return 0;
}

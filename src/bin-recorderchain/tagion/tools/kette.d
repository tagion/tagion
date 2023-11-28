/// \file kette.d
module tagion.tools.kette;

/**
 * @brief tool for replaying and undoing the dart database
 */

import tagion.tools.Basic;
import std.getopt;
import tagion.tools.revision;
import tagion.dart.DART;
import tagion.dart.Recorder;
import tagion.basic.Types : FileExtension;
import std.path : extension;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet;
import std.file : copy, exists;
import std.range;
import tagion.dart.DARTException;
import tagion.hibon.HiBONRecord: isRecord;



import tagion.recorderchain.RecorderChainBlock : RecorderBlock;


mixin Main!(_main, "tagionkette");

import std.stdio;

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;

    SecureNet secure_net = new StdSecureNet;
    const hash_net = new StdHashNet;
    auto factory = RecordFactory(hash_net);
    string genesis_dart;
    string dart_file;
    bool dry_run;

    string passphrase = "verysecret";
    secure_net.generateKeyPair(passphrase);
    
    GetoptResult main_args;
    try {
        main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        "v|verbose", "Prints more debug information", &__verbose_switch,
        "genesisdart|g", "Path to genesis dart file", &genesis_dart,
        "dartfile|d", "Path to dart file", &dart_file,
        "dry-run", "dry run the changes", &dry_run,
        );

        if (version_switch) {
            revision_text.writeln;
            return 0;
        }
        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                    // format("%s version %s", program, REVNO),
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    "",
                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }

        if (!genesis_dart.exists || genesis_dart.extension != FileExtension.dart) {
            error("incorrect genesis dart file");
            return 1;
        }
        // Copy genesis DART as base for DART that is being recovered
        genesis_dart.copy(dart_file);

        DART dart;
        scope(exit) {
            dart.close;
        }
        try {
            dart = new DART(secure_net, dart_file);
        }
        catch (DARTException e) {
            error(e);
            return 1;
        }


        
        import tagion.hibon.HiBONFile : HiBONRange;


        RecorderBlock prev_block;
        foreach(inputfilename; args[1 ..$]) {
            switch(inputfilename.extension) {
                case FileExtension.hibon:
                    auto fin = File(inputfilename, "r");
                    scope(exit) {
                        fin.close;
                    }

                    foreach(no, doc; HiBONRange(fin).enumerate) {
                        // add the blocks
                        if (!doc.isRecord!RecorderBlock) {
                            error("The document in the range was not of type RecorderBlock");
                            return 1;
                        }
                        const _block = RecorderBlock(doc);

                        if (!(prev_block is RecorderBlock.init && _block.previous is prev_block.fingerprint)) {
                            error("The chain is not valid");
                            return 1;
                        }

                        
                        const _recorder = factory.recorder(_block.recorder_doc);
                        verbose("epoch: %s, eye %(%02x), recorder length %s", _block.epoch_number, _block.bullseye, _recorder.length); 

                        if (dry_run) {
                            continue;
                        }

                        dart.modify(_recorder);
                        const new_bullseye = dart.bullseye;
                        if (_block.bullseye !is new_bullseye) {
                            error("Bullseye not correct after applying recorder");
                        }
                    }
                    break;
                default:
                    error("File %s not valid (only %(.%s %))",
                            inputfilename, only(FileExtension.hibon));
                    return 1;

            } 
        }


    } catch (Exception e) {
        error(e);
    }




    return 0;



}





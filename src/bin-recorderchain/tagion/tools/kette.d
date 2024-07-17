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
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONtoText;
import std.format;



import tagion.replicator.RecorderBlock;


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

    string passphrase = "verysecret";
    secure_net.generateKeyPair(passphrase);


    bool replay;
    bool replay_and_find;
    
    GetoptResult main_args;
    try {
        main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        "v|verbose", "Prints more debug information", &__verbose_switch,
        "genesisdart|g", "Path to genesis dart file", &genesis_dart,
        "dartfile|d", "Path to dart file", &dart_file,
        "replay|r", "Replay the recorder", &replay,
        "findreplay|f", "Find the block and replay from there", &replay_and_find,
        );

        if (version_switch) {
            revision_text.writeln;
            return 0;
        }
        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                    // format("%s version %s", program, REVNO),
                    "Documentation: https://docs.tagion.org/",
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

        if (replay) {
            // Copy genesis DART as base for DART that is being recovered
            genesis_dart.copy(dart_file);
        }

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


        if (replay) {
            foreach(inputfilename; args[1 ..$]) {
                writefln("going through the blocks of %s", inputfilename);
                if (inputfilename.extension != FileExtension.hibon) {
                    error("File %s not valid (only %(.%s %))",
                            inputfilename, only(FileExtension.hibon));
                    return 1;

                }
                auto fin = File(inputfilename, "r");
                scope(exit) {
                    fin.close;
                }

                RecorderBlock prev_block;
                foreach(no, doc; HiBONRange(fin).enumerate) {
                    // add the blocks
                    if (!doc.isRecord!RecorderBlock) {
                        error("The document in the range was not of type RecorderBlock");
                        return 1;
                    }
                    const _block = RecorderBlock(doc);

                
                    verbose("block %s", _block.toPretty);

                    if (prev_block !is RecorderBlock.init) {
                        const hash_of_prev = hash_net.calcHash(prev_block.toDoc);
                        if (hash_of_prev != _block.previous) {
                            error("The chain is not valid. fingerprint of previous %s=%s block %s expected %s", prev_block.epoch_number, hash_of_prev.encodeBase58, _block.epoch_number, _block.previous.encodeBase58); 

                        }
                    }

                    const _recorder = factory.recorder(_block.recorder_doc);
                    verbose("epoch: %s, eye %(%02x%), recorder length %s", _block.epoch_number, _block.bullseye, _recorder.length); 
                    const new_bullseye = dart.modify(_recorder);
                    if (_block.bullseye != new_bullseye) {
                        error(format("ERROR: expected bullseye: %(%02x%) \ngot %(%02x%)", 
                            _block.bullseye, 
                            new_bullseye));
                        return 1;
                    }
                    verbose("successfully added block");
                    prev_block = _block;
                }

            } 
            
        }

        if (replay_and_find) {
            bool match;

            const init_eye = dart.bullseye;
            verbose("searching for eye %(%02x%)", init_eye);
            foreach(inputfilename; args[1 ..$]) {
                writefln("going through the blocks of %s", inputfilename);
                if (inputfilename.extension != FileExtension.hibon) {
                    error("File %s not valid (only %(.%s %))",
                            inputfilename, only(FileExtension.hibon));
                    return 1;
                }
                auto fin = File(inputfilename, "r");
                scope(exit) {
                    fin.close;
                }

                RecorderBlock prev_block;
                Blocks: foreach(no, doc; HiBONRange(fin).enumerate) {
                    // add the blocks
                    if (!doc.isRecord!RecorderBlock) {
                        error("The document in the range was not of type RecorderBlock");
                        return 1;
                    }
                    const _block = RecorderBlock(doc);
                    scope(success) {
                        prev_block = _block;
                    }
                    if (prev_block !is RecorderBlock.init) {
                        const hash_of_prev = hash_net.calcHash(prev_block.toDoc);
                        if (hash_of_prev != _block.previous) {
                            error("The chain is not valid. fingerprint of previous %s=%s block %s expected %s", prev_block.epoch_number, hash_of_prev.encodeBase58, _block.epoch_number, _block.previous.encodeBase58); 

                        }
                    }

                    if (!match && _block.bullseye == init_eye) {
                        verbose("found a MATCH on epoch %d", _block.epoch_number);
                        match = true;
                        continue Blocks;
                    }

                    if (!match) {
                        verbose("Bullseye did not match searching next epoch %s", _block.epoch_number);
                        continue Blocks;
                    }
                    verbose("block %s", _block.toPretty);


                    const _recorder = factory.recorder(_block.recorder_doc);
                    verbose("epoch: %s, eye %(%02x%), recorder length %s", _block.epoch_number, _block.bullseye, _recorder.length); 
                    const new_bullseye = dart.modify(_recorder);
                    if (_block.bullseye != new_bullseye) {
                        error(format("ERROR: expected bullseye: %(%02x%) \ngot %(%02x%)", 
                            _block.bullseye, 
                            new_bullseye));
                        return 1;
                    }
                    verbose("successfully added block");
                }

            } 
            
        }

    } catch (Exception e) {
        error(e);
    }




    return 0;



}





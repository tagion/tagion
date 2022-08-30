/// \file recorderchain.d
module tagion.recorderchain;

/**
 * @brief tool replay whole recorder chain in DART database
 */

import std.stdio;
import std.getopt;
import std.path;
import std.format;
import std.file;
import std.array;

import tagion.basic.Types : Buffer;
import tagion.basic.TagionExceptions;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.dart.Recorder;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.services.RecorderService;
import tagion.communication.HiRPC;
import tagion.utils.Miscellaneous : toHexString, decode;
import tagion.dart.RecorderChainBlock;
import tagion.dart.RecorderChain;

auto logo = import("logo.txt");

/** 
 * Used to add recorder to DART database
 * @param db - DART database
 * @param recorder - recorder to add
 * @param hirpc - to modify DART database
 */
void addRecordToDB(DART db, RecordFactory.Recorder recorder, HiRPC hirpc) 
{
    auto sended = DART.dartModify(recorder, hirpc);
    auto received = hirpc.receive(sended);
    db(received, false);
}

int main(string[] args)
{
    if (args.length == 1)
    {
        writeln("Error: No arguments provided for ", baseName(args[0]), "!");
        return 1;
    }
    /** Net for DART database creation */
    SecureNet secure_net = new StdSecureNet;
    /** Net for recorder factory creation */
    const hash_net = new StdHashNet;
    /** Used for create recorder */
    auto factory = RecordFactory(hash_net);
    /** Passphrase for generate key pair for hirpc */
    string passphrase = "verysecret";
    secure_net.generateKeyPair(passphrase);
    /** Hirpc for create and modify DART database */
    auto hirpc = HiRPC(secure_net);
    /** Directory for recorder block chain */
    string chain_directory;
    /** Directory for DART database */
    string dart_file;
    /** Initialize new DART database */
    bool initialize;

   
    GetoptResult main_args;

    main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "chaindirectory|c", "Path to recorder chain directory", &chain_directory,
        "dartfile|d", "Path to dart file", &dart_file,
        "initialize|i", "Initialize empty DART", &initialize,
    );

    if (main_args.helpWanted)
    {
        writeln(logo);
        defaultGetoptPrinter(
            [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }
    
    chain_directory = args[1];
    dart_file = args[2];

    if(initialize)
    {
        /** Used for create new DART database */
        enum BLOCK_SIZE = 0x80;
        BlockFile.create(dart_file, DARTFile.stringof, BLOCK_SIZE);
        /** New DART database */
        DART db = new DART(secure_net, dart_file, 0, 0);

        /** List of recorder block names */ 
        auto block_filenames = RecorderChain.getBlockFilenames(chain_directory);

        /** Contains first, last, amount of recorder block */
        auto info = RecorderChain.getBlocksInfo(chain_directory, hash_net);
        /** Recorder from the first block in recorder block chain */
        auto first_recorder = factory.recorder(info.first.recorder_doc);

        addRecordToDB(db, first_recorder, hirpc);

        if(info.first.bullseye != db.fingerprint)
        {
            throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
            return 1;
        }
        
        /** Block, recorder from which will be added to DART database next */
        RecorderChainBlock next_block;
        next_block = RecorderChain.findNextDARTBlock(info.first.fingerprint, chain_directory, hash_net);
        /** Recorder of next block */
        auto next_recorder = factory.recorder(next_block.recorder_doc);

        addRecordToDB(db, next_recorder, hirpc);

        if(next_block.bullseye != db.fingerprint)
        {
            throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
            return 1;
        }

        foreach(cur_block; 0..(info.amount - 2)) 
        {
            next_block = RecorderChain.findNextDARTBlock(next_block.fingerprint, chain_directory, hash_net);  
            /** Recorder from *next* block */
            auto recorder = factory.recorder(next_block.recorder_doc);
            addRecordToDB(db, recorder, hirpc);
            if(next_block.bullseye != db.fingerprint)
            {
                throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
                return 1;
            }
        }
    }
    else
    {
        /** DART databse from file */
        DART db = new DART(secure_net, dart_file, 0, 0);

        /** Contains first, last, amount of recorder block */
        auto info = RecorderChain.getBlocksInfo(chain_directory, hash_net);
        if (info.last.bullseye == db.fingerprint)
        {
            return 0;
        }
        /** Bullseye of this block same with DART database fingerprint */
        auto cur_block = RecorderChain.findCurrentDARTBlock(db.fingerprint, chain_directory, hash_net);
        /** Block, recorder from which will be added to DART database next */
        auto next_block = RecorderChain.findNextDARTBlock(cur_block.fingerprint, chain_directory, hash_net);

        while(next_block.fingerprint != info.last.fingerprint)
        {
            /** Recorder from *next* block */
            auto recorder = factory.recorder(next_block.recorder_doc);
            addRecordToDB(db, recorder, hirpc);

            if(next_block.bullseye != db.fingerprint)
            {
                throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
                return 1;
            }
            
            next_block = RecorderChain.findNextDARTBlock(next_block.fingerprint, chain_directory, hash_net);
        }
        /** Recorder from *next* block */
        auto recorder = factory.recorder(next_block.recorder_doc);
        addRecordToDB(db, recorder, hirpc);

        if(next_block.bullseye != db.fingerprint)
        {
            throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
            return 1;
        }

    }

    return 0;
}

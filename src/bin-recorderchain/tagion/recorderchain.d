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
import tagion.utils.Fingerprint : Fingerprint;
import tagion.utils.Miscellaneous : toHexString, decode;
import tagion.dart.RecorderChainBlock;
import tagion.dart.RecorderChain;

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
    auto result = db(received, false);
}

/** 
 * Used find next block in recorder block chain
 * @param cur_fingerprint - fingerprint of current block from recorder block chain
 * @param blocks_folder - folder with blocks from recorder block chain
 * @param net - to read block from file
 * @return block from recorder block chain
 */
RecorderChainBlock findNextBlock(Buffer cur_fingerprint, string blocks_folder, const StdHashNet net) 
{
    auto block_filenames = RecorderChain.getBlockFilenames(blocks_folder);
    foreach (filename; block_filenames)
    {
        auto fingerprint = decode(filename.stripExtension);
        auto block = RecorderChain.readBlock(fingerprint, blocks_folder, net);
        if(block.chain) 
        {
            if (block.chain == cur_fingerprint)
            {
                return block;
            }
        }
    }
    assert(0);
}

/** 
 * Used find current block in recorder block chain
 * @param cur_bullseye - bullseye of DART database
 * @param blocks_folder - folder with blocks from recorder block chain
 * @param net - to read block from file
 * @return block from recorder block chain
 */
RecorderChainBlock findCurrentBlock(Buffer cur_bullseye, string blocks_folder, const StdHashNet net)
{
    auto block_filenames = RecorderChain.getBlockFilenames(blocks_folder);
    foreach (filename; block_filenames)
    {
        auto fingerprint = decode(filename.stripExtension);
        auto block = RecorderChain.readBlock(fingerprint, blocks_folder, net);
        
        if (block.bullseye == cur_bullseye)
        {
            return block;
        }  
    }
    assert(0);
}

int main(string[] args)
{
    writeln("bin-recorderchain run");

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
        remove(chain_directory~"/"~info.first.fingerprint.toHexString~".rcb");

        addRecordToDB(db, first_recorder, hirpc);

        
        if(info.first.bullseye != db.fingerprint)
        {
            throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
            return 1;
        }
       

        foreach(i; 0..(info.amount - 1)) 
        {
            /** Block, recorder from which will be added to DART database next */
            RecorderChainBlock next_block;
            if(!i)
            {
                next_block = findNextBlock(info.first.fingerprint, chain_directory, hash_net);
            }
            else if (i == info.amount - 2)
            {
                next_block = info.last;
            }
            else
            {
                next_block = findNextBlock(next_block.fingerprint, chain_directory, hash_net);
            }

            remove(chain_directory~"/"~next_block.fingerprint.toHexString~".rcb");
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
        auto cur_block = findCurrentBlock(db.fingerprint, chain_directory, hash_net);
        /** Block, recorder from which will be added to DART database next */
        auto next_block = findNextBlock(cur_block.fingerprint, chain_directory, hash_net);

        while(next_block.fingerprint != info.last.fingerprint)
        {
            /** Recorder from *next* block */
            auto recorder = factory.recorder(next_block.recorder_doc);
            remove(chain_directory~"/"~next_block.fingerprint.toHexString~".rcb");
            addRecordToDB(db, recorder, hirpc);

            if(next_block.bullseye != db.fingerprint)
            {
                throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
                return 1;
            }
            
            next_block = findNextBlock(next_block.fingerprint, chain_directory, hash_net);
        }
        /** Recorder from *next* block */
        auto recorder = factory.recorder(next_block.recorder_doc);
        remove(chain_directory~"/"~next_block.fingerprint.toHexString~".rcb");
        addRecordToDB(db, recorder, hirpc);

        if(next_block.bullseye != db.fingerprint)
        {
            throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
            return 1;
        }

    }

    return 0;
}

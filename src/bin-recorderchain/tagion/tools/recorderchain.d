/// \file recorderchain.d
module tagion.recorderchain;

/**
 * @brief tool replay whole recorder chain in DART database
 */

import std.stdio;
import std.getopt;
import std.path;
import std.file;
import std.array;
import std.format;

import tagion.basic.TagionExceptions;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.dart.Recorder;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.services.RecorderService;
import tagion.communication.HiRPC;
import tagion.dart.RecorderChainBlock;
import tagion.dart.RecorderChain;

auto logo = import("logo.txt");

/** 
 * Used to add recorder to DART database
 * @param db - DART database
 * @param recorder - recorder to add
 * @param hirpc - to modify DART database
 */
void addRecordToDB(DART db, RecordFactory.Recorder recorder, HiRPC hirpc) @safe
{
    auto sent = DART.dartModify(recorder, hirpc);
    auto received = hirpc.receive(sent);
    db(received, false);
}

int main(string[] args)
{
    immutable program = args[0];

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

    try
    {
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
                "Usage:",
                format("%s [<option>...]", program),
                "",
                "Examples:",
                "# To run recorer chain specify 2 required parameters",
                format("%s -с chain_directory -d DART_directory -i true", program),
                "",
                "<option>:",

            ].join("\n"),
            main_args.options);
            return 0;
        }
    }
    catch (Exception e)
    {
        stderr.writefln(e.msg);
        return 1;
    }
    
    if(!chain_directory.exists)
    {
        writeln(chain_directory, " directory does not exist");
        return 1;
    }

    if(!RecorderChain.isValidChain(chain_directory, hash_net))
    {
        writeln("Recorder block chain is not valid");
        return 1;
    }

    /** DART database */
    DART db;
    /** First, last, amount of blocks in chain */ 
    auto info = RecorderChain.getBlocksInfo(chain_directory, hash_net);
    if(!info.amount) 
    {
        writeln("Directory for recorder block chain is empty");
        return 1;
    }

    /** Block that should be pushed to DART database next*/
    RecorderChainBlock current_block;
    if (initialize)
    {
        try
        {
            BlockFile.create(dart_file, DARTFile.stringof, BLOCK_SIZE);
            /** Initialize DART database */
            db = new DART(secure_net, dart_file, 0, 0);
        }
        catch (Exception e)
        {
            writeln("Can not create DART file: ", dart_file);
            return 0;
        }
        current_block = info.first;
    }
    else
    {
        try
        {
            db = new DART(secure_net, dart_file, 0, 0);
        }
        catch (Exception e)
        {
            writeln("Can not open DART file: ", dart_file);
            return 0;
        }

        /** Used to find block that should be pushed to DART database next */
        auto block = RecorderChain.findCurrentDARTBlock(db.fingerprint, chain_directory, hash_net);
        if (block.fingerprint == info.last.fingerprint)
        {
            return 1;
        }
        current_block = RecorderChain.findNextBlock(block.fingerprint, chain_directory, hash_net);
    }

    do
    {
        /** Recorder to modify DART database */
        auto recorder = factory.recorder(current_block.recorder_doc);
        addRecordToDB(db, recorder, hirpc);
        if (current_block.bullseye != db.fingerprint)
        {
            throw new TagionException("DART fingerprint should be the same with recorder block bullseye");
            return 1;
        }
        current_block = RecorderChain.findNextBlock(current_block.fingerprint, chain_directory, hash_net);
    }
    while (current_block !is null);

    return 0;
}
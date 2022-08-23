module tagion.recorderchain;

import std.stdio;
import std.getopt;
import std.path;
import std.format;
import std.array;
import std.file;
import std.conv;

import tagion.basic.Types : Control, Buffer;

import tagion.basic.Basic : TrustedConcurrency;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.dart.Recorder;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.services.Options : Options, setDefaultOption;
import tagion.services.RecorderService;
import tagion.services.LoggerService;
import tagion.logger.Logger;
import tagion.communication.HiRPC;
import tagion.tasks.TaskWrapper : Task;
import tagion.utils.Fingerprint : Fingerprint;
import tagion.dart.RecorderChain : RecorderChain;

mixin TrustedConcurrency;

enum main_task = "recorderchain";

int main(string[] args)
{
    writeln("bin-recorderchain run");

    const auto EXEC_NAME = baseName(args[0]);

    if (args.length == 1)
    {
        writeln("Error: No arguments provided for ", EXEC_NAME, "!");
        return 1;
    }

    

    // Options options;
    // setDefaultOption(options);

    // auto loggerService = Task!LoggerTask(options.logger.task_name, options);
    // scope (exit)
    // {
    //     loggerService.control(Control.STOP);
    //     receiveOnly!Control;
    // }

    // const response = receiveOnly!Control;
    // stderr.writeln("Logger started");
    // if (response !is Control.LIVE)
    // {
    //     stderr.writeln("ERROR:Logger %s", response);
    // }

    // log.register(main_task);

    // bool print = false;
    // bool clean = false;
    // ulong rollback, init_count;

    string chain_directory;
    string dart_file;
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
    writeln(chain_directory, " ", dart_file, " ", initialize);




    import tagion.basic.Basic : tempfile;

    const temp_folder = tempfile ~ "/";
    scope (exit)
    {
        import std.file : rmdirRecurse;

        rmdirRecurse(temp_folder);
    }

    const net = new StdHashNet;

    auto factory = RecordFactory(net);
    immutable empty_recorder = cast(immutable) factory.recorder;
    const Buffer empty_bullseye = [];

    RecorderChain recorder_chain;

    /// RecorderChain_empty_folder
    {
        recorder_chain = new RecorderChain(temp_folder, net);

        assert(recorder_chain.getAmount == 0);
        assert(recorder_chain.getFirstBlock is null);
        assert(recorder_chain.getLastBlock is null);
    }

    /// RecorderChain_getBlockFilenames_empty
    {
        import std.range;

        assert(RecorderChain.getBlockFilenames(temp_folder).empty);
    }

    auto block_factory = RecorderChainBlockFactory(net);
    auto block0 = block_factory(empty_recorder, [], empty_bullseye);

    /// RecorderChain_single_block
    {
        recorder_chain.push(block0);

        assert(recorder_chain.getAmount == 1);
        assert(recorder_chain.getFirstBlock is block0);
        assert(recorder_chain.getLastBlock is block0);
    }

    auto block1 = block_factory(empty_recorder, block0.fingerprint, empty_bullseye);
    auto block2 = block_factory(empty_recorder, block1.fingerprint, empty_bullseye);

    /// RecorderChain_many_blocks
    {
        recorder_chain.push(block1);
        recorder_chain.push(block2);

        assert(recorder_chain.getAmount == 3);
        assert(recorder_chain.getFirstBlock is block0);
        assert(recorder_chain.getLastBlock is block2);
    }

    /// RecorderChain_static_getBlocksInfo
    {
        auto info = RecorderChain.getBlocksInfo(temp_folder, net);

        assert(info.amount == 3);
        assert(info.first.toDoc.serialize == block0.toDoc.serialize);
        assert(info.last.toDoc.serialize == block2.toDoc.serialize);
    }

    /// RecorderChain_getBlockFilenames_non_empty
    {
        auto block_filenames = RecorderChain.getBlockFilenames(temp_folder);
        assert(block_filenames.length == 3);
        foreach (filename; block_filenames)
        {
            assert(filename.extension == FileExtension.recchainblock.withDot);
        }
    }

    // // TODO: add argument for selecting folder
    // auto folder_path = options.recorder.folder_path;
    // string dartfilename = folder_path ~ "DummyDART";
    // ushort fromAngle = 0;
    // ushort toAngle = 1;
    // string passphrase = "verysecret";
    // SecureNet net = new StdSecureNet;
    // net.generateKeyPair(passphrase);
    // auto hirpc = HiRPC(net);

    // int onHelp()
    // {
    //     defaultGetoptPrinter(
    //         [
    //         "Documentation: https://tagion.org/",
    //         "",
    //         "Usage:",
    //         format("%s <command> [<option>...]\n", EXEC_NAME),
    //         "Where:",
    //         "<command> one of [--init, --print, --rollback]\n",
    //         "<options>:"
    //     ].join("\n"),
    //     cli_args_config.options
    //     );
    //     return 0;
    // }

    // void onInit()
    // {
    //     if (!exists(folder_path))
    //         mkdirRecurse(folder_path);

    //     enum BLOCK_SIZE = 0x80;
    //     BlockFile.create(dartfilename, DARTFile.stringof, BLOCK_SIZE);

    //     DART db = new DART(net, dartfilename, fromAngle, toAngle);

    //     // Create dummy Recorder
    //     HiBON hibon = new HiBON;
    //     hibon["not_empty_db?"] = "NO:)";

    //     immutable hashnet = new StdHashNet;
    //     auto recordFactory = RecordFactory(hashnet);
    //     auto rec = recordFactory.recorder;
    //     rec.add(Document(hibon));
    //     immutable rec_im = cast(immutable) rec;

    //     // Spawn recorder task
    //     auto recorderService = Task!RecorderTask(options.recorder.task_name, options);
    //     receiveOnly!Control;
    //     scope (exit)
    //     {
    //         recorderService.control(Control.STOP);
    //         receiveOnly!Control;
    //     }

    //     addDummyRecordToDB(db, rec_im, hirpc);
    //     recorderService.receiveRecorder(rec_im, Fingerprint(db.fingerprint));
    //     writeln;
    //     writeln("db\n", db.fingerprint);
    //     writeln("bl\n", RecorderChain.getBlocksInfo(folder_path).last.bullseye);
    //     writeln;

    //     // Send recorder to service
    //     foreach (i; 0 .. init_count)
    //     {
    //         //auto recorder = initDummyRecorderAdd(cast(int) i, to!string(i));
    //         addDummyRecordToDB(db, recorder, hirpc);
    //         recorderService.receiveRecorder(recorder, Fingerprint(db.fingerprint));

    //         writeln;
    //         writeln("-db\n", db.fingerprint);
    //         writeln("-bl\n", RecorderChain.getBlocksInfo(folder_path).last.bullseye);
    //         writeln;
    //     }

    //     writeln(format("Initialized %d dummy records in '%s'", init_count, folder_path));
    // }

    // void onPrint()
    // {
    //     auto blocks_info = RecorderChain.getBlocksInfo(folder_path);

    //     Buffer fingerprint = blocks_info.last.fingerprint;
    //     foreach (j; 0 .. blocks_info.amount)
    //     {
    //         const current_block = RecorderChain.readBlock(fingerprint, folder_path, net);

    //         writeln(format(">> %s block start", blocks_info.amount - j));

    //         writefln("Fingerprint:\n%X", Fingerprint(current_block.fingerprint));
    //         const bullseye = current_block.bullseye;
    //         if (bullseye.empty)
    //             writeln("Bullseye: <empty>");
    //         else
    //             writefln("Bullseye:\n%X", Fingerprint(bullseye));

    //         writeln(format("<< %s block end\n", blocks_info.amount - j));

    //         fingerprint = current_block.chain;
    //     }
    // }

    // void onRollback()
    // {
    //     auto blocks_info = RecorderChain.getBlocksInfo(folder_path);
    //     if (rollback > blocks_info.amount)
    //     {
    //         writeln(format("Rollback count (%d) is greater than number of blocks (%d)", rollback, blocks_info
    //                 .amount));
    //         rollback = blocks_info.amount;
    //     }

    //     writeln("Rollback for ", rollback, " steps\n");

    //     if (!exists(folder_path))
    //     {
    //         writeln(format("File '%s' don't exist, failed to rollback. Abort"));
    //     }

    //     DART db = new DART(net, dartfilename, fromAngle, toAngle);

    //     Buffer fingerprint = blocks_info.last.fingerprint;
    //     foreach (j; 0 .. rollback)
    //     {
    //         writefln("Current rollback: %d", rollback - j);

    //         const current_block = RecorderChain.readBlock(fingerprint, folder_path, net);

    //         writeln("Current block bullseye:\n%X", Fingerprint(current_block.bullseye));
    //         writeln("DB fingerprint:\n%X", Fingerprint(db.fingerprint));

    //         // Add flipped recorder to DB
    //         // addDummyRecordToDB(db, RecorderChain.getFlippedRecorder(current_block), hirpc);
    //         // Remove local file with this block
    //         RecorderChain.makePath(fingerprint, folder_path).remove;

    //         fingerprint = current_block.chain;
    //     }
    // }

    // try
    // {
    //     // Calling --help or -h
    //     if (cli_args_config.helpWanted)
    //         return onHelp;

    //     // Should be the first action
    //     if (init_count > 0)
    //         onInit;

    //     if (print)
    //         onPrint;

    //     if (rollback > 0)
    //         onRollback;

    //     // Last action in work
    //     if (clean)
    //     {
    //         if (exists(folder_path))
    //         {
    //             rmdirRecurse(folder_path);
    //             writeln(format("Cleaned files in '%s'", folder_path));
    //         }
    //         else
    //         {
    //             writeln(format("Folder '%s' is already empty", folder_path));
    //         }
    //     }
    // }
    // catch (Exception e)
    // {
    //     // Might be:
    //     // std.getopt.GetOptException for unrecoginzed option
    //     // std.conv.ConvException for unexpected values for option recognized
    //     writeln(e);
    //     return 1;
    // }
    return 0;
}

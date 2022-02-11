module tagion.logservicetest;

pragma(msg, "Fixme(cbr): Rename the tagion Node to Prime");

int loggerServiceTest(string[] args) {
    import std.stdio;
    import core.thread;
    import std.getopt;
    import std.format;
    import std.concurrency;
    import std.array : join;

    import tagion.basic.Basic : Control;
    import tagion.logger.Logger;
    import tagion.services.Options : Options, setDefaultOption;
    import tagion.options.CommonOptions : setCommonOptions;
    import tagion.services.LoggerService : loggerTask;

    enum main_task="tagionlogservicetest";

    Options service_options;
    setDefaultOption(service_options);

    auto logger_tid=spawn(&loggerTask, service_options);
    scope(exit){
        logger_tid.send(Control.STOP);
        auto respond_control = receiveOnly!Control;
    }
 
    import std.stdio : stderr;
    stderr.writeln("Waiting for logger");

    const response=receiveOnly!Control;
    stderr.writeln("Logger started");
    if ( response !is Control.LIVE ) {
        stderr.writeln("ERROR:Logger %s", response);
    }

    log.register(main_task);

    import core.thread;
    int counter = 0;
    while(true) {
        if (counter == 5) {
            logger_tid.send(Control.STOP);
        }

        switch(counter%3) {
            case 0:
                log.error(format("My custom error {%d}", counter));
                break;
            case 1:
                log.warning(format("My custom warning {%d}", counter));
                break;
            default:
                log.trace(format("My custom trace {%d}", counter));
        }

        writeln("--------");
        ++counter;
        Thread.sleep(3.seconds);
    }

    return 0;
}

// // service that receives and saves recored
// // bin that can revert 1 step db
// // cli 2 func: revert, replay

int recorderCliTest(string[] args) {
    import std.path;
    import std.getopt;
    import std.stdio;
    import std.file : exists;
    import std.format;
    import std.conv : to;
    import std.array;
    import std.concurrency;
    import tagion.utils.Miscellaneous;
    import tagion.utils.Gene;
    import tagion.services.Options : Options, setDefaultOption;
    import tagion.services.LoggerService : loggerTask;
    import tagion.basic.Basic : Control;

    // Default inits for cli
    uint rollback = 0;
    // bool version_switch = false;
    bool dump = false;
    bool init = false;
    ushort fromAngle = 0;
    ushort toAngle = 1;

    const auto EXEC_NAME = baseName(args[0]);

    if (args.length == 1) {
        writeln("Error: No arguments provided for ", EXEC_NAME,"!");
        return 1;
    }

    Options options;
    setDefaultOption(options);
    
    // auto logger_tid=spawn(&loggerTask, options);
    // scope(exit){
    //     logger_tid.send(Control.STOP);
    //     auto respond_control = receiveOnly!Control;
    // }

    // TODO: import
    string dartfilename = "/tmp/default.drt";

    auto cliArgsConfig = getopt(
        args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        // Explicitly declare noPassThrough for considering command argument as error
        // std.getopt.config.noPassThrough,
        "init|i", "Init db for tests", &init,
        "rollback|r", "Rollback database on n steps backward", &rollback,
        "dump|d", "Make a dump of current database's state", &dump,
        // "version", "display the version", &version_switch,
        // "pathToBlocks|p", "Path to blocks", &file_for_blocks,
        // "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase,
        //"dartfilename|dart", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
        // "from", format("Sets from angle: default %s", (fromAngle == toAngle) ? "full" : fromAngle.to!string), &fromAngle,
        // "to", format("Sets to angle: default %s", (fromAngle == toAngle) ? "full" : toAngle.to!string), &toAngle,
    );

    // /*
    // 1. rollback
    // [] > [] > [] > [*]
    //       ^ > remove
    // 2. generate 5
    // * > [] > [] > []
    // ^ > generate dummy recorders
    // 3. separete service: spawn(&service)
    //  (immutable(Recorder), fingerprint) > service
    // */

    int onHelp() {
        defaultGetoptPrinter(
            [
            //format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s <command> [<option>...]\n", EXEC_NAME),
            "Where:",
            "<command> one of [--init, --dump, --rollback]\n",
            "<options>:"].join("\n"),
            cliArgsConfig.options
        );
        return 0;
    }

    void onInit() {
        writeln("--init");
        // if (dartfilename.length == 0) {
        //     dartfilename = tempfile ~ "tmp";
        //     writeln("DART filename: ", dartfilename);
        // }

        // enum BLOCK_SIZE = 0x80;
        // BlockFile.create(dartfilename, DARTFile.stringof, BLOCK_SIZE);


        import tagion.dart.Recorder : RecordFactory;  
        import tagion.crypto.SecureNet : StdHashNet;
        import tagion.services.RecorderService : recorderTask;

        auto recorder_service_tid=spawn(&recorderTask, options);
        scope(exit){
            recorder_service_tid.send(Control.STOP);
            writeln("exit bin init; control=", receiveOnly!Control);
        }
        
        const net = new StdHashNet;
        auto factory = RecordFactory(net);
        RecordFactory.Recorder recorder = factory.recorder;

        string filename = "filename";

        import core.thread;
        while(true) {
            recorder_service_tid.send("aaa   bbb   ccc", filename);
            writeln("while sleep 5 seconds...");
            filename ~= "_a";
            Thread.sleep(5.seconds);
        }
    }

    void onDump() {
        writeln("--dump");
        // writefln("Dump called: \n", db_.fingerprint);
        // db_.dump();
    }

    void onRollback() {
        writeln("--rollback");
        //     writeln("rollback called for ", rollback, " steps\n");
        //     while(rollback > 0)
        //     {
        //         writefln("Current rollback: %d", rollback);
        //         auto flip_rec = blocks_.rollBack();
        //         db_.modify(flip_rec._recorder);
        //         if(dump)
        //         {
        //             writefln("Rollback on %d step: %s", rollback, "dummy.db");//db.fingerprint);
        //         }
        //         rollback --;
        //     }
    }

    try
    {
        // Calling --help or -h
        if (cliArgsConfig.helpWanted) {
            return onHelp;
        }

        // Calling --init | -i
        if (init) {
            onInit;
        }

        // Calling --dump | -d
        if (dump) {
            onDump;
        }

        // Calling --rollback \ -r
        if (rollback > 0) {
            onRollback;
        }
    }
    catch(Exception e)
    {
        // Might be:
        // std.getopt.GetOptException for unrecoginzed option
        // std.conv.ConvException for unexpected values for option recognized
        writeln(e);
    }
    return 0;
}

int main(string[] args) {
    //return loggerServiceTest(args);
    return recorderCliTest(args);
}
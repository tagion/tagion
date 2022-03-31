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

    enum main_task = "tagionlogservicetest";

    Options service_options;
    setDefaultOption(service_options);

    auto logger_tid = spawn(&loggerTask, service_options);
    scope (exit) {
        logger_tid.send(Control.STOP);
        auto respond_control = receiveOnly!Control;
    }

    import std.stdio : stderr;

    stderr.writeln("Waiting for logger");

    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE) {
        stderr.writeln("ERROR:Logger %s", response);
    }

    log.register(main_task);

    import core.thread;

    int counter = 0;
    while (true) {
        if (counter == 5) {
            logger_tid.send(Control.STOP);
        }

        switch (counter % 3) {
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

import std.path;
import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.conv : to;
import std.array;
import tagion.utils.Miscellaneous;
import tagion.utils.Gene;
import tagion.services.Options : Options, setDefaultOption;
import tagion.services.LoggerService : loggerTask;
import tagion.services.RecorderService;
import tagion.basic.Basic : Control, Buffer, TrustedConcurrency;
import tagion.dart.DART : DART;
import tagion.dart.Recorder : RecordFactory;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet, StdHashNet;
import tagion.dart.BlockFile;
import tagion.hibon.Document;
import tagion.dart.DARTFile;

void addRecToDB(ref DART db, immutable(RecordFactory.Recorder) rec, HiRPC hirpc) {
    writeln("addRecToDB run...");
    const sent = hirpc.dartModify(rec);
    const received = hirpc.receive(sent.toDoc);
    const result = db(received, false);
}

immutable(RecordFactory.Recorder) testFlipRecorderAdd() {
    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto rec = factory.recorder;

    HiBON[10] HIB;

    foreach (i; 0 .. HIB.length) {
        HIB[i] = new HiBON;
    }

    for (int i = 0; i < HIB.length; i++) {
        HIB[i]["test1"] = i * 35 - 46;
        HIB[i]["test2"] = i * 35 - 45;
        HIB[i]["test3"] = i * 35 - 44;
        HIB[i]["test4"] = i * 35 - 43;
        HIB[i]["test5"] = i * 35 - 42;
        HIB[i]["test6"] = i * 35 - 41;
        HIB[i]["test7"] = i * 35 - 40;
        HIB[i]["test8"] = i * 35 - 39;
        HIB[i]["test9"] = i * 35 - 38;
        HIB[i]["test10"] = i * 35 - 37;
    }

    foreach (i; 0 .. HIB.length) {
        rec.add(Document(HIB[i]));
    }

    immutable(RecordFactory.Recorder) rec_im = cast(immutable(RecordFactory.Recorder)) rec;
    return rec_im;
}

immutable(RecordFactory.Recorder) testFlipRecorderDel() {

    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto rec = factory.recorder;

    HiBON[5] HIB;

    foreach (i; 0 .. HIB.length) {
        HIB[i] = new HiBON;
    }

    for (int i = 0; i < HIB.length; i++) {
        HIB[i]["test1"] = i * 35 - 46;
        HIB[i]["test2"] = i * 35 - 45;
        HIB[i]["test3"] = i * 35 - 44;
        HIB[i]["test4"] = i * 35 - 43;
        HIB[i]["test5"] = i * 35 - 42;
        HIB[i]["test6"] = i * 35 - 41;
        HIB[i]["test7"] = i * 35 - 40;
        HIB[i]["test8"] = i * 35 - 39;
        HIB[i]["test9"] = i * 35 - 38;
        HIB[i]["test10"] = i * 35 - 37;
    }

    foreach (i; 0 .. 5) {
        rec.remove(Document(HIB[i]));
    }

    HiBON toAdd = new HiBON;
    toAdd["add"] = "add";
    rec.add(Document(toAdd));

    immutable(RecordFactory.Recorder) rec_im = cast(immutable(RecordFactory.Recorder)) rec;
    return rec_im;
}

immutable(RecordFactory.Recorder) testNewRecorder() {
    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto rec = factory.recorder;

    HiBON[3] H;

    foreach (i; 0 .. H.length) {
        H[i] = new HiBON;
    }

    for (int i = 0; i < H.length; i++) {
        H[i]["Otest1"] = i * 350 - 46;
        H[i]["Otest2"] = i * 350 - 45;
        H[i]["Otest3"] = i * 350 - 44;
        H[i]["Otest4"] = i * 350 - 43;
        H[i]["Otest5"] = i * 350 - 42;
        H[i]["Otest6"] = i * 350 - 41;
        H[i]["Otest7"] = i * 350 - 40;
        H[i]["Otest8"] = i * 350 - 39;
        H[i]["Otest9"] = i * 350 - 38;
        H[i]["Otest10"] = i * 350 - 37;
    }

    foreach (i; 0 .. 3) {
        rec.add(Document(H[i]));
    }

    immutable(RecordFactory.Recorder) rec_im = cast(immutable(RecordFactory.Recorder)) rec;
    return rec_im;
}

mixin TrustedConcurrency;

int recorderCliTest(string[] args) {

    const auto EXEC_NAME = baseName(args[0]);

    if (args.length == 1) {
        writeln("Error: No arguments provided for ", EXEC_NAME, "!");
        return 1;
    }

    Options options;
    setDefaultOption(options);

    // ===================================================================================

    // Dummy inits
    string passphrase = "verysecret";
    string file_for_blocks = options.recorder.folder_path;
    string dartfilename = file_for_blocks ~ "A";

    // Default inits for cli
    uint rollback = 0;
    // bool version_switch = false;
    bool dump = false;
    bool init = false;
    ushort fromAngle = 0;
    ushort toAngle = 1;

    alias BlocksDB = EpochBlockFileDataBase;
    auto blocks_ = new BlocksDB(file_for_blocks);

    SecureNet net_;
    net_ = new StdSecureNet;
    net_.generateKeyPair(passphrase);
    auto hirpc_ = HiRPC(net_);
    enum BLOCK_SIZE = 0x80;
    BlockFile.create(dartfilename, DARTFile.stringof, BLOCK_SIZE);

    DART db_ = new DART(net_, dartfilename, fromAngle, toAngle);
    immutable(StdHashNet) hashnet_ = new StdHashNet;
    Buffer noHash = null;
    auto epBlockFactory = EpochBlockFactory(hashnet_);

    HiBON hibon_ = new HiBON;
    hibon_["not_empty_db?"] = "NO:)";
    auto recordFactory = RecordFactory(hashnet_);
    auto rec = recordFactory.recorder;
    rec.add(Document(hibon_));
    immutable(RecordFactory.Recorder) rec_im = cast(immutable) rec;

    // ==================================================================================
    addRecToDB(db_, rec_im, hirpc_);

    writeln("1 step: ", db_.fingerprint.cutHex); //for test

    auto rec1 = testFlipRecorderAdd; //create recorder
    auto block1 = epBlockFactory(rec_im, noHash, db_.fingerprint); //create block
    writeln("2 step BEFORE: ", db_.fingerprint.cutHex, " (add 1-st -> ", block1.bullseye.cutHex, ")");
    blocks_.addBlock(block1); //save block
    addRecToDB(db_, block1.recorder, hirpc_); //add to DB

    writeln("2 step: ", db_.fingerprint.cutHex, " (add 1-st -> ", block1.bullseye.cutHex, ")");

    auto rec2 = testFlipRecorderDel;
    auto block2 = epBlockFactory(rec_im, block1.fingerprint, db_.fingerprint);
    writeln("3 step BEFORE: ", db_.fingerprint.cutHex, " (add 2-nd -> ", block2.bullseye.cutHex, ")");
    blocks_.addBlock(block2);
    addRecToDB(db_, block2.recorder, hirpc_);

    writeln("3 step: ", db_.fingerprint.cutHex, " (add 2-nd -> ", block2.bullseye.cutHex, ")");

    auto rec3 = testNewRecorder;
    auto block3 = epBlockFactory(rec_im, block2.fingerprint, db_.fingerprint);
    writeln("4 step BEFORE: ", db_.fingerprint.cutHex, " (add 3-rd -> ", block3.bullseye.cutHex, ")");
    blocks_.addBlock(block3);
    addRecToDB(db_, block3.recorder, hirpc_);

    writeln("4 step: ", db_.fingerprint.cutHex, " (add 3-rd -> ", block3.bullseye.cutHex, ")");

    addRecToDB(db_, BlocksDB.getFlippedRecorder(block3), hirpc_);

    writeln("5 step: ", db_.fingerprint.cutHex);

    //auto block_flip_1 = blocks.rollBack();
    addRecToDB(db_, BlocksDB.getFlippedRecorder(block2), hirpc_);

    writeln("6 step: ", db_.fingerprint.cutHex);

    //auto block_flip_2 = blocks.rollBack();
    addRecToDB(db_, BlocksDB.getFlippedRecorder(block1), hirpc_);

    writeln("7 step: ", db_.fingerprint.cutHex);
    // ===================================================================================

    // auto logger_tid=spawn(&loggerTask, options);
    // scope(exit){
    //     logger_tid.send(Control.STOP);
    //     auto respond_control = receiveOnly!Control;
    // }

    auto cliArgsConfig = getopt(
            args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling, // Explicitly declare noPassThrough for considering command argument as error
            // std.getopt.config.noPassThrough,
            "init|i", "Init db for tests", &init,
            "rollback|r", "Rollback database on n steps backward", &rollback,
            "dump|d", "Make a dump of current database's state", &dump, // "version", "display the version", &version_switch,
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
            "<options>:"
        ].join("\n"),
        cliArgsConfig.options
        );
        return 0;
    }

    void onInit() {
        writeln("--init");
    }

    void onDump() {
        writefln("Dump called: \n", db_.fingerprint);
    }

    void onRollback() {
        writeln("rollback called for ", rollback, " steps\n");
        while (rollback > 0) {
            writefln("Current rollback: %d", rollback);
            //const flip_rec = blocks_.rollBack();

            // function `tagion.dart.DARTFile.DARTFile.modify(Recorder modify_records)`
            // is not callable using argument types `(immutable(EpochBlock))`
            // db.modify(flip_rec);
            if (dump) {
                writefln("Rollback on %d step: %s", rollback, "dummy.db"); //db.fingerprint);
            }
            rollback--;
        }
    }

    try {
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
    catch (Exception e) {
        // Might be:
        // std.getopt.GetOptException for unrecoginzed option
        // std.conv.ConvException for unexpected values for option recognized
        writeln(e);
    }
    return 0;
}

int logSubscriptionTest(string[] args) {
    import std.algorithm;
    import std.getopt;
    import std.stdio;
    import core.thread;
    import std.getopt;
    import std.concurrency;
    import std.stdio;
    import std.format;
    import std.socket : InternetAddress, AddressFamily;

    import tagion.hibon.Document : Document;
    import tagion.network.SSLSocket;
    import tagion.services.Options;
    import tagion.options.CommonOptions : setCommonOptions;
    import tagion.services.LogSubscriptionService;
    import tagion.basic.Basic : Control, Buffer;

    import tagion.communication.HiRPC;

    import core.thread;

    //import tagion.script.StandardRecords;
    import std.array : join;
    import tagion.logger.Logger : LoggerType;
    import tagion.services.Options : Options, setDefaultOption;
    import tagion.options.CommonOptions : setCommonOptions;
    import tagion.services.LoggerService : loggerTask, LogFilter;
    import tagion.utils.Miscellaneous;
    import tagion.utils.Gene;


    /** \struct ClientOprions
    *  Client options used to set up socket connection
    */
    struct ClientOprions {
        string addr; /// @brief client's addres
        ushort port; /// @brief client's port

        /// set default values for ClientOptions fields
        void setDefault() {
            addr = "127.0.0.1";
            port = 10700;
        }
    }

    /** 
    * \brief Struct myStruct dskfsl;df
    */
    struct MyStruct {
        /** To read something
        */
        void read() {}
    }

    writefln("args=%s", args);

    ushort port;
    string task_name;
    LoggerType log_info;

    getopt(args,
        std.getopt.config.caseSensitive,
        "port", &port,
        "task_name", &task_name,
        "log_info", &log_info);

    /// \link LogFilter
    LogFilter filter = LogFilter(task_name, log_info);

    /// @see Options
    Options service_options;
    service_options.setDefaultOption;
    service_options.logSubscription.service.port = port;
    // Set the shared common options for all services
    setCommonOptions(service_options.common);

    auto logger_tid = spawn(&loggerTask, service_options);

    scope(exit){
        logger_tid.send(Control.STOP);
        auto respond_control = receiveOnly!Control;
    }

    import std.stdio : stderr;

    const response=receiveOnly!Control;
    stderr.flush();
    std.stdio.stdout.flush();
    if ( response !is Control.LIVE ) {
        stderr.writeln("ERROR:Logger %s", response);
    }

    /// \link logSubscriptionServiceTask
    auto log_subscription_tid = spawn(&logSubscriptionServiceTask, service_options);

    scope(exit) {
        log_subscription_tid.send(Control.STOP);
        auto respond_control = receiveOnly!Control;
    }
    assert(receiveOnly!Control == Control.LIVE);
    ClientOprions options;
    options.setDefault();
    Thread.sleep(5.seconds);

    /// @see SSLSocket
    auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
    client.connect(new InternetAddress(options.addr, port));

    scope (exit) {
        client.close;
    }

    /// @see HiRPC
    HiRPC hirpc; 
    const sender = hirpc.action("test", filter.toDoc);
    immutable data = sender.toDoc.serialize;
    writeln(data);
    client.send(data);
    ptrdiff_t rec_size;
    auto rec_buf = new byte[4000];

    do {
        do {
            rec_size = client.receive(rec_buf); //, current_max_size);
            string reply = cast(string)rec_buf.idup;
            writeln(reply);
            Thread.sleep(400.msecs);
        }
        while (rec_size < 0);
    }
    while (client.isAlive());

    return 0;
}

int main(string[] args) {
    //return loggerServiceTest(args);
    return recorderCliTest(args);
    //return logSubscriptionTest(args);
}

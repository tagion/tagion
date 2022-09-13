module tagion.logservicetest;

import core.thread;
import std.path;
import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.conv : to;
import std.array;
import tagion.utils.Miscellaneous;
import tagion.utils.Gene;
import tagion.services.Options;
import tagion.services.LoggerService;
import tagion.services.RecorderService;
import tagion.services.LogSubscriptionService;
import tagion.basic.Basic : TrustedConcurrency;
import tagion.basic.Types : Control, Buffer;
import tagion.dart.DART : DART;
import tagion.dart.Recorder : RecordFactory;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet, StdHashNet;
import tagion.dart.BlockFile;
import tagion.hibon.Document;
import tagion.dart.DARTFile;
import tagion.tasks.TaskWrapper;
import tagion.logger.Logger;
import tagion.logger.LogRecords;
import tagion.network.SSLOptions;
import tagion.network.SSLSocket;
import std.socket : InternetAddress, AddressFamily, SocketOSException;
import tagion.options.CommonOptions : setCommonOptions;
import tagion.hibon.HiBONJSON;

mixin TrustedConcurrency;

void sendingLoop()
{
    import core.thread;
    import std.stdio;

    writeln("I'm alive!");
    log.register("sendingLoop");
    writeln("Wait...");
    Thread.sleep(3000.msecs);

    log("---------------------- Test logs from sendingLoop ----------------------");

    import tagion.hibon.HiBONRecord;

    static struct S
    {
        int x;
        mixin HiBONRecord!(
            q{this(int x) {this.x = x;}}
        );
    }

    const test_variable = S(10);
    mixin Log!test_variable;
}

void create_ssl(const(OpenSSL) openssl)
{
    import std.algorithm.iteration : each;
    import std.file : exists, mkdirRecurse;
    import std.process : pipeProcess, wait, Redirect;
    import std.array : array;
    import std.path : dirName;

    writeln(openssl.certificate.exists, openssl.private_key.exists);

    if (!openssl.certificate.exists || !openssl.private_key.exists)
    {
        writeln(openssl.certificate.dirName);
        openssl.certificate.dirName.mkdirRecurse;
        openssl.private_key.dirName.mkdirRecurse;
        auto pipes = pipeProcess(openssl.command.array);
        scope (exit)
        {
            wait(pipes.pid);
        }
        openssl.config.each!(a => pipes.stdin.writeln(a));
        pipes.stdin.writeln(".");
        pipes.stdin.flush;
        foreach (s; pipes.stderr.byLine)
        {
            stderr.writeln(s);
        }
        foreach (s; pipes.stdout.byLine)
        {
            writeln(s);
        }
        assert(openssl.certificate.exists && openssl.private_key.exists);
    }
}

import tagion.tools.Basic;

mixin Main!(_main, "logsub");

int _main(string[] args)
{
    scope Options local_options;
    import std.getopt;

    setDefaultOption(local_options);

    auto config_file = "tagionwave.json";

    local_options.load(config_file);
    setOptions(local_options);
    main_task = "logservicetest";

    immutable service_options = getOptions();
    // Set the shared common options for all services
    setCommonOptions(service_options.common);
    writeln("LogSubService: certificate", service_options.logSubscription
            .service.openssl.certificate);
    writeln("LogSubService: private_key", service_options.logSubscription
            .service.openssl.private_key);

    /// starting Logger task
    auto logger_service = Task!LoggerTask(service_options.logger.task_name, service_options);
    import std.stdio : stderr;

    stderr.writeln("Waiting for logger");
    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE)
    {
        stderr.writeln("ERROR:Logger %s", response);
        return -1;
    }
    scope (exit)
    {
        logger_service.control(Control.STOP);
        receiveOnly!Control;
    }
    log.register(main_task);

    create_ssl(service_options.logSubscription.service.openssl);

    writeln("Creating SSLSocket");
    Thread.sleep(1.seconds);
    auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
    scope (exit)
    {
        client.close;
    }
    try
    {
        writeln("Trying to connect socket");
        writeln("Addres ", service_options.logSubscription.service.address);
        writeln("Port ", service_options.logSubscription.service.port);
        client.connect(new InternetAddress(service_options.logSubscription
                .service.address, service_options.logSubscription
                .service.port));
    }
    catch (SocketOSException e)
    {
        writeln("Log subscription failed: ", e.msg);
        return 1;
    }
    HiRPC hirpc;
    client.blocking = true;

    auto filter = LogFilter("sendingLoop", "test_variable");
    const sender = hirpc.action("subscription", filter.toHiBON);
    immutable data = sender.toDoc.serialize;
    writeln(sender.toDoc.toJSON);
    client.send(data);

    auto rec_buf = new void[4000];
    ptrdiff_t rec_size;

    spawn(&sendingLoop);

    do
    {
        rec_size = client.receive(rec_buf); //, current_max_size);
        writefln("read rec_size=%d", rec_size);
        Thread.sleep(1000.msecs);
    }
    while (rec_size < 0);
    auto resp_doc = Document(cast(Buffer) rec_buf[0 .. rec_size]);
    writefln("Response document toJSON: %s", resp_doc.toPretty);

    return 0;
}

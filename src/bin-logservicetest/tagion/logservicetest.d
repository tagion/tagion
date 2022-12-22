module tagion.logservicetest;

import std.format : format;
import std.socket : InternetAddress, AddressFamily, SocketOSException;
import std.stdio : writeln, writefln, stderr;
import core.thread : Thread, seconds;

import tagion.basic.Basic : TrustedConcurrency;
import tagion.basic.Types : Control, Buffer;
import tagion.communication.HiRPC : HiRPC;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONJSON : toJSON, toPretty;
import tagion.hibon.HiBONRecord : HiBONRecord, RecordType;
import tagion.logger.Logger : log, LogLevel, Log;
import tagion.logger.LogRecords : LogFilter;
import tagion.network.SSLServiceOptions : configureSSLCert;
import tagion.network.SSLSocket : SSLSocket, EndpointType;
import tagion.options.CommonOptions : setCommonOptions;
import tagion.services.LoggerService : LoggerTask;
import tagion.services.Options : Options, setDefaultOption, setOptions, getOptions;
import tagion.tasks.TaskWrapper : Task;
import tagion.tools.Basic : Main;

mixin TrustedConcurrency;

private void sendingLoop() {
    writeln("I'm alive!");
    log.register("sendingLoop");
    writeln("Wait...");
    Thread.sleep(3.seconds);

    log("Test logs from sendingLoop");

    static struct S {
        int x;
        mixin HiBONRecord!(
                q{this(int x) {this.x = x;}}
        );
    }

    const test_variable = S(10);
    mixin Log!test_variable;
}

mixin Main!(_main, "logsub");

int _main(string[] args) {
    scope Options local_options;

    setDefaultOption(local_options);

    auto config_file = "tagionwave.json";

    local_options.load(config_file);
    setOptions(local_options);
    enum main_task = "logservicetest";

    immutable service_options = getOptions();
    // Set the shared common options for all services
    setCommonOptions(service_options.common);
    writeln("LogSubService: certificate", service_options.logsubscription
            .service.cert.certificate);
    writeln("LogSubService: private_key", service_options.logsubscription
            .service.cert.private_key);

    /// starting Logger task
    auto logger_service = Task!LoggerTask(service_options.logger.task_name, service_options);

    stderr.writeln("Waiting for logger");
    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE) {
        stderr.writeln("ERROR:Logger %s", response);
        return -1;
    }
    scope (exit) {
        logger_service.control(Control.STOP);
        receiveOnly!Control;
    }
    log.register(main_task);

    configureSSLCert(service_options.logsubscription.service.cert);

    writeln("Creating SSLSocket");
    Thread.sleep(1.seconds);
    auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
    scope (exit) {
        client.close;
    }
    try {
        writeln("Trying to connect socket");
        writeln("Addres ", service_options.logsubscription.service.server.address);
        writeln("Port ", service_options.logsubscription.service.server.port);
        client.connect(new InternetAddress(service_options.logsubscription
                .service.server.address, service_options.logsubscription
                .service.server.port));
    }
    catch (SocketOSException e) {
        writeln("Log subscription failed: ", e.msg);
        return 1;
    }
    HiRPC hirpc;
    client.blocking = true;

    auto hibon_filters = new HiBON;
    hibon_filters[0] = LogFilter("sendingLoop", "test_variable");
    hibon_filters[1] = LogFilter("sendingLoop", LogLevel.INFO);

    const sender = hirpc.action("subscription", hibon_filters);
    immutable data = sender.toDoc.serialize;
    writeln(sender.toDoc.toJSON);
    client.send(data);

    auto rec_buf = new void[4000];
    ptrdiff_t rec_size;

    spawn(&sendingLoop);

    do {
        rec_size = client.receive(rec_buf); //, current_max_size);
        writefln("read rec_size=%d", rec_size);
        Thread.sleep(1.seconds);
    }
    while (rec_size < 0);
    auto resp_doc = Document(cast(Buffer) rec_buf[0 .. rec_size]);
    writefln("Response document toJSON: %s", resp_doc.toPretty);

    return 0;
}


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
import tagion.services.LogSubscriptionService;

import core.thread;

//import tagion.script.StandardRecords;
import std.array : join;
import tagion.basic.Basic : Control;
import tagion.logger.Logger;
import tagion.services.Options : Options, setDefaultOption;
import tagion.options.CommonOptions : setCommonOptions;
import tagion.services.LoggerService : loggerTask;
import tagion.utils.Miscellaneous;
import tagion.utils.Gene;

struct ClientOprions {
    string addr;
    ushort port;
    void setDefault() {
        addr = "localhost";
        port = 10800;
    }
}

struct ClientSubscription {
    // ubyte[string] log_info;
    ubyte[] log_info;
    const(ClientOprions) options;

    this(ClientOprions optiong) {
        this.options = options;
    }
}

enum main_task="tagionlogger";


void loggerServiceTest() {
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
}

int v_foo(string[] args) {
    Options my_options;
    setDefaultOption(my_options);
    auto subscription_tid = spawn(&logSubscriptionServiceTask, my_options);

    auto respond_control = receiveOnly!Control;

    assert(respond_control == Control.LIVE);

    immutable program = args[0];

    ClientOprions options;
    options.setDefault();

    auto clinetSubscription = ClientSubscription(options);

    auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
    client.connect(new InternetAddress(clinetSubscription.options.addr, clinetSubscription.options.port));

    scope (exit) {
        client.close;
    }

    client.blocking = true;
    // writeln(cast(string) data.data);
    client.send(clinetSubscription.log_info);
    ptrdiff_t rec_size;
    auto rec_buf = new void[4000];

    do {
        do {
            rec_size = client.receive(rec_buf); //, current_max_size);
            Thread.sleep(400.msecs);
        }
        while (rec_size < 0);
        // writefln(rec_buf);
    }
    while (client.isAlive());

    return 0;
}

void main(string[] args) {
    loggerServiceTest;
    writeln("Program reached end");
}

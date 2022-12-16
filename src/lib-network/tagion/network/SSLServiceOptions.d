module tagion.network.SSLServiceOptions;

import std.algorithm.iteration : each;
import std.array : array;
import std.file : exists, mkdirRecurse;
import std.process : pipeProcess, wait;
import std.path : dirName;

//import std.stdio : stderr, writeln;
import std.outbuffer : OutBuffer;

import tagion.utils.JSONCommon;
import tagion.hibon.HiBONRecord;

struct SSLCert {
    string certificate; /// Certificate file name
    string private_key; /// Private key
    uint key_size; /// Key size (RSA 1024,2048,4096)
    uint days; /// Number of days the certificate is valid
    string country; /// Country Name two letters
    string state; /// State or Province Name (full name)
    string city; /// Locality Name (eg, city)
    string organisation; /// Organization Name (eg, company)
    string unit; /// Organizational Unit Name (eg, section)
    string name; /// Common Name (e.g. server FQDN or YOUR name)
    string email; /// Email Address
    import std.range : zip, repeat, only;
    import std.format;

    auto config() const pure nothrow @nogc {
        return only(
                country,
                state,
                city,
                organisation,
                name,
                email);
        //                "\n".repeat);

    }

    auto command() const pure {
        return only(
                "openssl",
                "req",
                "-newkey",
                format!"rsa:%d"(key_size),
                "-nodes",
                "-keyout",
                private_key,
                "-x509",
                "-days",
                days.to!string,
                "-out",
                certificate);
    }

    mixin JSONCommon;
}

struct SSLServiceOptions {
    ServerOptions server;
    SSLCert cert; ///
    mixin JSONCommon;
    mixin JSONConfig;
}

struct ServerOptions {
    //    string task_name; /// Task name of the SSLService used
    string response_task_name; /// Name of the respose task name (If this is not set the respose service is not started)
    string prefix;
    string address; /// Ip address
    ushort port; /// Port
    uint max_buffer_size; /// Max buffer size
    uint max_queue_length; /// Listener max. incomming connection req. queue length
    uint max_connections; /// Max simultanious connections for the scripting engine
    uint select_timeout; /// Select timeout in ms
    uint client_timeout; /// Client timeout
    mixin JSONCommon;
}

int configureSSLCert(const(SSLCert) openssl, OutBuffer bout = null) @trusted {
    int exit_code;
    if (!openssl.certificate.exists || !openssl.private_key.exists) {
        openssl.certificate.dirName.mkdirRecurse;
        openssl.private_key.dirName.mkdirRecurse;
        auto pipes = pipeProcess(openssl.command.array);
        scope (exit) {
            exit_code = wait(pipes.pid);
        }
        openssl.config.each!(a => pipes.stdin.writeln(a));
        pipes.stdin.writeln(".");
        pipes.stdin.flush;
        if (bout) {
            bout.writefln("stderr:");
            pipes.stderr.byLine.each!(s => bout.writefln(s));
            bout.writefln("stdout:");
            pipes.stdout.byLine.each!(s => bout.writefln(s));

        }
    }
    return exit_code;
}

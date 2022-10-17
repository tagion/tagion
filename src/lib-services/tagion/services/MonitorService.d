module tagion.services.MonitorService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.logger.Logger;
import tagion.services.Options : Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Types : Control, Pubkey;
import tagion.basic.Basic : basename;
import tagion.basic.TagionExceptions : TagionException;

import tagion.hibon.Document;
import tagion.network.ListenerSocket;
import tagion.basic.TagionExceptions;

//Create flat webserver start class function - create Backend class.
void monitorServiceTask(immutable(Options) opts) nothrow
{
    try
    {
        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }

        // Set thread global options
        setOptions(opts);
        immutable task_name = opts.monitor.task_name;
        log.register(task_name);

        log("SockectThread port=%d addresss=%s", opts.monitor.port, commonOptions.url);

        auto listener_socket = ListenerSocket(commonOptions.url,
            opts.monitor.port, opts.monitor.timeout, opts.monitor.task_name);
        auto listener_socket_thread = listener_socket.start;

        scope (exit)
        {
            log.trace("In exit of soc.port=%d th", opts.monitor.port);
            listener_socket.stop;

            version (none)
                if (listener_socket_thread !is null)
                {
                    listener_socket.stop;

                    log.trace("Kill listener socket. %d", opts.monitor.port);
                    //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.

                    auto ping = new TcpSocket(new InternetAddress(opts.url, opts.monitor.port));

                    writefln("Pause for %d to close", opts.monitor.port);
                    Thread.sleep(500.msecs);

                    log.trace("Run listerner %s %s", listener_socket.active, opts.monitor.port);

                    writefln("Wait for %d to close", opts.monitor.port);
                    listener_socket_thread.join();

                    log.trace("Thread joined %d", opts.monitor.port);
                }
        }

        bool stop;
        void handleState(Control ts)
        {
            with (Control) switch (ts)
            {
            case STOP:
                log("Kill socket thread. %d", opts.monitor.port);

                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }

        void taskfailure(immutable(TaskFailure) t)
        {
            ownerTid.send(t);
        }

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receiveTimeout(500.msecs, //Control the thread
                &handleState, (string json) { listener_socket.broadcast(json); }, (
                    immutable(ubyte)[] hibon_bytes) {
                listener_socket.broadcast(hibon_bytes);
            }, (Document doc) { listener_socket.broadcast(doc); }, &taskfailure
            );
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}

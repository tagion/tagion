module tagion.services.TagionFactory;

import core.thread;
import std.concurrency;
import std.range : lockstep;
import std.conv;
import std.algorithm.searching : canFind;

import tagion.services.Options;

import tagion.utils.Random;

import tagion.GlobalSignals : abort;
import tagion.basic.Types : Pubkey, Control;
import tagion.logger.Logger;

//import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;
import tagion.gossip.AddressBook : addressbook;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.options.ServiceNames : get_node_name;
import tagion.basic.TagionExceptions;
import p2plib = p2p.node;
import tagion.services.DARTService;
import tagion.services.DARTSynchronizeService;
import tagion.dart.DARTSynchronization;
import tagion.dart.DART;

import tagion.services.TagionService;
import tagion.services.MdnsDiscoveryService;

//import tagion.Keywords : NetworkMode;

void tagionFactoryService(Options opts) nothrow
{
    try
    {
        scope (exit)
        {
            ownerTid.send(Control.END);
        }
        immutable tast_name = opts.heartbeat.task_name;
        log.register(tast_name);
        setOptions(opts);
        addressbook.number_of_active_nodes = opts.nodes;

        Tid[] tids;

        with (NetworkMode)
        {
            final switch (opts.net_mode)
            {
            case internal:
                //    if (opts.net_mode == NetworkMode.internal) {
                Options[] node_opts;
                log("in ineternal");
                import std.array : replace;
                import std.string : indexOf;
                import std.file : mkdir, exists;

                foreach (ushort i; 0 .. opts.nodes)
                {
                    pragma(msg, "foreach (i; 0 .. opts.nodes) ", typeof(i), "  ", typeof(opts.nodes));
                    string new_task_name(string task_name)
                    {
                        import std.format;

                        return format("%s%d", task_name, i);
                    }

                    short get_port(const short port) @trusted
                    {
                        return cast(ushort)(port + i);
                    }

                    const is_master_node = i == 0;
                    Options service_options = opts;

                    service_options.node_id = cast(uint) i;
                    auto local_port = get_port(opts.port_base);
                    service_options.dart.initialize = true;
                    if (is_master_node)
                    {
                        service_options.dart.initialize = opts.dart.initialize;
                        service_options.dart.synchronize = false;
                        service_options.discovery.notify_enabled = true;
                    }

                    service_options.port = local_port;
                    enum dir_token = "%dir%";
                    if (opts.dart.path.indexOf(dir_token) != -1)
                    {
                        auto path_to_dir = service_options.dart.path[0 .. opts.dart.path.indexOf(
                                dir_token)] ~ "node" ~ to!string(i);
                        if (!path_to_dir.exists)
                            path_to_dir.mkdir;
                        service_options.dart.path = opts.dart.path.replace(dir_token,
                            "node" ~ to!string(i));
                    }
                    else
                    {
                        import std.path;

                        if (!is_master_node)
                        {
                            pragma(msg, "fixme(): Use buildpath/path functions instead of string concat");
                            service_options.dart.path = stripExtension(
                                opts.dart.path) ~ to!string(i) ~ extension(opts.dart.path);
                        }
                    }
                    service_options.transcript.task_name = new_task_name(opts.transcript.task_name);
                    service_options.transaction.task_name = new_task_name(
                        opts.transaction.task_name);
                    service_options.transaction.service.task_name = new_task_name(
                        opts.transaction.service.task_name);
                    service_options.transaction.service.response_task_name
                        = new_task_name(
                            opts.transaction.service.response_task_name);
                    service_options.collector.task_name = new_task_name(opts.collector.task_name);
                    service_options.dart.task_name = new_task_name(opts.dart.task_name);
                    service_options.dart.sync.task_name = new_task_name(opts.dart.sync.task_name);
                    service_options.discovery.task_name = new_task_name(opts.discovery.task_name);
                    if ((opts.monitor.port >= opts.min_port) && ((opts.monitor.max == 0)
                            || (i < opts.monitor.max)))
                    {
                        service_options.monitor.port = get_port(opts.monitor.port);
                    }
                    // if ( (opts.transaction.port >= opts.min_port) && ((opts.transaction.max == 0) || (i < opts.transaction.max)) ) {
                    //     service_options.transaction.port=cast(ushort)(opts.transaction.port + i);
                    // }
                    if ((opts.transaction.service.port >= opts.min_port)
                        && ((opts.transaction.max == 0) || (i < opts.transaction.max)))
                    {
                        service_options.transaction.service.port =
                            get_port(
                                opts.transaction.service.port);
                    }
                    service_options.node_name = i.get_node_name;
                    node_opts ~= service_options;
                }
                log("options configurated");
                Pubkey[] pkeys;
                foreach (node_opt; node_opts)
                {

                    tids ~= spawn(&tagionService, NetworkMode.internal, node_opt);
                    pkeys ~= receiveOnly!(Pubkey);
                }

                foreach (ref tid; tids)
                {
                    foreach (pkey; pkeys)
                    {
                        tid.send(pkey);
                    }
                    assert(receiveOnly!Control == Control.LIVE);
                }
                break;
            case local:
                // }
                // else if (opts.net_mode == NetworkMode.local) {
                opts.node_name = "local-tagion";
                tids ~= spawn(&tagionService, opts.net_mode, opts);
                break;
            case pub:
                // }
                // else if (opts.net_mode == NetworkMode.pub) {
                opts.node_name = "public-tagion";
                tids ~= spawn(&tagionService, opts.net_mode, opts);
                break;
            }
        }
        scope (exit)
        {
            foreach (tid; tids)
            {
                tid.send(Control.STOP);
                assert(receiveOnly!Control is Control.END);
            }
        }

        void taskfailure(immutable(TaskFailure) t)
        {
            ownerTid.send(t);
            pragma(msg, "fixme(ib) check why we have an abort?");
            abort = true;
            log.silent = true;
        }

        bool stop;
        log("Start the heart beat");
        uint node_id;
        uint time = opts.delay;
        Random!uint rand;
        rand.seed(opts.seed);
        ownerTid.send(Control.LIVE);
        while (!stop && !abort)
        {
            //            Thread.sleep(opts.delay.msecs);
            immutable message_received = receiveTimeout(
                opts.delay.msecs,
                (Control ctrl) {
                with (Control)
                {
                    switch (ctrl)
                    {
                    case STOP:
                        stop = true;
                        break;
                    default:
                    }
                }
            },
                &taskfailure);
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}

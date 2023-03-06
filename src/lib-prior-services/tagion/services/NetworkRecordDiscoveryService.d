module tagion.services.NetworkRecordDiscoveryService;

import core.time;
import std.datetime;
import std.concurrency;
import std.format;

import tagion.services.Options;
import tagion.basic.Types : Buffer, Control;
import tagion.crypto.Types :   Pubkey;
import tagion.logger.Logger;
import tagion.utils.StdTime;

import p2plib = p2p.node;
import tagion.gossip.AddressBook : addressbook;
import tagion.communication.HiRPC;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.FileDiscoveryService;
import tagion.services.MdnsDiscoveryService;

import tagion.basic.TagionExceptions : fatal;
import tagion.crypto.SecureNet;

enum DiscoveryRequestCommand {
    BecomeOnline = 1,
    RequestTable = 2,
    BecomeOffline = 3,
    UpdateTable = 4 // on epoch
}

enum DiscoveryControl {
    READY = 1,
    ONLINE = 2,
    OFFLINE = 3
}

void networkRecordDiscoveryService(
        Pubkey pubkey,
        shared p2plib.Node p2pnode,
        string task_name,
        immutable(Options) opts) nothrow {
    try {

        scope (exit) {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);
        immutable inner_task_name = format("%s-%s", task_name, "internal");

        Tid bootstrap_tid;

        final switch (opts.net_mode) {
        case NetworkMode.internal: {
                bootstrap_tid = spawn(
                        &mdnsDiscoveryService,
                        pubkey,
                        p2pnode,
                        inner_task_name,
                        opts);
                break;
            }
        case NetworkMode.local: {
                bootstrap_tid = spawn(
                        &fileDiscoveryService,
                        pubkey,
                        p2pnode,
                        inner_task_name,
                        opts);
                break;
            }
        case NetworkMode.pub: {
                bootstrap_tid = spawn(
                        &serverFileDiscoveryService,
                        pubkey,
                        p2pnode,
                        inner_task_name,
                        opts);
                break;
            }
        }
        assert(receiveOnly!Control is Control.LIVE);
        scope (exit) {
            bootstrap_tid.send(Control.STOP);
            assert(receiveOnly!Control is Control.END);
        }

        ownerTid.send(Control.LIVE);
        bool stop = false;
        while (!stop) {
            receive(
                    (DiscoveryRequestCommand request) { bootstrap_tid.send(request); },
                    (DiscoveryControl state) { ownerTid.send(state); },
                    (Control control) {
                if (control is Control.STOP) {
                    stop = true;
                }
            });
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

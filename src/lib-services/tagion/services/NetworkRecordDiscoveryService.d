module tagion.services.NetworkRecordDiscoveryService;

import core.time;
import std.datetime;
import std.concurrency;
import std.format;

import tagion.services.Options;
import tagion.basic.Basic : nameOf;
import tagion.basic.Types : Buffer, Control, Pubkey;
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

void networkRecordDiscoveryService(
    Pubkey pubkey,
    shared p2plib.Node p2pnode,
    string task_name,
    immutable(Options) opts) nothrow {
    try {

        scope (exit) {
            log("exit");
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);
        immutable inner_task_name = format("%s-%s", task_name, "internal");
        const net = new StdHashNet();
        const internal_hirpc = HiRPC(null);

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
        while(!stop) {
            receive(
                //&receiveAddrBook,
                (DiscoveryRequestCommand request) {
                    log("send request: %s", request);
                    bootstrap_tid.send(request);
                },
                (DiscoveryState state) {
                    log.trace("state %s", state);
                    ownerTid.send(state);
                },
                (Control control) {
                if (control == Control.STOP) {
                    log("stop");
                    stop = true;
                }
            });
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

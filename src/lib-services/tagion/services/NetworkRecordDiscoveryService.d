module tagion.services.NetworkRecordDiscoveryService;

import core.time;
import std.datetime;
import std.typecons;
import std.conv;
import std.concurrency;
import std.stdio;
import std.array;
import std.algorithm.iteration;
import std.format;

import tagion.services.Options;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import tagion.logger.Logger;
import tagion.utils.StdTime;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import p2plib = p2p.node;
import tagion.crypto.SecureInterfaceNet : HashNet;

//import tagion.gossip.P2pGossipNet : ActiveNodeAddressBook;
import tagion.gossip.AddressBook : addressbook, NodeAddress;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.Recorder : RecordFactory;
import tagion.script.StandardRecords;
import tagion.communication.HiRPC;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.FileDiscoveryService;
import tagion.services.MdnsDiscoveryService;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hibon.HiBONJSON;

//import tagion.Keywords : NetworkMode;
import tagion.basic.TagionExceptions : fatal, taskfailure, TagionException;
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

        version(none)
        void receiveAddrBook(ActiveNodeAddressBook address_book) {
            assert(0, "Shoudl not be used");
            log.trace("updated addr book: %d", addressbook.numOfActiveNodes);
            //   ownerTid.send(address_book);
        }

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

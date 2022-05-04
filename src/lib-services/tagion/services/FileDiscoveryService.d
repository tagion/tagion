module tagion.services.FileDiscoveryService;

import core.time;
import std.datetime;
import std.typecons;
import std.conv;
import std.format;
import std.concurrency;
import std.stdio;
import std.file : exists;
import std.array;

// import tagion.services.LoggerService;
import p2plib = p2p.node;
import tagion.utils.Miscellaneous : cutHex;
import tagion.services.Options;
import tagion.logger.Logger;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import tagion.basic.TagionExceptions : TagionException, taskException, fatal;
import tagion.services.MdnsDiscoveryService;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : fwrite, fread;
import tagion.hibon.Document : Document;
import tagion.services.ServerFileDiscoveryService : DiscoveryRequestCommand, DiscoveryState;

import tagion.gossip.P2pGossipNet : ActiveNodeAddressBook;
import tagion.gossip.AddressBook : addressbook, NodeAddress, AddressBook;

void fileDiscoveryService(
    Pubkey pubkey,
    shared p2plib.Node node,
    string task_name,
    immutable(Options) opts) nothrow { //TODO: for test
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);
        string shared_storage = opts.path_to_shared_info;

        bool stop = false;

        void initialize() {
            static uint count;
            count++;
            log("initializing %d %s", count, pubkey.cutHex);
            addressbook.load(shared_storage, false);
            addressbook.erase(pubkey);
            addressbook[pubkey] = NodeAddress(node.LlistenAddress, opts.dart, opts.port_base);
            addressbook.save(shared_storage, true);
        }

        void updateAddressbook() {
            static uint count;
            count++;
            log.trace("update %d %s", count, pubkey.cutHex);
            addressbook.load(shared_storage, true);
        }

        initialize;
        log("File Discovery started");
        ownerTid.send(Control.LIVE);
        bool addressbook_done;
        bool addressbook_requested;
        while (!stop) {
            const message = receiveTimeout(
                500.msecs,
                (Control control) {
                    if (control is Control.STOP) {
                        log("stop");
                        stop = true;
                    }
                },
                (DiscoveryRequestCommand request) {
                    with (DiscoveryRequestCommand) {
                        final switch (request) {
                        case RequestTable:
                            pragma(msg, "fixme(cbr):Address book request should not be used anymore (FileDiscoveryService)");

                            //                        initialize();
                            auto address_book = new ActiveNodeAddressBook(null); //node_addrses);
                            //log("Requested: %d : %d", addressbook._data.length, address_book.data.length);
                            addressbook_requested=true;
                            ownerTid.send(address_book);
                            break;
                        case BecomeOnline:
                            log("Becoming online..");
                            break;
                        case BecomeOffline:
                            log("Becoming off-line");
                            break;
                        case UpdateTable:
                            throw new TagionException(format("DiscoveryRequestCommand %s has not function", request));
                            break;

                        }
                    }
                });
            log.trace("FILE NETWORK READY %d < %d ", addressbook.numOfNodes, opts.nodes);
            if (!addressbook_done) {
                if (!message) {
                    updateAddressbook;
                }
                if (addressbook_requested && addressbook.isReady) {
                    ownerTid.send(DiscoveryState.READY);
                    addressbook_done=true;
                }
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

module tagion.services.MdnsDiscoveryService;

import p2plib = p2p.node;
import p2p.callback;
import p2p.cgo.c_helper;
import tagion.communication.HandlerPool;

//import tagion.dart.DART;
import core.time;
import std.datetime;
import tagion.services.Options;

//import std.typecons;
import std.conv;
import tagion.logger.Logger;
import std.concurrency;
import tagion.basic.Basic : Buffer, Control, Pubkey;
import std.stdio;
import tagion.gossip.AddressBook : NodeAddress, addressbook;
import tagion.basic.TagionExceptions : fatal;
import tagion.services.ServerFileDiscoveryService : DiscoveryRequestCommand, DiscoveryState;
import tagion.gossip.P2pGossipNet;

void mdnsDiscoveryService(
        Pubkey pubkey,
        shared p2plib.Node node,
        string task_name,
        immutable(Options) opts) nothrow { //TODO: for test
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);

        p2plib.MdnsService discovery = node.startMdns("tagion_mdns", opts.discovery.interval.msecs);

        log("Run mdns service");
        p2plib.MdnsNotifee notifee;
        // if(opts.discovery.notify_enabled){
        log("Mdns: notify enabled");
        notifee = discovery.registerNotifee(&StdHandlerCallback, task_name);
        // }
        scope (exit) {
            // if(opts.discovery.notify_enabled){
            notifee.close();
            // }
        }

        bool stop = false;

        bool checkTimestamp(SysTime time, Duration duration) {
            return (Clock.currTime - time) > duration;
        }

        void updateTimestamp(ref SysTime time) {
            time = Clock.currTime;
        }

        SysTime mdns_start_timestamp;
        updateTimestamp(mdns_start_timestamp);
        void notifyReadyAfterDelay() {
            static bool owner_notified;
            if (!owner_notified) {
                const after_delay = checkTimestamp(mdns_start_timestamp,
                        opts.discovery.delay_before_start.msecs);
                if (after_delay) {
                    ownerTid.send(DiscoveryState.READY);
                    owner_notified = true;
                }
            }
        }

        addressbook[pubkey] = NodeAddress(node.LlistenAddress, opts.dart, opts.port_base);
        ownerTid.send(Control.LIVE);
        bool addressbook_done;
        while (!stop) {
            pragma(msg, "fixme(alex): 500.msecs shoud be an option parameter");
            const message=receiveTimeout(
                    500.msecs,
                    (Control control) {
                if (control is Control.STOP) {
                    stop = true;
                }
            },
                    (DiscoveryRequestCommand request) {
                with (DiscoveryRequestCommand) {
                    final switch (request) {
                    case RequestTable:
                        auto address_book = new ActiveNodeAddressBook(addressbook._data); //node_addrses);
                        log("Requested: %s : %d", addressbook._data.length, address_book.data.length);
                        ownerTid.send(address_book); //addressbook._data);
                        break;
                    case BecomeOnline:
                    case BecomeOffline:
                    case UpdateTable:
                        break;

                    }
                }
            });
                        if (!addressbook_done) {
/*
            if (!message) {
                updateAddressbook;
            }
*/
            if (addressbook.ready(opts)) {
                ownerTid.send(DiscoveryState.READY);
                addressbook_done=true;
            // }
            // }
// }
//                         notifyReadyAfterDelay();
        }

//            notifyReadyAfterDelay();
                        }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

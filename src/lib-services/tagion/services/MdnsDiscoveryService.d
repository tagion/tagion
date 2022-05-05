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
            notifee.close();
        }

        bool stop = false;

        addressbook[pubkey] = NodeAddress(node.LlistenAddress, opts.dart, opts.port_base);
        ownerTid.send(Control.LIVE);
        bool addressbook_done;
        while (!stop) {
            pragma(msg, "fixme(alex): 500.msecs shoud be an option parameter");
            const message = receiveTimeout(
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
                        pragma(msg, "fixme(cbr):Address book request should not be used anymore");
                        //auto address_book = new ActiveNodeAddressBook(null); //node_addrses);
                        log("Requested: %s ", addressbook._data.length);
                        addressbook_done = false;
                        //ownerTid.send(address_book); //addressbook._data);
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
                log.trace("MDNS NETWORK READY %d < %d (%s)", addressbook.numOfNodes, opts.nodes, addressbook.isReady);

                if (addressbook.isReady) {
                    ownerTid.send(DiscoveryState.READY);
                    addressbook_done = true;
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

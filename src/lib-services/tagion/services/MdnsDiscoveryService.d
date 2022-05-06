module tagion.services.MdnsDiscoveryService;

import p2plib = p2p.node;
import p2p.callback;

import core.time;
import std.concurrency;

import tagion.services.Options;

import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control, Pubkey;
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
        log("Mdns: notify enabled");
        notifee = discovery.registerNotifee(&StdHandlerCallback, task_name);

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
                        log("Requested: %s ", addressbook._data.length);
                        addressbook_done = false;
                        break;
                    case BecomeOnline:
                    case BecomeOffline:
                    case UpdateTable:
                        break;

                    }
                }
            });
            if (!addressbook_done) {
                log.trace("MDNS NETWORK READY %d < %d (%s)", addressbook.numOfNodes, opts.nodes, addressbook.isReady);

                if (addressbook.isReady) {
                    ownerTid.send(DiscoveryState.READY);
                    addressbook_done = true;
                }
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

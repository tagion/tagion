module tagion.prior_services.MdnsDiscoveryService;

import p2plib = p2p.node;
import p2p.callback;

import core.time;
import std.concurrency;

import tagion.prior_services.Options;

import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control;
import tagion.crypto.Types : Pubkey;
import tagion.gossip.AddressBook : NodeAddress, addressbook;
import tagion.actor.exceptions : fatal;
import tagion.prior_services.NetworkRecordDiscoveryService : DiscoveryRequestCommand, DiscoveryControl;

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

        p2plib.MdnsNotifee notifee;
        notifee = discovery.registerNotifee(&StdHandlerCallback, task_name);

        scope (exit) {
            notifee.close();
        }

        bool stop = false;

        addressbook[pubkey] = NodeAddress(node.LlistenAddress, opts.port_base);
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
                        addressbook_done = false;
                        break;
                    case BecomeOnline:
                    case BecomeOffline:
                    case UpdateTable:
                        break;

                    }
                }
            }
            );
            if (!addressbook_done) {
                log.trace("MDNS NETWORK READY %d < %d (%s)", addressbook.numOfNodes, opts.nodes, addressbook
                        .isReady);

                if (addressbook.isReady) {
                    ownerTid.send(DiscoveryControl.READY);
                    addressbook_done = true;
                }
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

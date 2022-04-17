module tagion.services.MdnsDiscoveryService;

import p2plib = p2p.node;
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
        while(!stop) {
            pragma(msg, "fixme(alex): 500.msecs shoud be an option parameter");
            receiveTimeout(
                    500.msecs,
                    (Control control) {
                if (control == Control.STOP) {
                    stop = true;
                }
            }, (DiscoveryRequestCommand request) {
                final switch (request) {
                case DiscoveryRequestCommand.RequestTable:
                    auto address_book = new ActiveNodeAddressBook(addressbook._data); //node_addrses);
                        log("Requested: %s : %d", addressbook._data.length, address_book.data.length);
                        ownerTid.send(address_book); //addressbook._data);
                        break;
                case DiscoveryRequestCommand.BecomeOnline:
                case DiscoveryRequestCommand.UpdateTable:
                case DiscoveryRequestCommand.BecomeOffline:
                        break;

                }
            });
            notifyReadyAfterDelay();
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

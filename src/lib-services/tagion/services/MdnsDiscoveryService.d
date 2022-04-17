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
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import std.stdio;
import tagion.gossip.AddressBook : NodeAddress, addressbook;
import tagion.basic.TagionExceptions : fatal;
import tagion.services.ServerFileDiscoveryService : DiscoveryRequestCommand, DiscoveryState;
import tagion.gossip.P2pGossipNet;

void mdnsDiscoveryService(shared p2plib.Node node, string task_name, immutable(Options) opts) nothrow { //TODO: for test
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);

        bool is_ready = false;

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

        auto stop = false;
        NodeAddress[Pubkey] node_addrses;

        bool checkTimestamp(SysTime time, Duration duration) {
            return (Clock.currTime - time) > duration;
        }

        void updateTimestamp(ref SysTime time) {
            time = Clock.currTime;
        }

        SysTime mdns_start_timestamp;
        updateTimestamp(mdns_start_timestamp);

        auto owner_notified = false;

        void notifyReadyAfterDelay() {
            if (!owner_notified) {
                const after_delay = checkTimestamp(mdns_start_timestamp,
                        opts.discovery.delay_before_start.msecs);
                if (after_delay) {
                    ownerTid.send(DiscoveryState.READY);
                    owner_notified = true;
                }
            }
        }

        void addOwnInfo() {
            NodeAddress node_address = NodeAddress(node.LlistenAddress, opts.dart, opts.port_base);
            immutable pk = cast(immutable(ubyte)[])(node_address.id);
            node_addrses[cast(Pubkey) pk] = node_address;
        }

        ownerTid.send(Control.LIVE);
        //    try{
        do {
            pragma(msg, "fixme(alex); 500.msecs shoud be an option parameter");
            receiveTimeout(500.msecs, (Response!(ControlCode.Control_PeerDiscovered) response) {
                string address = cast(string) response.data;
                NodeAddress node_address = NodeAddress(NodeAddress.parseAddr(address), opts.dart, opts.port_base);
                immutable pk = cast(immutable(ubyte)[])(node_address.id);
                node_addrses[cast(Pubkey) pk] = node_address;
                // log("RECEIVED PEER %d", node_addrses.length);
            }, (Control control) {
                if (control == Control.STOP) {
                    // log("stop");
                    stop = true;
                }
            }, (DiscoveryRequestCommand request) {
                final switch (request) {
                case DiscoveryRequestCommand.BecomeOnline: {
                        log("Becoming online..");
                        addOwnInfo();
                        break;
                    }
                case DiscoveryRequestCommand.RequestTable: {
                        auto address_book = new ActiveNodeAddressBook(node_addrses);
                        log("Requested: %s", address_book.data.length);
                        ownerTid.send(address_book);
                        break;
                    }
                case DiscoveryRequestCommand.UpdateTable:
                case DiscoveryRequestCommand.BecomeOffline: {
                        break;
                    }
                }
            });
            notifyReadyAfterDelay();
        }
        while (!stop);
    }
    catch (Throwable t) {
        fatal(t);
    }
}

module tagion.services.MdnsDiscoveryService;

import p2plib = p2p.node;
import p2p.callback;
import p2p.cgo.helper;
import tagion.communication.HandlerPool;
//import tagion.dart.DART;
import core.time;
import std.datetime;
import tagion.Options;
//import std.typecons;
import std.conv;
import tagion.services.LoggerService;
import std.concurrency;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import std.stdio;

void mdnsDiscoveryService(shared p2plib.Node node, immutable(Options) opts){  //TODO: for test
    scope(exit){
        log("exit mdns discovery service");
        ownerTid.prioritySend(Control.END);
    }

    bool checkTimestamp(SysTime time, Duration duration){
        return (Clock.currTime - time) > duration;
    }
    void updateTimestamp(ref SysTime time){
        time = Clock.currTime;
    }

    bool is_ready = false;

    p2plib.MdnsService discovery = node.startMdns("tagion", opts.discovery.interval.msecs);
    log.register(opts.discovery.task_name);

    log("Run mdns service");
    p2plib.MdnsNotifee notifee;
    if(opts.discovery.notify_enabled){
        log("Mdns: notify enabled");
        notifee = discovery.registerNotifee(&StdHandlerCallback, opts.discovery.task_name);
    }
    scope(exit){
        if(opts.discovery.notify_enabled){
            notifee.close();
        }
    }
    SysTime mdns_start_timestamp;
    updateTimestamp(mdns_start_timestamp);
    SysTime mdns_loop_timestamp;
    updateTimestamp(mdns_loop_timestamp);

    auto stop = false;
    NodeAddress[Pubkey] node_addrses;
    ownerTid.send(Control.LIVE);
    try{
        do{
            receiveTimeout(
                500.msecs,
                (Response!(ControlCode.Control_PeerDiscovered) response) {
                    string address = cast(string)response.data;
                    // log("discovery node: %s", address);
                    NodeAddress node_address = NodeAddress(NodeAddress.parseAddr(address), opts);
                    immutable pk = cast(immutable (ubyte)[]) (node_address.id);
                    node_addrses[cast(Pubkey) pk] = node_address;
                    // log("\nNODE ADDRESSes: %s\n", node_addrses);
                },
                (Control control){
                    if(control == Control.STOP){
                        // log("stop");
                        stop = true;
                    }
                }
            );
            if(opts.discovery.notify_enabled){
                void addOwnInfo(){
                    NodeAddress node_address = NodeAddress(node.LlistenAddress, opts);
                    immutable pk = cast(immutable (ubyte)[]) (node_address.id);
                    node_addrses[cast(Pubkey) pk] = node_address;
                }
                if(!is_ready && checkTimestamp(mdns_start_timestamp, opts.discovery.delay_before_start.msecs)){
                    log("AFTER DELAY");
                    is_ready = true;

                    // log("\nBEFORE NODE ADDRESSes: %s\n", node_addrses);
                    addOwnInfo();
                    // log("\nAFTER NODE ADDRESSes: %s\n", node_addrses);

                    immutable result = new immutable AddressBook!Pubkey(node_addrses);
                    // log("\nAFTER ADDR BOOK: %s\n", result.data);
                    ownerTid.send(result);
                    node_addrses.clear;
                    updateTimestamp(mdns_loop_timestamp);
                }
                if(is_ready && checkTimestamp(mdns_loop_timestamp, opts.discovery.interval.msecs)){

                    // log("\nBEFORE NODE ADDRESSes: %s\n", node_addrses);
                    addOwnInfo();
                    // log("\nAFTER NODE ADDRESSes: %s\n", node_addrses);

                    immutable result = new immutable AddressBook!Pubkey(node_addrses);
                    // log("\nNODE ADDRESSes: %s\n", node_addrses);
                    ownerTid.send(result);
                    node_addrses.clear;
                    updateTimestamp(mdns_loop_timestamp);
                }
            }
        }while(!stop);
    }catch(Exception e){
        log("Exception: %s", e.msg);
    }
}

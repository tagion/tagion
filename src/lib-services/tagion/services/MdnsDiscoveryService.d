module tagion.services.MdnsDiscoveryService;

import p2plib = p2p.node;
import p2p.callback;
import p2p.cgo.helper;
import tagion.utils.HandlerPool;
import tagion.dart.DART;
import core.time;
import std.datetime;
import tagion.Options;
import std.typecons;
import std.conv;
import tagion.services.LoggerService;
import std.concurrency;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import std.stdio;

immutable class AddressBook(TKey){
    this(NodeAddress[TKey] addrs){
        this.data = cast(immutable) addrs.dup;
    }
    immutable(NodeAddress[TKey]) data;
}
struct NodeAddress{
    enum tcp_token = "/tcp/";
    enum p2p_token = "/p2p/";
    string address;
    bool is_marshal;
    string id;
    uint port;
    DART.SectorRange sector;
    this(string address, immutable Options opts, bool marshal = false){
        import std.string;
        try{
            this.address = address;
            this.is_marshal = marshal;
            if(!marshal){
                this.id = address[address.lastIndexOf(p2p_token)+5..$];
                auto tcpIndex = address.indexOf(tcp_token)+tcp_token.length;
                this.port = to!uint(address[tcpIndex .. tcpIndex + 4]);

                const node_number = this.port - opts.port_base;
                if(this.port>=opts.dart.sync.maxSlavePort){
                    sector = DART.SectorRange(opts.dart.sync.netFromAng, opts.dart.sync.netToAng);
                }else{
                    const max_sync_node_count = opts.dart.sync.master_angle_from_port
                    ? opts.dart.sync.maxSlaves
                    : opts.dart.sync.maxMasters;
                    auto ang_range = calcAngleRange(opts, node_number, max_sync_node_count);

                    sector = DART.SectorRange(ang_range[0], ang_range[1]);
                }
            }else{
                import std.json;
                auto json = parseJSON(address);
                this.id = json["ID"].str;
                auto addr = json["Addrs"].array()[0].str();
                auto tcpIndex = addr.indexOf(tcp_token)+tcp_token.length;
                this.port = to!uint(addr[tcpIndex .. tcpIndex + 4]);
            }
        }catch(Exception e){
            writeln(e.msg);
                log.fatal(e.msg);
        }
    }

    static Tuple!(ushort, ushort) calcAngleRange(immutable(Options) opts, const ulong node_number, const ulong max_nodes){
        import std.math: ceil, floor;
        float delta = (cast(float)(opts.dart.sync.netToAng - opts.dart.sync.netFromAng))/max_nodes;
        auto from_ang = to!ushort(opts.dart.from_ang + floor(node_number*delta));
        auto to_ang = to!ushort(opts.dart.from_ang + floor((node_number+1)*delta));
        return tuple(from_ang, to_ang);
    }
    static string parseAddr(string addr) {
        import std.string;

        string result;
        auto firstpartAddr = addr.indexOf('[') + 1;
        auto secondpartAddr = addr.indexOf(']');
        auto firstpartId = addr.indexOf('{') + 1;
        auto secondpartId = addr.indexOf(':');
        // writefln("addr %s len: %d\naddress from %d to %d\nid from %d to %d", addr,
                // addr.length, firstpartAddr, secondpartAddr, firstpartId, secondpartId);
        result = addr[firstpartAddr .. secondpartAddr] ~ p2p_token ~ addr[firstpartId .. secondpartId];
        return result;
    }
    public string toString(){
        return address;
    }
}
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

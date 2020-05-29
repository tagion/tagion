module tagion.services.ServerFileDiscoveryService;

import core.time;
import std.datetime;
import tagion.Options;
import std.typecons;
import std.conv;
import tagion.services.LoggerService;
import std.concurrency;
import tagion.Base : Buffer, Control, nameOf, Pubkey;
import std.stdio;
import tagion.services.MdnsDiscoveryService;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import std.file;
import std.file: fwrite = write;
import std.array;
import p2plib = p2p.node;
import std.net.curl;
import tagion.hibon.HiBONJSON;

void serverFileDiscoveryService(Pubkey pubkey, shared p2plib.Node node, immutable(Options) opts){  //TODO: for test
    scope(exit){
        log("exit");
        ownerTid.prioritySend(Control.END);
    }

    log.register(opts.discovery.task_name);

    bool checkTimestamp(SysTime time, Duration duration){
        return (Clock.currTime - time) > duration;
    }
    void updateTimestamp(ref SysTime time){
        time = Clock.currTime;
    }

    SysTime start_timestamp;

    auto stop = false;
    NodeAddress[Pubkey] node_addresses;

    void recordOwnInfo(string addrs){
        auto params = new HiBON;
        params["pkey"] = pubkey;
        params["address"] = addrs;
        auto doc = Document(params.serialize);
        auto json = doc.toJSON().toString();
        log("posting info to %s \n %s", opts.serverFileDiscovery.url ~ "/node/record", json);
        try{
            post(opts.serverFileDiscovery.url ~ "/node/record", ["value": json]);
        }catch(Exception e){
            log("ERROR: %s", e.msg);
        }
    }

    void eraseOwnInfo(){
        auto params = new HiBON;
        params["pkey"] = pubkey;
        log("posting info to %s", opts.serverFileDiscovery.url ~ "/node/erase");
        post(opts.serverFileDiscovery.url ~ "/node/erase", ["value":(cast(string)params.serialize)]);
    }

    scope(exit){
        eraseOwnInfo();
    }

    void initialize(){
        log("initializing");
        try{
            auto read_buff = get(opts.serverFileDiscovery.url ~ "/node/storage");
            log("%s", cast(char[])read_buff);
            auto splited_read_buff = read_buff.split("\n");
            log("%d", splited_read_buff.length);
            foreach(node_info_buff; splited_read_buff){
                if(node_info_buff.length>0){
                    log("%s", cast(char[])node_info_buff);
                    import std.json;
                    auto json = (cast(string)node_info_buff).parseJSON;
                    auto hibon = json.toHiBON;
                    auto doc = Document(hibon.serialize);
                    import tagion.hibon.HiBONJSON;
                    log("%s", doc.toJSON);
                    auto pkey_buff=doc["pkey"].get!Buffer;
                    auto pkey = cast(Pubkey)pkey_buff;
                    auto addr = doc["address"].get!string;
                    import tagion.utils.Miscellaneous : toHexString, cutHex;
                    auto node_addr = NodeAddress(addr, opts);
                    node_addresses[pkey]= node_addr;
                    log("added %s", pkey);
                }
            }
            log("initialized %d", node_addresses.length);
        }catch(Exception e){
            writeln("Er:", e.msg);
            log.fatal(e.msg);
        }
    }
    spawn(&handleAddrChanedEvent, node);
    spawn(&handleRechabilityChanged, node);
    node.SubscribeToAddressUpdated("addr_changed_handler");
    node.SubscribeToRechabilityEvent("rechability_handler");
    string public_addr = receiveOnly!string;
    recordOwnInfo(public_addr);
    updateTimestamp(start_timestamp);

    bool is_ready = false;
    try{
        do{
            receiveTimeout(
                500.msecs,
                (immutable(Pubkey) key, Tid tid){
                    log("looking for key: %s", key);
                    tid.send(node_addresses[key]);
                },
                (Control control){
                    if(control == Control.STOP){
                        log("stop");
                        stop = true;
                    }
                }
            );
            if(!is_ready && checkTimestamp(start_timestamp, opts.discovery.delay_before_start.msecs)){
                is_ready = true;
                initialize();
                auto address_book = new immutable AddressBook!Pubkey(node_addresses);
                ownerTid.send(address_book);
            }
        }while(!stop);
    }catch(Exception e){
        log("Exception: %s", e.msg);
    }
}

void handleAddrChanedEvent(shared p2plib.Node node){
    register("addr_changed_handler", thisTid);

    do{
        receive(
            (immutable(ubyte)[] data){
                auto pub_addr = node.PublicAddress;
                writeln("Addr changed %s", pub_addr);
                if(pub_addr.length > 0){
                    ownerTid.send(pub_addr);
                }
            }
        );
    }while(true);
}

void handleRechabilityChanged(shared p2plib.Node node){
    register("rechability_handler", thisTid);
    do{
        receive(
            (immutable(ubyte)[] data){
                writeln("Addr changed");
            }
        );
    }while(true);
}
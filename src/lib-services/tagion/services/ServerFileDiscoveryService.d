module tagion.services.ServerFileDiscoveryService;

import core.time;
import std.datetime;
import tagion.Options;
import std.typecons;
import std.conv;
import tagion.basic.Logger;
import std.concurrency;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import std.stdio;
//import tagion.services.MdnsDiscoveryService;
import tagion.gossip.P2pGossipNet : AddressBook, NodeAddress;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import std.file;
import std.file: fwrite = write;
import std.array;
import p2plib = p2p.node;
import std.net.curl;
import tagion.hibon.HiBONJSON;
import tagion.basic.TagionExceptions : fatal;

enum ServerRequestCommand{
    BecomeOnline = 1,
    RequestTable = 2,
    BecomeOffline =3,
}

void serverFileDiscoveryService(Pubkey pubkey, shared p2plib.Node node, immutable(Options) opts) nothrow {  //TODO: for test
    try{
        scope(exit){
            log("exit");
            ownerTid.prioritySend(Control.END);
        }

        log.register(opts.discovery.task_name);

        if (opts.serverFileDiscovery.url.length == 0){
            log.error("Server url is missing");
            ownerTid.send(Control.STOP);
            return;
        }

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
            if(opts.serverFileDiscovery.token){
                auto params = new HiBON;
                params["pkey"] = pubkey;
                params["address"] = addrs;
                auto doc = Document(params.serialize);
                auto json = doc.toJSON().toString();
                log("posting info to %s \n %s", opts.serverFileDiscovery.url ~ "/node/record", json);
                try{
                    post(opts.serverFileDiscovery.url ~ "/node/record", ["value": json, "token": opts.serverFileDiscovery.token]);
                }catch(Exception e){
                    log("ERROR on sending: %s", e.msg);
                }
            }
            else{
                log("Token missing.. Cannot record own info");
            }
        }

        void eraseOwnInfo(){
            // auto params = new HiBON;
            // params["pkey"] = pubkey;
            log("posting info to %s", opts.serverFileDiscovery.url ~ "/node/erase");
            // post(opts.serverFileDiscovery.url ~ "/node/erase", ["value":(cast(string)params.serialize)]);
            post(opts.serverFileDiscovery.url ~ "/node/erase", ["value":(cast(string)pubkey), "tag": opts.serverFileDiscovery.tag]);
        }

        scope(exit){
            eraseOwnInfo();
        }

        void initialize() nothrow {
            try{
                auto read_buff = get(opts.serverFileDiscovery.url ~ "/node/storage?tag=" ~ opts.serverFileDiscovery.tag);
                // log("%s", cast(char[])read_buff);
                auto splited_read_buff = read_buff.split("\n");
                // log("%d", splited_read_buff.length);
                foreach(node_info_buff; splited_read_buff){
                    if(node_info_buff.length>0){
                        import std.json;
                        auto json = (cast(string)node_info_buff).parseJSON;
                        auto hibon = json.toHiBON;
                        auto doc = Document(hibon.serialize);
                        import tagion.hibon.HiBONJSON;
                        auto pkey_buff=doc["pkey"].get!Buffer;
                        auto pkey = cast(Pubkey)pkey_buff;
                        auto addr = doc["address"].get!string;
                        import tagion.utils.Miscellaneous : toHexString, cutHex;
                        auto node_addr = NodeAddress(addr, opts, true);
                        node_addresses[pkey]= node_addr;
                    }
                }
                log("initialized %d", node_addresses.length);
            }
            catch(Exception e){
                log.error(e.msg);
            }
        }
        spawn(&handleAddrChanedEvent, node);
        spawn(&handleRechabilityChanged, node);
        auto substoaddrupdate = node.SubscribeToAddressUpdated("addr_changed_handler");
        auto substorechability = node.SubscribeToRechabilityEvent("rechability_handler");
        scope(exit){
            substoaddrupdate.close();
            substorechability.close();
        }
        updateTimestamp(start_timestamp);
        bool is_online = false;
        string last_seen_addr = "";

        bool is_ready = false;
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
                },
                (string updated_address){
                    last_seen_addr = updated_address;
                    if(is_online){
                        recordOwnInfo(updated_address);
                    }
                },
                (ServerRequestCommand cmd){
                    switch(cmd){
                    case ServerRequestCommand.BecomeOnline: {
                        is_online = true;
                        log("Becoming online..");
                        updateTimestamp(start_timestamp);
                        if(last_seen_addr!=""){
                            recordOwnInfo(last_seen_addr);
                        }
                        break;
                    }
                    case ServerRequestCommand.RequestTable: {
                        initialize();
                        auto address_book = new immutable AddressBook!Pubkey(node_addresses);
                        ownerTid.send(address_book);
                        break;
                    }
                    case ServerRequestCommand.BecomeOffline: {
                        eraseOwnInfo();
                        break;
                    }
                    default:
                        pragma(msg, "Fixme(alex): What should happen when the command does not exist? (Maybe you should use final case)");
                    }
                }
                );
            if (!is_ready && checkTimestamp(start_timestamp, opts.serverFileDiscovery.delay_before_start.msecs) && is_online){
                log("initializing");
                updateTimestamp(start_timestamp);
                is_ready = true;
                initialize();
                auto address_book = new immutable AddressBook!Pubkey(node_addresses);
                ownerTid.send(address_book);
            }
            if (is_ready && checkTimestamp(start_timestamp, opts.serverFileDiscovery.update.msecs)){
                log("updating");
                updateTimestamp(start_timestamp);
                initialize();
                auto address_book = new immutable AddressBook!Pubkey(node_addresses);
                ownerTid.send(address_book);
            }
        } while(!stop);
    }
    catch(Throwable t){
        fatal(t);
    }
}

void handleAddrChanedEvent(shared p2plib.Node node) nothrow {
    try {
        register("addr_changed_handler", thisTid);

        do{
            receive(
                (immutable(ubyte)[] data){
                    auto pub_addr = node.PublicAddress;
                    log("Addr changed %s", pub_addr);
                    if(pub_addr.length > 0){
                        auto addrinfo = node.AddrInfo();
                        ownerTid.send(addrinfo);
                    }
                }
                );
        } while(true);
    }
    catch (Throwable t) {
        fatal(t);
    }
}

void handleRechabilityChanged(shared p2plib.Node node) nothrow {
    try {
        register("rechability_handler", thisTid);
        do{
            receive(
                (immutable(ubyte)[] data){
                    log("RECHABILITY CHANGED: %s", cast(string) data);
                }
                );
        } while(true);
    }
    catch (Throwable t) {
        fatal(t);
    }
}

module tagion.services.FileDiscoveryService;

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

void fileDiscoveryService(Pubkey pubkey, string node_address, immutable(Options) opts){  //TODO: for test
    scope(exit){
        log("exit");
        ownerTid.prioritySend(Control.END);
    }
    string shared_storage = opts.path_to_shared_info;

    bool checkTimestamp(SysTime time, Duration duration){
        return (Clock.currTime - time) > duration;
    }
    void updateTimestamp(ref SysTime time){
        time = Clock.currTime;
    }

    bool is_ready = false;

    log.register(opts.discovery.task_name);

    SysTime mdns_start_timestamp;
    updateTimestamp(mdns_start_timestamp);

    auto stop = false;
    NodeAddress[Pubkey] node_addresses;

    void recordOwnInfo(){
        try{
            log("record own info");
            auto params = new HiBON;
            params["pkey"] = pubkey;
            params["address"] = node_address;
            shared_storage.append(params.serialize);
            shared_storage.append("/n");
        }
        catch(Exception e){
            log.error("Exception: %s", e.msg);
            stop = true;
        }
    }

    void eraseOwnInfo(){
        try{
            log("erase");
            auto read_buff = cast(ubyte[]) shared_storage.read;
            auto splited_read_buff = read_buff.split("/n");
            log("%d", splited_read_buff.length);
            foreach(node_info_buff; splited_read_buff){
                if(node_info_buff.length>0){
                    auto doc = Document(cast(immutable)node_info_buff);
                    auto pkey_buff=doc["pkey"].get!Buffer;
                    auto pkey = cast(Pubkey)pkey_buff;
                    if(pkey == pubkey){
                        log("found myself");
                        shared_storage.fwrite(cast(string)read_buff.replace(node_info_buff, cast(ubyte[])""));
                        break;
                    }
                }
            }
        }
        catch(Exception e){
            log.error("Exception: %s", e.msg);
            stop = true;
        }
    }

    scope(exit){
        eraseOwnInfo();
    }

    void initialize(){
        log("initializing");
        try{
            auto read_buff = cast(ubyte[]) shared_storage.read;
            // log("%s", cast(char[])read_buff);
            auto splited_read_buff = read_buff.split("/n");
            // log("%d", splited_read_buff.length);
            foreach(node_info_buff; splited_read_buff){
                if(node_info_buff.length>0){
                    // log("%s", cast(char[])node_info_buff);
                    auto doc = Document(cast(immutable)node_info_buff);
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
        }
        catch(Exception e){
            log.error("Exception %s", e.msg);
        }
    }

    recordOwnInfo();
    try{
        while(!stop){
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
            if(!is_ready && checkTimestamp(mdns_start_timestamp, opts.discovery.delay_before_start.msecs)){
                log("AFTER DELAY");
                is_ready = true;
                initialize();
                pragma(msg, typeof(node_addresses.keys));
                auto address_book = new immutable AddressBook!Pubkey(node_addresses);
                ownerTid.send(address_book);
            }
        }
    }
    catch(Exception e){
        log("Exception: %s", e.msg);
        import tagion.basic.TagionExceptions : taskException;
        ownerTid.send(taskException(e));
    }
}

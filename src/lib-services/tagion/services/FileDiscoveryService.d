module tagion.services.FileDiscoveryService;

import core.time;
import std.datetime;
import std.file;
import std.file: fwrite = write;
import std.array;
import std.typecons;
import std.conv;
import std.concurrency;
//import std.stdio;


import tagion.Options;
import tagion.basic.Logger;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import tagion.gossip.P2pGossipNet : AddressBook, NodeAddress;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.TagionExceptions;
import tagion.services.ServerFileDiscoveryService: DiscoveryRequestCommand, DicvoryControl;

void fileDiscoveryService(Pubkey pubkey, string node_address, string task_name, immutable(Options) opts) {  //TODO: for test
    bool stop = false;
    scope(exit){
        log("exit");
        if (stop) {
            ownerTid.prioritySend(Control.END);
        }
    }
    string shared_storage = opts.path_to_shared_info;

    log.register(task_name);

    NodeAddress[Pubkey] node_addresses;

    void recordOwnInfo() nothrow {
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

    void eraseOwnInfo() nothrow {
        try{
            log("erase");
            auto read_buff = cast(ubyte[]) shared_storage.read;
            pragma(msg, "fixme(alex): This part could break, because you use /n to split");
            pragma(msg, "fixme(alex): Use the The Document length to find the boundries instead");
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


    bool checkTimestamp(SysTime time, Duration duration){
        return (Clock.currTime - time) > duration;
    }
    void updateTimestamp(ref SysTime time){
        time = Clock.currTime;
    }

    auto is_ready = false;
    SysTime mdns_start_timestamp;
    updateTimestamp(mdns_start_timestamp);
    auto owner_notified = false;

    void notifyReadyAfterDelay(){
        if(!owner_notified){
            const after_delay = checkTimestamp(mdns_start_timestamp, opts.discovery.delay_before_start.msecs);
            if(after_delay && is_ready){
                ownerTid.send(DicvoryControl.READY);
                owner_notified = true;
            }
        }
    }
    

    void initialize() nothrow {
        log("initializing");
        try{
            auto read_buff = cast(ubyte[]) shared_storage.read;
            auto splited_read_buff = read_buff.split("/n");
            foreach(node_info_buff; splited_read_buff){
                if(node_info_buff.length>0){
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

    ownerTid.send(Control.LIVE);
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
                },
                (DiscoveryRequestCommand request){
                    switch(request){
                        case DiscoveryRequestCommand.BecomeOnline: {
                            log("Becoming online..");
                            recordOwnInfo();
                            is_ready = true;
                            break;
                        }
                        case DiscoveryRequestCommand.RequestTable: {
                            initialize();
                            auto address_book = new immutable AddressBook!Pubkey(node_addresses);
                            ownerTid.send(address_book);
                            break;
                        }
                        case DiscoveryRequestCommand.BecomeOffline: {
                            eraseOwnInfo();
                            break;
                        }
                        default:
                            pragma(msg, "Fixme(alex): What should happen when the command does not exist? (Maybe you should use final case)");
                    }
                }
            );
            notifyReadyAfterDelay();
        }
    }
    catch(TagionException e){
        immutable task_e=e.taskException;
        log(task_e);
        ownerTid.send(task_e);
    }
    catch(Throwable t){
        immutable task_e=t.taskException;
        log(task_e);
        ownerTid.send(task_e);
    }
}

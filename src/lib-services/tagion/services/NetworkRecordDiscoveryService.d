module tagion.services.NetworkRecordDiscoveryService;

import core.time;
import tagion.utils.StdTime;
import std.datetime;
import tagion.Options;
import std.typecons;
import std.conv;
import tagion.basic.Logger;
import std.concurrency;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import std.stdio;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import p2plib = p2p.node;
import tagion.gossip.InterfaceNet : HashNet;
import std.array;
import tagion.gossip.P2pGossipNet: NodeAddress, AddressBook;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.script.StandardRecords;
import tagion.communication.HiRPC;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.FileDiscoveryService;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hibon.HiBONJSON;
import tagion.Keywords: NetworkMode;

void networkRecordDiscoveryService(Pubkey pubkey, shared p2plib.Node p2pnode, const HashNet net, string taskName, immutable(Options) opts){
    scope(exit){
        log("exit");
        ownerTid.prioritySend(Control.END);
    }
    log.register(taskName);
    HiRPC internal_hirpc = HiRPC(null);

    Document get_addr_table(immutable NodeAddress[Pubkey] node_addresses){
        auto result = new HiBON;
        foreach (i, pk; node_addresses.keys)
        {
            result[i] = pk; 
        }
        return Document(result.serialize);
    }
    DARTFile.Recorder getFromDart(Buffer fp){
        auto dart_sync_tid = locate(opts.dart.sync.task_name);
        if(dart_sync_tid!=Tid.init){
            auto sender = DART.dartRead([fp], internal_hirpc);

            auto tosend = internal_hirpc.toHiBON(sender).serialize;
            send(dart_sync_tid, taskName, tosend);
            Buffer buffer = receiveOnly!Buffer;
            const received = internal_hirpc.receive(Document(buffer));
            return DARTFile.Recorder(cast(HashNet) net, received.params);            
        }else{
            log("DART sync not running");
            return DARTFile.Recorder(cast(HashNet) net);
        }
    }
    void update_dart(immutable NodeAddress[Pubkey] node_addresses){
        log("updating dart");
        // const currstd_t = cast(sdt_t) Clock.currStdTime();
        NetworkNameRecord getNetworkNameRecord(Buffer previous = null, uint index = 0){
            auto addresses_record = NetworkNameRecord();
            addresses_record.payload = get_addr_table(node_addresses);
            addresses_record.name = net.calcHash(cast(const(ubyte)[])"address_table");
            addresses_record.index = index;
            addresses_record.node = cast(Buffer)pubkey;
            return addresses_record;
        }
        DARTFile.Recorder getFromDart(Buffer fp){
            try{
                auto dart_sync_tid = locate(opts.dart.sync.task_name);
                if(dart_sync_tid!=Tid.init){
                    auto sender = DART.dartRead([fp], internal_hirpc);
                    auto tosend = internal_hirpc.toHiBON(sender).serialize;
                    send(dart_sync_tid, taskName, tosend);
                    auto buffer = receiveOnly!Buffer;
                    const received = internal_hirpc.receive(Document(buffer));
                    auto recorder = DARTFile.Recorder(cast(HashNet)net, received.params);
                    return recorder;
                }else{
                    log("dart sync not found");
                }
                throw new NotImplementedError("test");
            }catch(Throwable e){
                log("err: %s", e.msg);
                throw e;
            }
        }
            const addr_table_fp = net.calcHash(cast(Buffer)"address_table");
            
                NetworkNameRecord ncr;
                NetworkNameCard ncl;
            auto recorder = getFromDart(addr_table_fp);
            
                if(recorder.length == 0){
                    ncr = getNetworkNameRecord();
                    ncl = NetworkNameCard();
                    ncl.name = "address_table";
                    ncl.pubkey = pubkey;
                }else{
                    ncl = NetworkNameCard(recorder.archives().front().doc);                    
                    auto ncr_recorder = getFromDart(ncl.record);
                    if(ncr_recorder.archives.length != 0){
                        const prev_ncr = NetworkNameRecord(ncr_recorder.archives.front().doc);
                        ncr = getNetworkNameRecord(ncl.record, prev_ncr.index + 1);
                    }else{
                        ncr = getNetworkNameRecord();
                    }
                }
                ncl.record = net.calcHash(ncr.toHiBON.serialize);

                auto insert_recorder = DARTFile.Recorder(cast(HashNet)net);
                foreach (i, key; node_addresses.keys)
                {
                    auto nnr = NetworkNodeRecord();
                    nnr.node = cast(Buffer)key;
                    nnr.time = Clock.currStdTime();
                    nnr.state = NetworkNodeRecord.State.ACTIVE;
                    nnr.address = node_addresses[key].address;
                    // nnr.dart_from = 0;
                    // nnr.dart_to = 0;
                    log("ADDRESS: %s", Document(nnr.toHiBON.serialize).toJSON);
                    log("insert to recorder PK: %s HASH: %s", key.cutHex, net.hashOf(Document(nnr.toHiBON().serialize)).cutHex);
                    insert_recorder.add(Document(nnr.toHiBON.serialize));
                }
                insert_recorder.add(Document(ncr.toHiBON.serialize));
                insert_recorder.add(Document(ncl.toHiBON.serialize));
                auto dart_sync_tid = locate(opts.dart.sync.task_name);
                if(dart_sync_tid!=Tid.init){
                    log("modifying dart with: %d archives", insert_recorder.archives.length);
                    insert_recorder.dump();
                    auto sender = DART.dartModify(insert_recorder, internal_hirpc);
                    auto tosend = internal_hirpc.toHiBON(sender).serialize;
                    send(dart_sync_tid, taskName, tosend);
                    receive((Buffer result){
                        log("Update dart result: %s", cast(string)result);
                    });
                }else{
                    log("dart sync not located");
                }
    }
    auto is_ready = false;
    void receiveAddrBook(immutable(AddressBook!Pubkey) address_book) {
        if(is_ready){
            update_dart(address_book.data);
        }
        ownerTid.send(address_book);
    }
    Tid discovery_tid;
    if (opts.net_mode == NetworkMode.local)
    {
        discovery_tid = spawn(&fileDiscoveryService, pubkey, p2pnode.LlistenAddress, "internal_discovery", opts);
    }
    else if (opts.net_mode == NetworkMode.pub)
    {
        discovery_tid = spawn(&serverFileDiscoveryService, pubkey, p2pnode, "internal_discovery", opts);
    }else{
        throw new NotImplementedError("Network mode is not correct");
    }

    receiveOnly!Control;
    ownerTid.send(Control.LIVE);
    auto stop = false;
    do{            
        receive(
            &receiveAddrBook,
            (immutable(Pubkey) key, Tid tid){
                log("looking for key: %s HASH: %s", key.cutHex, net.calcHash(cast(Buffer)key).cutHex);
                auto result_recorder = getFromDart(net.calcHash(cast(Buffer)key));
                if(result_recorder.length > 0){
                    const addr_archive = result_recorder.archives.front;
                    const nnr = NetworkNodeRecord(addr_archive.doc);
                    auto address = NodeAddress(nnr.address, opts, opts.net_mode == NetworkMode.pub);
                    tid.send(address);
                }else{
                    log("address not found");
                    tid.send(null); //TODO: what to send if not found
                }
            },
            (DiscoveryRequestCommand request){
                log("send request: %s", request);
                if(request == DiscoveryRequestCommand.BecomeOnline){
                    is_ready = true;
                }
                discovery_tid.send(request);
            },
            (DicvoryControl control){
                log("Discovery received: %s", control);
                if(control == DicvoryControl.READY){
                    ownerTid.send(DicvoryControl.READY);
                }
            },
            (Control control){
                if(control == Control.STOP){
                    log("stop");
                    stop = true;
                }
            }
        );
    }while(!stop);


}

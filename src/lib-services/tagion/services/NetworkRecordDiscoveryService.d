module tagion.services.NetworkRecordDiscoveryService;

import core.time;
import std.datetime;
import std.typecons;
import std.conv;
import std.concurrency;
import std.stdio;
import std.array;
import std.algorithm.iteration;
import std.string : representation;
import std.range : isInputRange, ElementType;

import tagion.services.Options;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import tagion.logger.Logger;
import tagion.utils.StdTime;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import p2plib = p2p.node;
import tagion.crypto.SecureInterfaceNet : HashNet;

import tagion.gossip.P2pGossipNet;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.Recorder : RecordFactory;
import tagion.script.StandardRecords;
import tagion.communication.HiRPC;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.FileDiscoveryService;
import tagion.services.MdnsDiscoveryService;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hibon.HiBONJSON;

//import tagion.Keywords : NetworkMode;
import tagion.basic.TagionExceptions : fatal, taskfailure, TagionException;
import tagion.crypto.SecureNet;

void networkRecordDiscoveryService(
    Pubkey pubkey,
    shared p2plib.Node p2pnode,
    string task_name,
    immutable(Options) opts) nothrow {
    try {
        scope (exit) {
            log("exit");
            ownerTid.prioritySend(Control.END);
        }
        enum ADDR_TABLE = "address_table";
        immutable inner_task_name = task_name ~ "internal";
        log.register(task_name);
        HashNet net = new StdHashNet();
        HiRPC internal_hirpc = HiRPC(null);
        NodeAddress[Pubkey] internal_nodeaddr_table;

        auto rec_factory = RecordFactory(net);
        log("net created");
        RecordFactory.Recorder loadFromDART(Range)(Range fp) if (isInputRange!Range && is(ElementType!Range : const(Buffer)))  {
            try {
                auto dart_sync_tid = locate(opts.dart.sync.task_name);
                if (dart_sync_tid !is Tid.init) {
                    const sender = DART.dartRead(fp, internal_hirpc);

                    auto tosend = sender.toDoc.serialize;
                    send(dart_sync_tid, task_name, tosend);
                    Buffer buffer;
                    receive((Buffer buf) { buffer = buf; });
                    const received = internal_hirpc.receive(Document(buffer));
                    return rec_factory.recorder(received.response.result);
                }
                else {
                    log("DART sync not running");
                    return rec_factory.recorder;
                }
            }
            catch (Throwable e) {
                pragma(msg, "fixme(alex) Why catch when it is thrown again");
                log("err: %s", e.msg);
                throw e;
            }
        }

        // void update_internal_table(immutable NodeAddress[Pubkey] node_addresses) {
        //     internal_nodeaddr_table = cast(NodeAddress[Pubkey]) node_addresses.dup;
        // }

        void request_addr_table() {
            log("start: request_addr_table");
            const addr_table_fp = net.calcHash(ADDR_TABLE.representation);
            auto addr_table_recorder = loadFromDART([addr_table_fp]);
            if (addr_table_recorder.length > 0) {
                assert(addr_table_recorder.length == 1);
                const ncl = NetworkNameCard(addr_table_recorder[].front.filed);
                auto ncr_recorder = loadFromDART([ncl.record]);
                assert(ncr_recorder.length == 1);
                const prev_ncr = NetworkNameRecord(ncr_recorder[].front.filed);
                auto range = prev_ncr.payload[];
                auto active_pubkeys = range.map!(a => net.calcHash(a.get!Buffer));
                // alias Type=typeof(active_pubkeys);
                // static assert(isInputRange!Type);
                // pragma(msg, "ElementType!Type ",ElementType!Type);
//                static assert(isInputRange!Type);

                const addresses_recorder = loadFromDART(active_pubkeys.array);
                pragma(msg, "fixme(cbr): Should be range in the address book");
                NodeAddress[Pubkey] node_addresses;
                foreach (archive; addresses_recorder[]) {
                    auto nnr = NetworkNodeRecord(archive.filed);
                    if (nnr.state == NetworkNodeRecord.State.ACTIVE) {
                        auto node_addr = NodeAddress(nnr.address, opts.dart, opts.port_base, true);
                        auto pk = cast(Pubkey) nnr.node;
                        node_addresses[pk] = node_addr;
                    }
                }
                assert(node_addresses.length > 0);
                addressbook.overwrite(node_addresses);
                //        return cast(immutable) node_addresses;
                return;
            }
            throw new TagionException("Address table not initialized yet");
        }

        void update_dart(immutable NodeAddress[Pubkey] node_addresses) {
            log("start: update_dart");
            Document toAddressTable(immutable NodeAddress[Pubkey] node_addresses) {
                auto result = new HiBON;
                foreach (i, pk; node_addresses.keys) {
                    result[i] = pk;
                }
                return Document(result.serialize);
            }

            NetworkNameRecord getNetworkNameRecord(Buffer previous = null, uint index = 0) {
                auto addresses_record = NetworkNameRecord();
                pragma(msg, "fixme(cbr): NetworkNameRecord is HiBONRecord ctor should be used instead");
                // addresses_record.time = Clock.currStdTime();
                addresses_record.payload = toAddressTable(node_addresses);
                addresses_record.name = net.calcHash(ADDR_TABLE.representation);
                addresses_record.index = index;
                addresses_record.node = cast(Buffer) pubkey;
                addresses_record.previous = previous;
                return addresses_record;
            }

            const addr_table_fp = net.calcHash(ADDR_TABLE.representation);

            auto addr_table_recorder = loadFromDART([addr_table_fp]);

            auto insert_recorder = rec_factory.recorder;
            auto remove_recorder = rec_factory.recorder;
            NetworkNameRecord ncr;
            NetworkNameCard ncl;
            if (addr_table_recorder.length == 0) {
                ncr = getNetworkNameRecord();
                ncl = NetworkNameCard();
                ncl.name = ADDR_TABLE;
                ncl.pubkey = pubkey;
            }
            else {
                assert(addr_table_recorder.length == 1);
                ncl = NetworkNameCard(addr_table_recorder[].front.filed);
                remove_recorder.remove(Document(ncl.toHiBON.serialize));
                auto ncr_recorder = loadFromDART([ncl.record]);
                if (ncr_recorder.length != 0) {
                    assert(ncr_recorder.length == 1);
                    const prev_ncr = NetworkNameRecord(ncr_recorder[].front.filed);
                    ncr = getNetworkNameRecord(ncl.record, prev_ncr.index + 1);
                }
                else {
                    ncr = getNetworkNameRecord();
                }
            }
            pragma(msg, "fixme(Alex) Here you should use .hashOf because ncr is a HiBON");
            ncl.record = net.hashOf(ncr.toDoc);

            /// Removing previous node addresses
            pragma(msg, "fixme(Alex): Why not just use the maps range instead",
                    " of copying the keys to an array");
            const prev_addresses_recorder = loadFromDART(node_addresses.keys.map!(
                    a => cast(Buffer) net.calcHash(cast(Buffer) a)).array);
            if (prev_addresses_recorder.length > 0) {
                foreach (archive; prev_addresses_recorder[]) {
                    remove_recorder.remove(archive.filed);
                }
            }

            foreach (i, key; node_addresses.keys) {
                auto nnr = NetworkNodeRecord();
                nnr.node = cast(Buffer) key;
                nnr.time = Clock.currStdTime();
                nnr.state = NetworkNodeRecord.State.ACTIVE;
                nnr.address = node_addresses[key].address;
                // nnr.dart_from = 0;
                // nnr.dart_to = 0;
                log("ADDRESS: %s", Document(nnr.toHiBON.serialize).toJSON);
                // log("insert to addr_table_recorder PK: %s HASH: %s", key.cutHex, net.hashOf(Document(nnr.toHiBON().serialize)).cutHex);
                insert_recorder.add(Document(nnr.toHiBON.serialize));
            }
            insert_recorder.add(ncr);
            insert_recorder.add(ncl);
            void updateDART(RecordFactory.Recorder recorder) {
                auto dart_sync_tid = locate(opts.dart.sync.task_name);
                if (dart_sync_tid != Tid.init) {
                    log("modifying dart with: %d archives", recorder.length);
                    recorder.dump();
                    auto sender = DART.dartModify(recorder, internal_hirpc);
                    auto tosend = sender.toDoc.serialize;
                    send(dart_sync_tid, task_name, tosend);
                    receive((Buffer result) { log("Update dart result: %s", cast(string) result); });
                }
                else {
                    log("dart sync not located");
                }
            }

            updateDART(remove_recorder);
            updateDART(insert_recorder);
        }

        auto is_ready = false;
        void receiveAddrBook(ActiveNodeAddressBookPub address_book) {
            //assert(0, "receiveAddrBook should not be used use AddressBook");
            log("updated addr book: %d", address_book.data.length);
            // if (is_ready) {
            //     log("updated addr book internal: %d", address_book.data.length);
            //     update_internal_table(address_book.data);
            //     update_dart(address_book.data);
            // }
            ownerTid.send(address_book);
        }

        Tid bootstrap_tid;

        final switch (opts.net_mode) {
        case NetworkMode.internal:
            bootstrap_tid = spawn(&mdnsDiscoveryService, p2pnode, inner_task_name, opts);
            break;
        case NetworkMode.local:
            bootstrap_tid = spawn(&fileDiscoveryService, pubkey,
                p2pnode.LlistenAddress, inner_task_name, opts);
            break;
        case NetworkMode.pub:
            bootstrap_tid = spawn(&serverFileDiscoveryService, pubkey,
                p2pnode, inner_task_name, opts);
            break;
        }

        scope (exit) {
            bootstrap_tid.send(Control.STOP);
            auto ctrl = receiveOnly!Control;
            assert(ctrl is Control.END);
        }

        auto ctrl = receiveOnly!Control;
        assert(ctrl is Control.LIVE);

        ownerTid.send(Control.LIVE);

        bool stop = false;
        while(!stop) {
            receive(
                &receiveAddrBook,
                (immutable(Pubkey) key, Tid tid) {
                    log("looking for key: %s HASH: %s", key.cutHex, net.calcHash(cast(Buffer) key).cutHex);
                    auto result_addr = internal_nodeaddr_table.get(key, NodeAddress.init);
                    if (result_addr == NodeAddress.init) {
                        log("Address not found in internal nodeaddr table");
                    }
                    tid.send(result_addr);
                },
                (DiscoveryRequestCommand request) {
                    log("send request: %s", request);
                    switch (request) {
                    case DiscoveryRequestCommand.BecomeOnline:
                        is_ready = true;
                        break;
                    case DiscoveryRequestCommand.UpdateTable:
                        assert(0, "Should use the AddressBook");
                        // auto addr_table = request_addr_table();
                        // update_internal_table(addr_table);
                        break;
                    default:
                        break;
                    }
                    bootstrap_tid.send(request);
                },
                (DiscoveryState state) {
                    ownerTid.send(state);
                },
                (Control control) {
                    if (control == Control.STOP) {
                        log("stop");
                        stop = true;
                    }
                });
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

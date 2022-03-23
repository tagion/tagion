module tagion.services.FileDiscoveryService;

import core.time;
import std.datetime;
import std.typecons;
import std.conv;
import std.format;
import std.concurrency;
import std.stdio;

// import tagion.services.LoggerService;
import tagion.services.Options;
import tagion.logger.Logger;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import tagion.basic.TagionExceptions : TagionException, taskException, fatal;
import tagion.services.MdnsDiscoveryService;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import std.file;
import std.file : fwrite = write;
import std.array;
import tagion.services.ServerFileDiscoveryService : DiscoveryRequestCommand, DiscoveryState;
import tagion.gossip.P2pGossipNet;

void fileDiscoveryService(Pubkey pubkey, string node_address, string task_name,
        immutable(Options) opts) nothrow { //TODO: for test
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        string shared_storage = opts.path_to_shared_info;

        log.register(task_name);

        auto stop = false;
        NodeAddress[Pubkey] node_addresses;

        void recordOwnInfo() nothrow {
            try {
                log("record own info");
                auto params = new HiBON;
                params["pkey"] = pubkey;
                params["address"] = node_address;
                shared_storage.append(params.serialize);
                shared_storage.append("/n");
            }
            catch (Exception e) {
                log.error("Exception: %s", e.msg);
                stop = true;
            }
        }

        void eraseOwnInfo() nothrow {
            try {
                log("erase");
                auto read_buff = cast(ubyte[]) shared_storage.read;
                auto splited_read_buff = read_buff.split("/n");
                log("%d", splited_read_buff.length);
                foreach (node_info_buff; splited_read_buff) {
                    if (node_info_buff.length > 0) {
                        auto doc = Document(cast(immutable) node_info_buff);
                        auto pkey_buff = doc["pkey"].get!Buffer;
                        auto pkey = cast(Pubkey) pkey_buff;
                        if (pkey == pubkey) {
                            log("found myself");
                            shared_storage.fwrite(cast(string) read_buff.replace(node_info_buff,
                                    cast(ubyte[]) ""));
                            break;
                        }
                    }
                }
            }
            catch (Exception e) {
                log("Exception: %s", e.msg);
                stop = true;
            }
        }

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

        scope (exit) {
            eraseOwnInfo();
        }

        void initialize() nothrow {
            log("initializing");
            try {
                auto read_buff = cast(ubyte[]) shared_storage.read;
                auto splited_read_buff = read_buff.split("/n");
                foreach (node_info_buff; splited_read_buff) {
                    if (node_info_buff.length > 0) {
                        auto doc = Document(cast(immutable) node_info_buff);
                        import tagion.hibon.HiBONJSON;

                        log("%s", doc.toJSON);
                        auto pkey_buff = doc["pkey"].get!Buffer;
                        auto pkey = cast(Pubkey) pkey_buff;
                        auto addr = doc["address"].get!string;
                        import tagion.utils.Miscellaneous : toHexString, cutHex;

                        auto node_addr = NodeAddress(addr, opts.dart, opts.port_base);
                        node_addresses[pkey] = node_addr;
                        log("added %s", pkey);
                    }
                }
                log("initialized %d", node_addresses.length);
            }
            catch (Exception e) {
                //logwriteln("Er:", e.msg);
                log.fatal(e.msg);
            }
        }

        log("File Discovery started");
        ownerTid.send(Control.LIVE);
        // ownerTid.send(DiscoveryState.READY);

        while (!stop) {
            receiveTimeout(
                    500.msecs,
                    (immutable(Pubkey) key, Tid tid) { log("looking for key: %s", key); tid.send(node_addresses[key]); },
                    (Control control) {
                if (control == Control.STOP) {
                    log("stop");
                    stop = true;
                }
            },
                    (DiscoveryRequestCommand request) {
                with (DiscoveryRequestCommand) {
                    final switch (request) {
                    case BecomeOnline:
                        log("Becoming online..");
                        recordOwnInfo();
                        break;
                    case RequestTable:
                        initialize();
                        auto address_book = new ActiveNodeAddressBook(
                            node_addresses);
                        ownerTid.send(address_book);
                        break;
                    case BecomeOffline:
                        eraseOwnInfo();
                        break;
                    case UpdateTable:
                        throw new TagionException(format("DiscoveryRequestCommand %s has not function", request));
                        break;

                    }
                }
            });
            notifyReadyAfterDelay();

        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

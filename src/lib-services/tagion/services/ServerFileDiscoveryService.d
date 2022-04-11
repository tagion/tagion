module tagion.services.ServerFileDiscoveryService;

import std.stdio;
import core.time;
import std.datetime;
import std.typecons;
import std.conv;
import std.concurrency;
import std.file;
import std.file : fwrite = write;
import std.array;
import p2plib = p2p.node;
import std.net.curl;

// import tagion.services.LoggerService;
import tagion.logger.Logger;
import tagion.basic.Basic : Buffer, Control, nameOf, Pubkey;
import tagion.basic.TagionExceptions : fatal;
import tagion.services.Options;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.gossip.P2pGossipNet;

enum DiscoveryRequestCommand {
    BecomeOnline = 1,
    RequestTable = 2,
    BecomeOffline = 3,
    UpdateTable = 4 // on epoch
}

enum DiscoveryState {
    READY = 1,
    ONLINE = 2,
    OFFLINE = 3
}

void serverFileDiscoveryService(Pubkey pubkey, shared p2plib.Node node,
        string taskName, immutable(Options) opts) nothrow { //TODO: for test
    try {
        scope (exit) {
            log("exit");
            ownerTid.prioritySend(Control.END);
        }

        log.register(taskName);

        if (opts.serverFileDiscovery.url.length == 0) {
            log.error("Server url is missing");
            ownerTid.send(Control.STOP);
            return;
        }

        auto stop = false;
        NodeAddress[Pubkey] node_addresses;

        void recordOwnInfo(string addrs) {
            if (opts.serverFileDiscovery.token) {
                auto params = new HiBON;
                params["pkey"] = pubkey;
                params["address"] = addrs;
                auto doc = Document(params.serialize);
                auto json = doc.toJSON().toString();
                log("posting info to %s \n %s", opts.serverFileDiscovery.url ~ "/node/record", json);
                try {
                    post(opts.serverFileDiscovery.url ~ "/node/record",
                            [
                            "value": json,
                            "token": opts.serverFileDiscovery.token
                            ]);
                }
                catch (Exception e) {
                    log("ERROR on sending: %s", e.msg);
                    ownerTid.send(cast(immutable) e);
                }
            }
            else {
                log("Token missing.. Cannot record own info");
            }
        }

        void eraseOwnInfo() {
            log("posting info to %s", opts.serverFileDiscovery.url ~ "/node/erase");
            post(opts.serverFileDiscovery.url ~ "/node/erase",
                    [
                    "value": (cast(string) pubkey),
                    "tag": opts.serverFileDiscovery.tag
                    ]);
        }

        scope (exit) {
            eraseOwnInfo();
        }

        void initialize() nothrow {
            try {
                auto read_buff = get(
                        opts.serverFileDiscovery.url ~ "/node/storage?tag="
                        ~ opts.serverFileDiscovery.tag);
                auto splited_read_buff = read_buff.split("\n");
                foreach (node_info_buff; splited_read_buff) {
                    if (node_info_buff.length > 0) {
                        import std.json;

                        auto json = (cast(string) node_info_buff).parseJSON;
                        auto hibon = json.toHiBON;
                        auto doc = Document(hibon.serialize);
                        import tagion.hibon.HiBONJSON;

                        auto pkey_buff = doc["pkey"].get!Buffer;
                        auto pkey = cast(Pubkey) pkey_buff;
                        auto addr = doc["address"].get!string;
                        import tagion.utils.Miscellaneous : toHexString, cutHex;

                        auto node_addr = NodeAddress(addr, opts.dart, opts.port_base, true);
                        node_addresses[pkey] = node_addr;
                    }
                }
                log("initialized %d", node_addresses.length);
            }
            catch (Exception e) {
                fatal(e);
            }
        }

        auto addr_changed_tid = spawn(&handleAddrChanedEvent, node);
        receive((Control ctrl) { assert(ctrl == Control.LIVE); });

        auto rechability_changed_tid = spawn(&handleRechabilityChanged, node);
        receive((Control ctrl) { assert(ctrl == Control.LIVE); });
        scope (exit) {
            {
                addr_changed_tid.send(Control.STOP);
                auto ctrl = receiveOnly!Control;
                assert(ctrl == Control.END);
            }
            {
                rechability_changed_tid.send(Control.STOP);
                auto ctrl = receiveOnly!Control;
                assert(ctrl == Control.END);
            }
        }

        auto substoaddrupdate = node.SubscribeToAddressUpdated("addr_changed_handler");
        auto substorechability = node.SubscribeToRechabilityEvent("rechability_handler");
        scope (exit) {
            substoaddrupdate.close();
            substorechability.close();
        }

        string last_seen_addr = "";
        bool is_online = false;
        bool is_ready = false;

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
                if (after_delay && is_online && is_ready) {
                    ownerTid.send(DiscoveryState.READY);
                    owner_notified = true;
                }
            }
        }

        ownerTid.send(Control.LIVE);

        do {
            receiveTimeout(500.msecs, (immutable(Pubkey) key, Tid tid) {
                import tagion.utils.Miscellaneous : toHexString, cutHex;

                log("looking for key: %s", key.cutHex);
                tid.send(node_addresses[key]);
            }, (Control control) {
                if (control == Control.STOP) {
                    log("stop");
                    stop = true;
                }
            }, (string updated_address) {
                last_seen_addr = updated_address;
                if (is_online) {
                    recordOwnInfo(updated_address);
                    is_ready = true;
                }
            }, (DiscoveryRequestCommand cmd) {
                switch (cmd) {
                case DiscoveryRequestCommand.BecomeOnline: {
                        log("Becoming online..");
                        is_online = true;
                        if (last_seen_addr != "") {
                            recordOwnInfo(last_seen_addr);
                            is_ready = true;
                        }
                        break;
                    }
                case DiscoveryRequestCommand.RequestTable: {
                        initialize();
                        auto address_book = new ActiveNodeAddressBookPub(node_addresses);
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
            });
            notifyReadyAfterDelay();
        }
        while (!stop);
    }
    catch (Throwable t) {
        fatal(t);
    }
}

void handleAddrChanedEvent(shared p2plib.Node node) nothrow {
    try {
        register("addr_changed_handler", thisTid);
        ownerTid.send(Control.LIVE);
        scope (exit) {
            log("stop");
            ownerTid.prioritySend(Control.END);
        }
        auto stop = false;
        do {
            receive((immutable(ubyte)[] data) {
                auto pub_addr = node.PublicAddress;
                writefln("Addr changed %s", pub_addr);
                if (pub_addr.length > 0) {
                    auto addrinfo = node.AddrInfo();
                    ownerTid.send(addrinfo);
                }
            }, (Control control) {
                if (control == Control.STOP) {
                    log("stop");
                    stop = true;
                }
            });
        }
        while (!stop);
    }
    catch (Throwable t) {
        log("ERROR: %s", t.msg);
        fatal(t);
    }

}

void handleRechabilityChanged(shared p2plib.Node node) nothrow {
    try {

        register("rechability_handler", thisTid);
        ownerTid.send(Control.LIVE);
        scope (exit) {
            log("stop");
            ownerTid.prioritySend(Control.END);
        }
        auto stop = false;
        do {
            receive((immutable(ubyte)[] data) {
                writefln("RECHABILITY CHANGED: %s", cast(string) data);
                auto pub_addr = node.PublicAddress;
                writefln("Addr changed %s", pub_addr);
                if (pub_addr.length > 0) {
                    auto addrinfo = node.AddrInfo();
                    ownerTid.send(addrinfo);
                }
            }, (Control control) {
                if (control == Control.STOP) {
                    log("stop");
                    stop = true;
                }
            });
        }
        while (!stop);
    }
    catch (Throwable t) {
        log("ERROR: %s", t.msg);
        fatal(t);
    }
}

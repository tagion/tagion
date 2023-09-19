module tagion.prior_services.ServerFileDiscoveryService;

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

// import tagion.prior_services.LoggerService;
import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control;
import tagion.crypto.Types : Pubkey;
import tagion.actor.exceptions : fatal;
import tagion.basic.tagionexceptions : TagionException;

import tagion.prior_services.Options;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.prior_services.NetworkRecordDiscoveryService : DiscoveryRequestCommand, DiscoveryControl;

//import tagion.gossip.P2pGossipNet : ActiveNodeAddressBook;
import tagion.gossip.AddressBook : NodeAddress;

alias ActiveNodeAddressBookX = immutable(AddressBook_deprecation);

@safe
immutable class AddressBook_deprecation {
    this(const(NodeAddress[Pubkey]) addrs) @trusted {
        //        addressbook.overwrite(addrs);
        //         this.data = cast(immutable) addrs.dup;
    }

    //    immutable(NodeAddress[Pubkey]) data;

    static immutable(NodeAddress[Pubkey]) data() @trusted {
        immutable(NodeAddress[Pubkey]) empty;
        return empty;
    }

}

void serverFileDiscoveryService(
        Pubkey pubkey,
        shared p2plib.Node node,
        string taskName,
        immutable(Options) opts) nothrow { //TODO: for test
    try {
        scope (success) {
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
            auto params = new HiBON;
            params["pkey"] = pubkey;
            params["address"] = addrs;
            auto doc = Document(params.serialize);
            auto json = doc.toJSON().toString();
            log("Posting info to %s \n %s", opts.serverFileDiscovery.url ~ "/node/record", json);
            try {
                post(opts.serverFileDiscovery.url ~ "/node/record",
                        [
                    "value": json,
                ]);
            }
            catch (TagionException e) {
                fatal(e);
            }
        }

        void eraseOwnInfo() {
            log("Posting info to %s", opts.serverFileDiscovery.url ~ "/node/erase");
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

                        auto node_addr = NodeAddress(addr, opts.port_base, true);
                        node_addresses[pkey] = node_addr;
                    }
                }
            }
            catch (Exception e) {
                fatal(e);
            }
        }

        auto addr_changed_tid = spawn(&handleAddrChanedEvent, node);
        receive((Control ctrl) { assert(ctrl is Control.LIVE); });

        auto rechability_changed_tid = spawn(&handleRechabilityChanged, node);
        receive((Control ctrl) { assert(ctrl is Control.LIVE); });
        scope (exit) {
            {
                addr_changed_tid.send(Control.STOP);
                auto ctrl = receiveOnly!Control;
                assert(ctrl is Control.END);
            }
            {
                rechability_changed_tid.send(Control.STOP);
                auto ctrl = receiveOnly!Control;
                assert(ctrl is Control.END);
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
                    ownerTid.send(DiscoveryControl.READY);
                    owner_notified = true;
                }
            }
        }

        ownerTid.send(Control.LIVE);

        do {
            receiveTimeout(500.msecs, (immutable(Pubkey) key, Tid tid) {
                import tagion.utils.Miscellaneous : toHexString, cutHex;

                tid.send(node_addresses[key]);
            }, (Control control) {
                if (control == Control.STOP) {
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
                        auto address_book = new ActiveNodeAddressBookX(node_addresses);
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
                    stop = true;
                }
            });
        }
        while (!stop);
    }
    catch (Throwable t) {
        fatal(t);
    }

}

void handleRechabilityChanged(shared p2plib.Node node) nothrow {
    try {

        register("rechability_handler", thisTid);
        ownerTid.send(Control.LIVE);
        scope (exit) {
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
                    stop = true;
                }
            });
        }
        while (!stop);
    }
    catch (Throwable t) {
        fatal(t);
    }
}

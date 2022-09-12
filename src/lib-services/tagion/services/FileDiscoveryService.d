module tagion.services.FileDiscoveryService;

import core.time;
import std.format;
import std.concurrency;
import std.file;

import p2plib = p2p.node;
import tagion.utils.Miscellaneous : cutHex;
import tagion.services.Options;
import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control, Pubkey;
import tagion.basic.Basic : nameOf;
import tagion.basic.TagionExceptions : TagionException, fatal;
import tagion.services.MdnsDiscoveryService;

import tagion.services.NetworkRecordDiscoveryService : DiscoveryRequestCommand, DiscoveryControl;
import tagion.gossip.AddressBook : addressbook, NodeAddress;

void fileDiscoveryService(
    Pubkey pubkey,
    shared p2plib.Node node,
    string task_name,
    immutable(Options) opts) nothrow
{ //TODO: for test
    try
    {
        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);

        string shared_storage = opts.path_to_shared_info;

        bool stop = false;

        void initialize()
        {
            static uint count;
            count++;
            log("initializing %d %s", count, pubkey.cutHex);
            addressbook.load(shared_storage, false);
            addressbook.erase(pubkey);
            addressbook[pubkey] = NodeAddress(node.LlistenAddress, opts.dart, opts.port_base);
            addressbook.save(shared_storage, true);
        }

        void updateAddressbook()
        {
            static uint count;
            count++;
            log.trace("update %d %s", count, pubkey.cutHex);
            addressbook.load(shared_storage, true);
        }

        initialize;
        log("File Discovery started");
        ownerTid.send(Control.LIVE);
        bool addressbook_done;
        while (!stop)
        {
            const message = receiveTimeout(
                500.msecs,
                (Control control) {
                if (control is Control.STOP)
                {
                    log("stop");
                    stop = true;
                }
            },
                (DiscoveryRequestCommand request) {
                with (DiscoveryRequestCommand)
                {
                    final switch (request)
                    {
                    case RequestTable:
                        addressbook_done = false;
                        break;
                    case BecomeOnline:
                    case BecomeOffline:
                        break;
                    case UpdateTable:
                        throw new TagionException(format("DiscoveryRequestCommand %s has not function", request));
                        break;

                    }
                }
            }
            );
            if (!addressbook_done)
            {
                if (!message)
                {
                    updateAddressbook;
                }
                log.trace("FILE NETWORK READY %d < %d (%s) done = %s", addressbook.numOfNodes, opts.nodes, addressbook
                        .isReady, addressbook_done);
                if (addressbook.isReady)
                {
                    ownerTid.send(DiscoveryControl.READY);
                    addressbook_done = true;
                }
            }
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}

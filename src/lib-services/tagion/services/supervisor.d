/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import core.time;
import std.file;
import std.path;
import std.stdio;
import std.typecons;
import std.format;
import std.range;

import tagion.GlobalSignals : stopsignal;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types;
import tagion.crypto.SecureNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.wave.common;
import tagion.script.common;
import tagion.logger.Logger;
import tagion.gossip.AddressBook;
import tagion.services.DART;
import tagion.services.rpcserver;
import tagion.services.TVM;
import tagion.services.collector;
import tagion.services.epoch_creator;
import tagion.services.hirpc_verifier;
import tagion.services.options;
import tagion.services.replicator;
import tagion.services.epoch_commit;

version (NEW_TRANSCRIPT) {
    import tagion.services.trans;
}
else {
    import tagion.services.transcript;
}
import tagion.services.TRTService;
import tagion.services.nodeinterface;
import tagion.services.mode0_nodeinterface;
import tagion.services.messages;
import tagion.services.exception;

@safe
struct Supervisor {
    enum failHandler_ = (TaskFailure tf) @safe nothrow{
        log.error("%s", tf);

        if (cast(immutable(ServiceError)) tf.throwable !is null) {
            thisActor.stop = true;
        }
        else {
            sendOwner(tf);
        }
    };

    static assert(isFailHandler!(typeof(failHandler_)));

    void task(immutable(Options) opts, shared(SecureNet) shared_net) @safe {
        immutable tn = opts.task_names;
        const local_net = shared_net.clone;


        shared(AddressBook) addressbook = new shared(AddressBook);
        { // Set addressbook
            Exception dart_exception;
            DART db = new DART(local_net.hash, opts.dart.dart_path, dart_exception, Yes.read_only);
            scope(exit) db.close();
            if (dart_exception !is null) {
                throw dart_exception;
            }

            TagionHead head = TagionHead(); // getHead(db);
            GenericEpoch epoch = getEpoch(head, db);
            log("Booting with Epoch %J", epoch);
            auto keys = getNodeKeys(epoch);
            if (!opts.wave.address_file.empty) {
                /* addressbook = File(opts.wave.address_file, "r").byLine.parseAddressFile; */
            }
            else {
                addressbook = readNNRFromDart(db, keys, local_net.hash);
            }

            foreach (key; keys) {
                check(addressbook.exists(key), format("No address for node with pubkey %s", key.encodeBase64));
            }
        }

        ActorHandle[] handles;

        ActorHandle replicator_handle = spawn!ReplicatorService(tn.replicator, opts.replicator);
        handles ~= replicator_handle;
        ActorHandle dart_handle = spawn!DARTService(tn.dart, opts.dart, shared_net);
        handles ~= dart_handle;

        ActorHandle trt_handle;
        if (opts.trt.enable) {
            trt_handle = spawn!TRTService(tn.trt, opts.trt, tn, shared_net);
            handles ~= trt_handle;
        }

        handles ~= spawn!HiRPCVerifierService(tn.hirpc_verifier, opts.hirpc_verifier, tn);

        ActorHandle node_interface_handle;
        final switch (opts.wave.network_mode) {
        case NetworkMode.INTERNAL:
            node_interface_handle = _spawn!Mode0NodeInterfaceService(
                    tn.node_interface,
                    shared_net,
                    addressbook,
                    tn,
            );
            break;
        case NetworkMode.LOCAL,
            NetworkMode.MIRROR:
            node_interface_handle = _spawn!NodeInterfaceService(
                    tn.node_interface,
                    opts.node_interface,
                    shared_net,
                    addressbook,
                    tn.epoch_creator
            );
            break;
        }
        handles ~= node_interface_handle;

        // signs data
        handles ~= spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, shared_net, addressbook, tn);

        // verifies signature
        handles ~= _spawn!CollectorService(tn.collector, tn);

        handles ~= _spawn!TVMService(tn.tvm, tn);
        handles ~= _spawn!EpochCommit(tn.epoch_commit, dart_handle, replicator_handle, trt_handle);

        // signs data
        auto transcript_handle = _spawn!TranscriptService(
                tn.transcript,
                opts.wave.number_of_nodes,
                shared_net,
                tn,
        );

        handles ~= transcript_handle;

        handles ~= spawn(immutable(RPCServer)(opts.rpcserver, opts.trt, tn), tn.rpcserver);

        version(none)
        foreach(channel; addressbook.keys) {
            try {
                import tagion.dart.DARTcrud;
                import tagion.hibon.Document;
                import tagion.utils.pretend_safe_concurrency;
                node_interface_handle.send(NodeReq(), channel, dartBullseye().toDoc);
                receive((NodeReq.Response _, Document doc) { log("%s", doc.toPretty); });
            } catch(Exception e) { log.fatal(e); }
        }

        run(
                (EpochShutdown m, long shutdown_) { //
            transcript_handle.send(m, shutdown_);
        },
                failHandler_,
        );

        log("Supervisor stopping services");
        foreach (handle; handles) {
            handle.prioritySend(Sig.STOP);
        }

        waitforChildren(Ctrl.END, 10.seconds);
        log("All services stopped");
    }
}

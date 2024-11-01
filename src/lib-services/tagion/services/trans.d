/// New Service for Transcript responsible for creating recorder for DART 
/// [DART Documentation](https://docs.tagion.org/tech/architecture/transcript)
module tagion.services.trans;

import core.time;
import std.algorithm;
import std.array;
import std.exception;
import std.format;
import std.range;
import std.stdio;
import tagion.actor.actor;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.dart.DARTBasic;
import tagion.dart.Recorder;
import tagion.hashgraph.HashGraphBasic : EventPackage, isMajority;
import tagion.hibon.BigNumber;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : HiBONRecord, isRecord;
import tagion.logger.Logger;
import tagion.logger.Logger;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute : ContractProduct;
import tagion.script.standardnames;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.services.exception;
import tagion.json.JSONRecord;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;
import std.path : buildPath;
import std.file : exists;
import std.conv : to;
import tagion.logger.ContractTracker;
import tagion.services.transcript : TranscriptOptions, BUFFER_TIME_SECONDS;

@safe:

struct TranscriptService {
    const(SecureNet) net;
    immutable(TranscriptOptions) opts;

    immutable(size_t) number_of_nodes;

    
    ActorHandle dart_handle;
    ActorHandle epoch_creator_handle;
    ActorHandle trt_handle;
    bool trt_enable;

    RecordFactory rec_factory;

}

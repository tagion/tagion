/// Contains all the HiRPC DART crud commands
module tagion.dart.DARTcrud;

import std.range : isInputRange, ElementType;
import std.algorithm.iteration : filter;

import tagion.communication.HiRPC;
import tagion.hibon.HiBON : HiBON;
import tagion.dart.DART : DART;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.basic.Types : Buffer, isBufferType;
/**
       * Constructs a HiRPC method for dartRead 
       * Params:
       *   fingerprints = List of hash-pointers 
       *   hirpc = HiRPC credentials 
       *   id = HiRPC id 
       * Returns: 
       *   HiRPC Sender
       */
const(HiRPC.Sender) dartRead(Range)(
        Range fingerprints,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) @safe if (isInputRange!Range && is(ElementType!Range : const(DARTIndex))) {
    auto params = new HiBON;
    auto params_fingerprints = new HiBON;
    params_fingerprints = fingerprints.filter!(b => b.length !is 0);
    params[DART.Params.fingerprints] = params_fingerprints;
    return hirpc.dartRead(params, id);
}

const(HiRPC.Sender) dartCheckRead(Range)(
        Range fingerprints,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) @safe if (isInputRange!Range && is(ElementType!Range : const(DARTIndex))) {

    auto params = new HiBON;
    auto params_fingerprints = new HiBON;
    params_fingerprints = fingerprints.filter!(b => b.length !is 0);
    params[DART.Params.fingerprints] = params_fingerprints;
    return hirpc.dartCheckRead(params, id);
}

/**
        * Constructs a HiRPC method for dartRim
        * Params:
        *   rims = rim-path to the DART sub-tree
        *   hirpc = HiRPC credentials
        *   id = HiRPC id
        * Returns: 
        *   HiRPC sender
        */
const(HiRPC.Sender) dartRim(
        ref const DART.Rims rims,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) @safe {
    return hirpc.dartRim(rims, id);
}

/**
        * Constructs a HiRPC method for dartModify
        * Params:
        *   recorder = recoreder of archives
        *   hirpc = HiRPC credentials
        *   id = HiRPC id
        * Returns: 
        *   HiRPC sender
        */
const(HiRPC.Sender) dartModify(
        ref const RecordFactory.Recorder recorder,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) @safe {
    return hirpc.dartModify(recorder, id);
}

/**
         * Constructs a HiRPC method for the dartBullseye 
         * Params:
         *   hirpc = HiRPC credentials
         *   id = HiRPC id
         * Returns: 
         *   HiRPC sender
         */
const(HiRPC.Sender) dartBullseye(
        HiRPC hirpc = HiRPC(null),
        uint id = 0) @safe {
    return hirpc.dartBullseye(null, id);
}

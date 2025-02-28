/// Contains all the HiRPC DART crud commands
module tagion.dart.DARTcrud;

@safe:

import std.algorithm.iteration : filter;
import std.range : ElementType, isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.communication.HiRPC;
import tagion.dart.DARTBasic : DARTIndex, Params;
import tagion.dart.DARTRim;
import tagion.dart.Recorder;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

/**
 * Constructs a HiRPC method for dartRead 
 * Params:
 *   dart_indices = List of hash-pointers 
 *   hirpc = HiRPC credentials 
 *   id = HiRPC id 
 * Returns: 
 *   HiRPC Sender
*/
const(HiRPC.Sender) dartRead(Range)(Range dart_indices, HiRPC hirpc = HiRPC(null), uint id = 0) {
    return dartIndexCmd("dartRead", dart_indices, hirpc, id);
}

/**
 * Constructs a HiRPC method for dartCheckRead 
 * Params:
 *   dart_indices = List of hash-pointers 
 *   hirpc = HiRPC credentials 
 *   id = HiRPC id 
 * Returns: 
 *   HiRPC Sender
*/
const(HiRPC.Sender) dartCheckRead(Range)(Range dart_indices, HiRPC hirpc = HiRPC(null), uint id = 0) {
    return dartIndexCmd("dartCheckRead", dart_indices, hirpc, id);
}

/// General constructor for a dart index cmd [dartRead, dartCheckRead, trt.dartRead, etc...]
/// With a runtime method name
const(HiRPC.Sender) dartIndexCmd(Range)(
        string method,
        Range dart_indices,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) if (isInputRange!Range && is(ElementType!Range : const(DARTIndex))) {

    auto params = new HiBON;
    auto params_dart_indices = new HiBON;
    params_dart_indices = dart_indices.filter!(b => b.length !is 0);
    params[Params.dart_indices] = params_dart_indices;
    return hirpc.action(method, params, id);
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
        ref const Rims rims,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) {
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
        uint id = 0) {
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
        uint id = 0) {
    return hirpc.dartBullseye(Document(), id);
}

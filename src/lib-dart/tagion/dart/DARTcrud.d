/// Contains all the HiRPC DART crud commands
module tagion.dart.DARTcrud;

import std.algorithm.iteration : filter;
import std.range : ElementType, isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.communication.HiRPC;
import tagion.dart.DARTBasic : DARTIndex, Params;
import tagion.dart.DARTRim;
import tagion.dart.Recorder;
import tagion.hibon.HiBON : HiBON;

/**
 * Constructs a HiRPC method for dartRead 
 * Params:
 *   dart_indices = List of hash-pointers 
 *   hirpc = HiRPC credentials 
 *   id = HiRPC id 
 * Returns: 
 *   HiRPC Sender
*/
alias dartRead = _dartIndexCmd!"dartRead";
/// ditto
alias dartCheckRead = _dartIndexCmd!"dartCheckRead";
/// ditto
alias trtdartRead = _dartIndexCmd!"trt.dartRead";
/// ditto
alias trtdartCheckRead = _dartIndexCmd!"trt.dartCheckRead";

template _dartIndexCmd(string method) {
    const(HiRPC.Sender) _dartIndexCmd(Range)(
            Range dart_indices,
            HiRPC hirpc = HiRPC(null),
            uint id = 0) @safe if (isInputRange!Range && is(ElementType!Range : const(DARTIndex))) {

        auto params = new HiBON;
        auto params_dart_indices = new HiBON;
        params_dart_indices = dart_indices.filter!(b => b.length !is 0);
        params[Params.dart_indices] = params_dart_indices;
        return hirpc.opDispatch!method(params, id);
    }
}

/// General constructor for a dart index cmd [dartRead, dartCheckRead, etc...]
/// With a runtime method name
const(HiRPC.Sender) dartIndexCmd(Range)(
        string method,
        Range dart_indices,
        HiRPC hirpc = HiRPC(null),
        uint id = 0) @safe if (isInputRange!Range && is(ElementType!Range : const(DARTIndex))) {

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

module tagion.script.methods;

@safe:

import std.range : ElementType, isInputRange;
import std.array;
import std.algorithm : map;

import tagion.communication.HiRPC;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;
import tagion.hashgraph.HashGraphBasic;
public import tagion.dart.DARTcrud : dartRead, dartBullseye, dartCheckRead, dartBullseye, dartRim, dartIndexCmd, dartModify;

enum RPCMethods {
    readRecorder = "readRecorder",

    dartBullseye = "dartBullseye",
    dartRead = "dartRead",
    dartCheckRead = "dartCheckRead",
    dartRim = "dartRim",

    /// Internal method for making changes to the DB
    dartModify = "dartModify",

    /// Submit a contract to the network
    submit = "submit",

    /// deprecated trt method
    search = "search",

    /// Node to Node wavefront exchange
    wavefront = "wavefront",

    /// Shell development method for requesting bills to a wallet
    faucet = "faucet"
}

static immutable(string[]) public_dart_methods = [
    RPCMethods.dartRead,
    RPCMethods.dartRim,
    RPCMethods.dartBullseye,
    RPCMethods.dartCheckRead,
];

static immutable(string[]) public_trt_methods = public_dart_methods.map!(m => "trt." ~ m).array ~ RPCMethods.search;
static immutable(string[]) all_public_methods = public_dart_methods ~ public_trt_methods ~ RPCMethods.readRecorder ~ RPCMethods.submit;

struct EpochParam {
    @label(StdNames.epoch_number) long epoch_number;
    mixin HiBONRecord;
}

// replicatorRead
const(HiRPC.Sender) readRecorder( 
    long epoch_number,
    HiRPC hirpc = HiRPC(null),
    uint id = 0) {
    
    auto params = EpochParam(epoch_number);
    return hirpc.opDispatch!(RPCMethods.readRecorder)(params, id);
}

const(HiRPC.Sender) submit(SignedContract s_contract, HiRPC hirpc = HiRPC(null), uint id = 0) {
    return hirpc.opDispatch!(RPCMethods.submit)(s_contract, id);
}

const(HiRPC.Sender) wavefront(Wavefront wavefront, HiRPC hirpc = HiRPC(null), uint id = 0) {
    return hirpc.opDispatch!(RPCMethods.wavefront)(wavefront, id);
}

const(HiRPC.Sender) faucet(TagionBill[] bills, HiRPC hirpc = HiRPC(null), uint id = 0) {
    auto h = new HiBON();
    h[StdNames.values] = bills;
    return hirpc.opDispatch!(RPCMethods.faucet)(h, id);
}

module tagion.services.rpcs;

import std.algorithm;
import std.array;

import tagion.dart.DARTBasic;

@safe:

/// Accepted methods for the DART.
static immutable(string[]) accepted_dart_methods = [
    Queries.dartRead,
    Queries.dartRim,
    Queries.dartBullseye,
    Queries.dartCheckRead,
];

static immutable(string[]) accepted_rep_methods = [
    "readRecorder",
];

static immutable(string[]) input_methods = [
    "submit",
];

pragma(msg, "deprecated search method should be removed from trt");
/// All methods allowed for the TRT
static immutable(string[]) accepted_trt_methods = accepted_dart_methods.map!(
    m => "trt." ~ m).array ~ "search";
/// All allowed methods for the RPCServer
static immutable all_public_rpc_methods = accepted_dart_methods ~ accepted_trt_methods ~ accepted_rep_methods ~ input_methods;

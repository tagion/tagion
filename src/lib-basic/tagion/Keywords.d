module tagion.Keywords;

private import tagion.basic.basic : EnumText;

// Keyword list for the HiBON packages
protected enum _keywords = [
        // dfmt off
    "pubkey",       // Pubkey
    "signature",        // signature of the block
//    "altitude",   // altitude
    "received_order",
    // "tidewave",
    // "wavefront",  // Wave front is the list of events hashs
//    "ebody",      // Event body
//    "event",      // Event including the eventbody

    // HashGraph
    "message",
    "mother",
    "father",
    "daughter",
    "son",
    "payload",
    "channel",
    "witness",
    // "witness_mask",
    "round_mask",
    "round_seen",
    "round_received",
    "coin",
    "decided",
    "decided_count",
//    "total",
//    "decided_mask",
    "famous",
    "famous_votes",
    "round",
    "number",
    "remove",
    "forked",
    "strongly_seeing",
    "strong_votes",
    "strong_mask",
    "iterations",
//    "altenative",
    "looked_at_mask",
    "looked_at_count",
    "seeing_completed",
    "completed",
    "epoch",
    "list",
    "time",
    "events",     // List of event
    "type",       // Package type
//    "block",     // block

    "rim",
    "buckets",
    "tab",
    "transaction_id",
    "output",
    "signatures",
//    "signatur",
    "transaction_object",
    "transaction_scripting_object",
    "payers",
    "payees",
    "input_bills",
    "output_bills",
    "bill",
    "bill_number",
    "bill_body",
    "bill_type",
    "value",
    "ownerkey",

    // FixMe should be change to "result" and "error" to fit the HiRPC
    "result_code",
    "error_code",

    // Scripting
    "code",
    "source",

    // DART
//    "indices",
    "fingerprint",
//    "fingerprints",
    "archives",
    "branches",
    "read",
    "rims",
    "keys",

    // HiRPC (Similar to JSON-RPC 2.0)
//    "rev",
    "method",
    "params",
    "error", // error_code
    "result",
    "id", //
    "data",
    "hirpc"
    // dfmt on
    ];

// Generated the Keywords and enum string list
mixin(EnumText!("Keywords", _keywords));

// protected enum _network_modes = ["internal", "local", "pub"];
import std.array : join;

// enum ValidNetwrokModes = join(_network_modes, ",");
// mixin(EnumText!("NetworkMode", _network_modes));
/++
 Check if the CTE string $(LREF word) belongs to $(LREF K) string enum
+/
template isValid(K, string word) if (is(K == enum)) {
    enum code = "K." ~ word;
    enum isValid = __traits(compiles, mixin(code));
}

static unittest {
    import std.traits : EnumMembers;

    enum allkeys = EnumMembers!Keywords;
    enum kmin = allkeys[0];
    enum kmax = allkeys[$ - 1];
    enum kmid = allkeys[$ / 2];
    static assert(isValid!(Keywords, kmin));
    static assert(isValid!(Keywords, kmax));
    static assert(isValid!(Keywords, kmid));
    static assert(!isValid!(Keywords, "xxx"));
}

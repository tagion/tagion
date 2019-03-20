module tagion.Keywords;

private import tagion.Base : EnumText;

// Keyword list for the BSON packages
enum _keywords = [
    "pubkey",       // Pubkey
    "signature",        // signature of the block
    "altitude",   // altitude
    "received_order",
    "tidewave",
    "wavefront",  // Wave front is the list of events hashs
    "ebody",      // Event body
    "event",      // Event including the eventbody

    // HashGraph
    "message",
    "mother",
    "father",
    "daughter",
    "son",
    "payload",
    "channel",
    "witness",
    "witness_mask",
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
    "altenative",
    "looked_at_mask",
    "looked_at_count",
    "seeing_completed",
    "completed",
    "epoch",
    "list",
    "time",
    "events",     // List of event
    "type",       // Package type
    "block",     // block

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

    // FixMe should be change to "result" and "error" to fit the HBSON-RPC
    "result_code",
    "error_code",

    // Scripting
    "code",
    "source",

    // DART
    "indices",
    "fingerprint",
    "fingerprints",
    "archives",
    "branches",
    "read",
    "rims",
    "keys",
    "stub",

    // HBSON-RPC (Similar to JSON-RPC 2.0)
    "method",
    "params",
    "error", // error_code
    "result",
    "id", //
    "hrpc"
    ];

// Generated the Keywords and enum string list
mixin(EnumText!("Keywords", _keywords));

bool validate(Keywords keyword=Keywords.min)(immutable(string) word) {
    static if ( keyword <= Keywords.max ) {
        if ( keyword == word ) {
            return true;
        }
        return validate(keyword++)(word);
    }
    return false;
}

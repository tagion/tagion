/**
The standard result types from a BDD
*/
module tagion.behaviour.BehaviourResult;

public import tagion.communication.HiRPC : ResultOk;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import std.typecons : Yes;

static Document result_ok = result(ResultOk()).toDoc; /// This

/** 
 * Contains the Exception information  
*/
@safe
@recordType("BDDError")
struct BehaviourError {
    string msg; ///  Error message in the Exception
    string[] trace; ///. Exception line trace of in the exception
    ulong line; 
    string file;
    alias enable_serialize = bool;
    mixin HiBONRecord!(q{
            this(Throwable e) nothrow @trusted {
                import std.exception : assumeWontThrow;
                import std.stdio;
                import std.string : splitLines;
                msg = e.msg;
                trace = assumeWontThrow(e.toString.splitLines);
                line = e.line;
                file = e.file;
            }
        });
}

/**
 * Stores the result from a BDD Action, Senario or Feature
 */
@safe
@recordType("BDDResult", null, Yes.disable_serialize)
struct Result {
    Document outcome; /// BDD test return document
    alias enable_serialize = bool;
    mixin HiBONRecord!();
}

/** 
 * 
 * Params:
 *   doc = to encapsulated in the result
 * Returns: document wrapped as a Result
 */
@safe
Result result(const Document doc) nothrow {
    Result result;
    result.outcome = Document(doc.data);
    return result;
}

/**
 * ditto but takes a HiBONRecord instead of a Document
 */
@safe
Result result(T)(T hibon_record) if (isHiBONRecord!T) {
    return result(hibon_record.toDoc);
}

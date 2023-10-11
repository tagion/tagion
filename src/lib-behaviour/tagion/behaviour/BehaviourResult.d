/**
The standard result types from a BDD
*/
module tagion.behaviour.BehaviourResult;

import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
public import tagion.communication.HiRPC: ResultOk;

static Document result_ok = result(ResultOk()).toDoc; /// This

/** 
 * Contains the Exception information  
*/
@safe
@recordType("BDDError")
struct BehaviourError {
    string msg; ///  Error message in the Exception
    string[] trace; ///. Exception line trace of in the exception
    mixin HiBONRecord!(q{
            this(Throwable e) nothrow @trusted {
                import std.exception : assumeWontThrow;
                import std.string : splitLines;
                import std.stdio;
                msg =e.msg;
                trace= assumeWontThrow(e.toString.splitLines);
            }
        });
}

/**
 * Stores the result from a BDD Action, Senario or Feature
 */
@safe
@recordType("BDDResult")
struct Result {
    Document outcome; /// BDD test return document
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

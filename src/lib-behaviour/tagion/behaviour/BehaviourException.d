/// \file BehaviourException.d
module tagion.behaviour.BehaviourException;

import tagion.basic.TagionExceptions;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document : Document;

/**
 * \class BehaviourException
 * Exception type used by tagion.hibon.HiBON module
 */
@safe class BehaviourException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}

/** Check function used in the behaviour package */
alias check = Check!(BehaviourException);

/** 
 * Contains the Exception information  
*/

/**
 * \struct BehaviourError
 * Behaviour Error struct
 */
@safe @RecordType("BDDError")
struct BehaviourError
{
    /** Error message in the Exception */
    string msg;
    /** Exception line trace of in the exception */
    string[] trace;
    mixin HiBONRecord!(q{
            this(Exception e) nothrow @trusted {
                import std.exception : assumeWontThrow;
                import std.string : splitLines;
                import std.stdio;
                msg =e.msg;
                trace= assumeWontThrow(e.toString.splitLines);
            }
        });
}

/**
 * \struct Result
 * Struct for store BDD result
 */
@safe @RecordType("BDDResult")
struct Result
{
    /** BDD test return document */
    Document outcome;
    mixin HiBONRecord!();
}

/** 
 * Used to get document result 
 * @param doc - to encapsulated in the result
 * @return document wrapped as a Result
 */
@safe Result result(const Document doc) nothrow
{
    Result result;
    result.outcome = Document(doc.data);
    return result;
}

/** 
 * Used to get document result 
 * @param hibon_record - to encapsulated in the result
 * @return document wrapped as a Result
 */
@safe Result result(T)(T hibon_record) if (isHiBONRecord!T)
{
    return result(hibon_record.toDoc);
}

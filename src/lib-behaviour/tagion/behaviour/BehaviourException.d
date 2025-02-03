/**
Exception use by the BDD runtime
*/
module tagion.behaviour.BehaviourException;

import tagion.basic.Debug;
import tagion.errors.tagionexceptions;
import tagion.hibon.HiBONRecord;


/**
 Exception type used by tagion.hibon.HiBON module
 */
@safe class BehaviourException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
        version(unittest) {} else __write("BDDERROR: %s %s %s", msg, file, line);
    }
}

/// check function used in the behaviour package
alias check = Check!(BehaviourException);

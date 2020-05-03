module tagion.hibon.HiBONException;
import tagion.TagionExceptions : Check, TagionException;

/++
 Exception type used by tagion.hibon.HiBON module
 +/
@safe
class HiBONException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

/// check function used in the HiBON package
alias check=Check!HiBONException;

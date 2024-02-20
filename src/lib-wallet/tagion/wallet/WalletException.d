/** 
* Exception used in the wallet
*/
module tagion.wallet.WalletException;

import tagion.basic.tagionexceptions;

/**
 * Exception type used in the Script package
 */
@safe
class WalletException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/**
 * Exception type used by for key-recovery module
 */
@safe
class KeyRecoverException : WalletException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

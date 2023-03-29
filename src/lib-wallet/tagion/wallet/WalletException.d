/** 
* Exception used in teh wallet
*/
module tagion.wallet.WalletException;

import tagion.basic.TagionExceptions : TagionException, Check;

/**
 * Exception type used in the Script package
 */
@safe
class WalletException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!(WalletException);

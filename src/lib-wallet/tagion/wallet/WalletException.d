module tagion.wallet.WalletException;

import tagion.basic.TagionExceptions : TagionException, Check;

/**
 * Exception type used in the Script package
 */
@safe
class WalletException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        super(msg, file, line);
    }
}

/// check function used in the Script package
alias check = Check!(WalletException);

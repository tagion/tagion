module tagion.dart.DARTException;

import tagion.basic.TagionExceptions : TagionException;

/**
 * Exception type used by tagion.dart.BlockFile module
 */
@safe
class BlockFileException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        super(msg, file, line);
    }
}

/++
 + Excection used in the DART
 +/
@safe
class DARTException : BlockFileException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        super(msg, file, line);
    }
}

/++
 + Excection used in the Recorder RecordFactory
 +/
@safe
class DARTRecorderException : DARTException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        super(msg, file, line);
    }
}

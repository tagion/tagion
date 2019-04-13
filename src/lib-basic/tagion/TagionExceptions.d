module tagion.TagionExceptions;

import std.exception;
import tagion.hashgraph.ConsensusExceptions;
import tagion.services.LoggerService;


@safe
interface TagionExceptionInterface {

}

/++
 + Exception used as a base exception class for all exceptions use in tagion project
 +/
@safe
class TagionException : Exception, TagionExceptionInterface {
    immutable(string) task_name; /// Contains the name of the task when the execption has throw
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        task_name=log.task_name;
        super( msg, file, line );
    }
}

@safe
template convertEnum(Enum, Consensus) {
    const(Enum) convertEnum(uint enum_number, string file = __FILE__, size_t line = __LINE__) {
        if ( enum_number <= Enum.max) {
            return cast(Enum)enum_number;
        }
        throw new Consensus(ConsensusFailCode.NETWORK_BAD_PACKAGE_TYPE, file, line);
        assert(0);
    }
}

/++
 + Builds a check function out of a TagionExecption
+/
@safe
void Check(E)(bool flag, lazy string msg, string file = __FILE__, size_t line = __LINE__) {
    static assert(is(E:TagionExceptionInterface));
    if (!flag) {
        throw new E(msg, file, line);
    }
}

module tagion.TagionExceptions;

import std.exception;
import tagion.hashgraph.ConsensusExceptions;
import tagion.services.LoggerService;


/++
 + Exception used as a base exception class for all exceptions use in tagion project
 +/
@safe
class TagionException : Exception {
    immutable(string) task_name; /// Contains the name of the task when the execption has throw
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        task_name=log.task_name;
        super( msg, file, line );
    }
}

@safe
template ConvertEnum(Enum, Consensus) {
    const(Enum) convertEnum(uint enum_number, string file = __FILE__, size_t line = __LINE__) {
        if ( enum_number <= Enum.max) {
            return cast(Enum)enum_number;
        }
        throw new Consensus(ConsensusFailCode.NETWORK_BAD_PACKAGE_TYPE, file, line);
        assert(0);
    }
}

@safe
template ConsensusCheck(Consensus) {
    static if ( is(Consensus:ConsensusException) ) {
        void consensusCheck(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
            if (!flag) {
                throw new Consensus(code, file, line);
            }
        }
    }
    else {
        static assert(0, "Type "~Consensus.stringof~" not supported");
    }
}

@safe
template ConsensusCheckArguments(Consensus) {
    static if ( is(Consensus:ConsensusException) ) {
        ref auto consensusCheckArguments(A...)(A args) {
            struct Arguments {
                A args;
                void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) const {
                    if ( !flag ) {
                        immutable msg=format(consensus_error_messages[code], args);
                        throw new Consensus(msg, code, file, line);
                    }
                }
            }
            return const(Arguments)(args);
        }
    }
    else {
        static assert(0, "Type "~Consensus.stringof~" not supported");
    }
}

/++
 + Builds a check function out of a TagionExecption
+/
@safe
void Check(E)(bool flag, lazy string msg, string file = __FILE__, size_t line = __LINE__) {
    static assert(is(E:TagionException));
    if (!flag) {
        throw new E(msg, file, line);
    }
}

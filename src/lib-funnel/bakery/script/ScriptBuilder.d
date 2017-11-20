module bakery.script.ScriptBuilder;

import std.conv;
import tango.text.Unicode;

import bakery.script.ScriptInterpreter;
import bakery.script.Script;
import bakery.utils.BSON : R_BSON=BSON, Document;




import std.stdio;

alias R_BSON!true BSON;

@safe
class ScriptBuilderException : ScriptException {
    this( immutable(char)[] msg ) {
        super( msg );
    }
}


class ScriptBuilder {
    struct Function {
        string name;
        immutable(Token)[] tokens;
        ScriptElement opcode;
        bool compiled;
    }
    static private Function[string] functions;
    static this() {

    }
    alias ScriptInterpreter.Type ScriptType;
    alias ScriptInterpreter.Token Token;
    // struct Token {
    //     string token;
    //     uint line;
    //     ScriptType type;
    // }
    /**
       Build as script from bson data stream
     */
    @safe
    immutable(Token)[] BSON2Token(immutable ubyte[] data) {
        string lowercase(const(char)[] str) @trusted  {
            return toLower(str).idup;
        }
        immutable(Token)[] tokens;

        auto doc=Document(data);
        @trusted
        auto getRange(Document doc) {
            if ( doc.hasElement("code") ) {
                return doc["code"].get!Document[];
            }
            else {
                return doc[];
            }
        }
        auto range = getRange(doc);
        while(!range.empty) {
            auto word=range.front;
            if ( word.isDocument ) {
                auto word_doc= word.get!Document;
                immutable _token = word_doc["token"].get!string;
                auto _type = cast(ScriptType)(word_doc["type"].get!int);
                immutable _line = cast(uint)(word_doc["line"].get!int);
                switch (lowercase(_token)) {
                case "if":
                    _type=ScriptType.IF;
                    break;
                case "else":
                    _type=ScriptType.ELSE;
                    break;
                case "endif":
                case "then":
                    _type=ScriptType.ENDIF;
                    break;
                case "do":
                    _type=ScriptType.DO;
                    break;
                case "loop":
                    _type=ScriptType.LOOP;
                    break;
                case "begin":
                    _type=ScriptType.BEGIN;
                    break;
                case "until":
                    _type=ScriptType.UNTIL;
                    break;
                case "while":
                    _type=ScriptType.WHILE;
                    break;
                case "repeat":
                    _type=ScriptType.REPEAT;
                    break;
                case "leave":
                    _type=ScriptType.LEAVE;
                    break;
                default:
                    /*

                     */

                }
                immutable(Token) t={
                  token : _token,
                  type : _type,
                  line : _line
                };
                tokens~=t;
            }
            else {
                throw new ScriptBuilderException("Malformed Genesys script BSON stream document expected not "~to!string(word.type) );
            }
            range.popFront;
        }
        return tokens;
    }

    @safe
    bool parse_functions(immutable(Token)[] tokens, output immutable(Token)[] base_tokens) {
        immutable(Token)[] function_tokens;
        string function_name;
        bool fail=false;
        bool inside_function;
        foreach(t; tokens) {
            writefln("%s",t.toText);
            if ( t.type == ScriptType.FUNC ) {
                if ( function_name !is null ) {
                    immutable(Token) error = {
                      token : "Function declaration inside functions not allowed",
                      line : t.line,
                      type : ScriptType.ERROR
                    };
                    function_tokens~=t;
                    function_tokens~=error;
                    base_tokens~=error;
                    fail=true;
                }
                if ( t.token !in functions ) {
                    writefln("%s",t.token);
                    function_tokens = null;
                    function_name = t.token;
                }
                else {
                    immutable(Token) error = {
                      token : "Function "~t.token~" redefined!",

                      line : t.line,
                      type : ScriptType.ERROR
                    };
                    function_tokens~=t;
                    function_tokens~=error;
                    base_tokens~=error;
                    fail=true;
                }
            }
            else if ( t.type == ScriptType.ENDFUNC ) {
                writefln("%s",function_name);
                immutable(Token) exit = {
                  token : "$exit",
                  line : t.line,
                  type : ScriptType.EXIT
                };
                function_tokens~=exit;
                Function func={
                  name : function_name,
                  tokens : function_tokens
                };
                functions[function_name]=func;
                function_tokens = null;
                function_name = null;
            }
            else if ( function_name.length > 0 ) { // Inside function scope
                function_tokens~=tokens;
            }
            else { //
                base_tokens~=t;
            }
        }
        return fail;
    }


    static BSON BSONToken(const(Token) token) @safe {
        auto bson=new BSON();
        bson["token"]=token.token;
        bson["type"]=token.type;
        bson["line"]=token.line;
        bson["jump"]=token.jump;
        return bson;
    }
    unittest {
        BSON[] codes;
        immutable(Token) opcode={
          token : "opcode",
          type  : ScriptType.WORD
        };
        immutable(Token)[] tokens;
        // ( Forth source code )
        // : Test
        //  opcode if
        //    opcode opcode if
        //       opcode opcode if
        //          opcode opcode
        //        else
        //          opcode opcode
        //        then
        //           opcode opcode
        //    then then
        //  opcode opcode
        //  begin
        //    opcode opcode
        //  while
        //    opcode opcode
        //    do
        //      opcode opcode
        //    loop
        //    opcode opcode
        //    do
        //      opcode opcode
        //    +loop
        //  repeat

        tokens~=func("Test");
        tokens~=opcode;
        tokens~=token_if;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_if;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_if;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_else;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_endif;
        tokens~=token_endif;
        tokens~=token_endif;
        //
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_while;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_do;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_loop;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_do;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_incloop;

        {
            // Build BSON array of the token list
            foreach(t; tokens) {
                codes~=BSONToken(t);
            }
            // Build the BSON stream
            auto bson_stream=new BSON();
            bson_stream["code"]=codes;
            auto stream=bson_stream.expand;


            //
            // Reconstruct the token array from the BSON stream
            // and verify the reconstructed stream
            auto builder=new ScriptBuilder;
            try {
                auto retokens=builder.BSON2Token(stream);
            }
            catch() {
            }
        }

        tokens~=token_endfunc;

        assert(retokens.length == tokens.length);
        foreach(i;0..tokens.length) {
            assert(retokens[i].type == tokens[i].type);
            assert(retokens[i].token == tokens[i].token);
        }

        //
        // Function builder
        //
        assert(!builder.parse_functions(retokens));
        writeln("End of unittest");
        writefln("%s",functions.length);
        foreach(name, ref f; functions) {
            writefln("\t%s %s\n",name,f.tokens.length);
        }

    }

private:
    // Test aid function
    static immutable(Token) func(string name) {
        immutable(Token) result={
          token : name,
          type  : ScriptType.FUNC
        };
        return result;
    };
    static immutable(Token) token_endfunc={
      token : ";",
      type : ScriptType.ENDFUNC
    };

    //
    immutable(Token) token_put={
      token : "!",
      type : ScriptType.PUT
    };
    immutable(Token) token_get= {
      token : "@",
      type : ScriptType.GET
    };
    immutable(Token) token_inc= {
        // Increas by one
      token : "1+",
      type : ScriptType.WORD
    };
    static immutable(Token) token_dup= {
        // duplicate
      token : "dup",
      type : ScriptType.WORD
    };
    static immutable(Token) token_to_r= {
        // duplicate
      token : ">r",
      type : ScriptType.WORD
    };
    static immutable(Token) token_from_r= {
        // duplicate
      token : "<r",
      type : ScriptType.WORD
    };
    static immutable(Token) token_gte= {
        // duplicate
      token : ">=",
      type : ScriptType.WORD
    };
    static immutable(Token) token_repeat= {
        // repeat
      token : "repeat",
      type : ScriptType.REPEAT
    };
    static immutable(Token) token_if= {
        // if
      token : "if",
      type : ScriptType.IF
    };
    static immutable(Token) token_else= {
        // else
      token : "else",
      type : ScriptType.ELSE
    };
    static immutable(Token) token_begin= {
        // begin
      token : "begin",
      type : ScriptType.BEGIN
    };
    static immutable(Token) token_endif= {
        // then
      token : "then",
      type : ScriptType.ENDIF
    };
    static immutable(Token) token_leave= {
        // leave
      token : "leave",
      type : ScriptType.LEAVE
    };
    static immutable(Token) token_while= {
        // while
      token : "while",
      type : ScriptType.WHILE
    };
    static immutable(Token) token_do= {
        // do
      token : "do",
      type : ScriptType.DO
    };
    static immutable(Token) token_loop= {
        // loop
      token : "loop",
      type : ScriptType.LOOP
    };
    static immutable(Token) token_incloop= {
        // +loop
      token : "+loop",
      type : ScriptType.INCLOOP
    };

    immutable(Token) var_I(uint i) @safe pure nothrow const {
        immutable(Token) result = {
          token : "I_"~to!string(i),
          type : ScriptType.VAR
        };
        return result;
    };
    immutable(Token) var_to_I(uint i) @safe pure nothrow const {
        immutable(Token) result = {
          token : "I_TO"~to!string(i),
          type : ScriptType.VAR
        };
        return result;
    };

    immutable(Token)[] expand_loop(immutable(Token)[] tokens) @safe {
        uint loop_index;
        //immutable
        immutable(Token)[] scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) switch (t.type) {
                case DO:
                    // Insert forth opcode
                    // I_FROM_ ! I_ !
                    scope_tokens~=var_to_I(loop_index);
                    scope_tokens~=token_put;
                    scope_tokens~=var_I(loop_index);
                    scope_tokens~=token_put;
                case BEGIN:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : BEGIN,
                      jump : loop_index
                    };
                    scope_tokens~=token;
                    loop_index++;
                    break;
                case LOOP:
                case INCLOOP:
                    // loop
                    // I_ dup @ 1 + dup ! I_TO @ >=
                    // +loop
                    // >r I_ dup @ <r + dup ! I_TO @ >=
                    if (t.type == INCLOOP) {
                        scope_tokens~=token_to_r;
                    }
                    scope_tokens~=var_I(loop_index);
                    scope_tokens~=token_dup;
                    scope_tokens~=token_get;
                    if (t.type == INCLOOP) {
                        scope_tokens~=token_from_r;
                    }
                    else {
                        scope_tokens~=token_inc;
                    }
                    scope_tokens~=token_dup;
                    scope_tokens~=token_put;
                    scope_tokens~=var_to_I(loop_index);
                    scope_tokens~=token_get;
                    scope_tokens~=token_gte;
                    scope_tokens~=token_if;
                    scope_tokens~=token_repeat;
                    scope_tokens~=token_endif;
                    break;
                case WHILE:
                    scope_tokens~=token_if;
                    scope_tokens~=token_leave;
                    scope_tokens~=token_endif;
                    break;
                case LEAVE:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : loop_index
                    };
                    break;
                default:
                    scope_tokens~=t;
                }
        }
        return scope_tokens;
    }
    immutable(Token)[] expand_condition_jump(immutable(Token)[] tokens) @safe {
        uint condition_index; // Jump index for the IF ELSE THEN
        uint[] index_stack;
        immutable(Token)[] scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) switch (t.type) {
                case IF:
                    immutable(Token) token={
                      token : "$if",
                      line : t.line,
                      type : t.type,
                      jump : condition_index
                    };
                    index_stack~=condition_index;
                    condition_index++;
                    scope_tokens~=token;
                    break;
                case ELSE:
                    immutable(Token) token_else={
                      token : "$else",
                      line : t.line,
                      type : ELSE,
                      jump : condition_index
                    };
                    scope_tokens~=token_else;
                    index_stack[$-1]=condition_index;
                    immutable(Token) token_then={
                      token : "$if_label", // THEN is us a jump traget of the IF
                      line : t.line,
                      type : t.type,
                      jump : index_stack[$-1]
                    };
                    scope_tokens~=token_then;
                    condition_index++;
                    break;
                case ENDIF:
                    immutable(Token) token={
                      token : "$endif",
                      line : t.line,
                      type : t.type,
                      jump : index_stack[$-1]
                    };
                    index_stack.length--;
                    scope_tokens~=token;
                    break;
                case DO:
                case WHILE:
                case LOOP:
                case INCLOOP:
                    assert(0, "The opcode "~to!string(t.type)~
                        " should be eliminated by loop_expand function");
                    break;
                default:
                    scope_tokens~=t;
                    break;
                }
        }
        return scope_tokens;
    }
    immutable(Token)[] add_jump_labels(immutable(Token)[] tokens) @safe {
        // This table is set to all the forward jump indices for ELSE and THEN
        uint[uint] if_table;
        // This table is set to all the begin loop jump indices for BEGIN and DO
        uint[uint] begin_table;
        // This table is set to all the end loop jump indices for LOOP and REPEAT
        uint[uint] repeat_table;

        // Fill the tables up with jump indciese
        foreach(uint index, t; tokens) {
            with(ScriptType) switch (t.type) {
                case THEN:
                case ENDIF:
                    if_table[t.jump]=index;
                    break;
                case BEGIN:
                    begin_table[t.jump]=index;
                    break;
                case REPEAT:
                    repeat_table[t.jump]=index;
                    break;
                default:
                    break;
                }
        }
        immutable(Token)[] scope_tokens;
        // Change the jump to actual jump index pointers
        foreach(index, t; tokens) {
            with(ScriptType) switch (t.type) {
                case IF:
                case ELSE:
                    immutable(Token) token={
                      token : t.token,
                      type : t.type,
                      line : t.line,
                      jump : if_table[t.jump]
                    };
                    scope_tokens~=token;
                    break;
                case REPEAT:
                    immutable(Token) token={
                      token : t.token,
                      type : t.type,
                      line : t.line,
                      jump : begin_table[t.jump]
                    };
                    scope_tokens~=token;
                    break;
                case LEAVE:
                    immutable(Token) token={
                      token : t.token,
                      type : t.type,
                      line : t.line,
                      jump : repeat_table[t.jump]
                    };
                    scope_tokens~=token;
                    break;
                default:
                    scope_tokens~=t;
                    break;
                }
        }
        return scope_tokens;
    }
    version(none)
    immutable(Token)[] parse_function(immutable(Token)[] tokens) @safe {
        uint jump;
        immutable(uint)[] loop_stack;
        immutable(Token)[] scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) final switch (t.type) {
                case IF:
                case ELSE:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : jump
                    };
                    scope_tokens~=token;
                    jump++;
                    break;
                case ENDIF:
                case THEN:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : jump
                    };
                    scope_tokens~=token;
                    break;
                case DO:
                case BEGIN:
                case LEAVE:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : jump
                    };
                    scope_tokens~=token;
                    loop_stack~=jump;
                    jump++;
                    break;
                case LOOP:
                case INCLOOP:
                case REPEAT:
                case UNTIL:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : loop_stack[$-1]
                    };
                    scope_tokens~=token;
                    loop_stack.length--;
                    break;
                case WHILE:
                    break;
                case FUNC:
                case ENDFUNC:
                case LEAVE:
                case EXIT:
                case WORD:
                case NUMBER:
                case HEX:
                case TEXT:
                case ERROR:
                case UNKNOWN:
                    scope_tokens~=t;
                    break;
                case COMMENT:
                case EOF:
                    /* Tokens ignored */
            }
        }
    }
//    immutable(Token)(
}

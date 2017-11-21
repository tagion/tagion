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

@safe
class ScriptBuilderExceptionIncompte : ScriptException {
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
    static immutable(Token)[] BSON2Tokens(immutable ubyte[] data) {
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
    bool parse_functions(immutable(Token[]) tokens, out immutable(Token)[] base_tokens) {
        immutable(Token)[] function_tokens;
        string function_name;
        bool fail=false;
        bool inside_function;
        foreach(t; tokens) {
//            writefln("%s",t.toText);
            if ( t.type == ScriptType.FUNC ) {

                if ( inside_function || (function_name !is null) ) {
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
                inside_function=true;
            }
            else if ( t.type == ScriptType.ENDFUNC ) {
                writefln("%s",function_name);
                if (inside_function) {
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
                    inside_function=false;
                }
                else {
                    immutable(Token) error = {
                      token : "Function end with out a function begin declaration",
                      line : t.line,
                      type : ScriptType.ERROR
                    };
                    base_tokens~=t;
                    base_tokens~=error;
                    fail=true;
                }
                function_tokens = null;
                function_name = null;


            }
            else if ( function_name.length > 0 ) { // Inside function scope
                function_tokens~=t;
            }
            else { //
                base_tokens~=t;
            }
        }
        if (inside_function) {
            writeln("Inside function");
            immutable(Token) error = {
              token : "No function end found",
              type : ScriptType.ERROR
            };
            base_tokens~=error;
            fail=true;
        }
        return fail;
    }


    static BSON Token2BSON(const(Token) token) @safe {
        auto bson=new BSON();
        bson["token"]=token.token;
        bson["type"]=token.type;
        bson["line"]=token.line;
        bson["jump"]=token.jump;
        return bson;
    }
    unittest {
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
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_until;

        writefln("tokens.length=%s", tokens.length);


        { //
          // Function parse test missing end of function
          //
            BSON[] codes;

            // Build BSON array of the token list
            foreach(t; tokens) {
                codes~=Token2BSON(t);
            }
            // Build the BSON stream
            auto bson_stream=new BSON();
            bson_stream["code"]=codes;
            auto stream=bson_stream.expand;


            //
            // Reconstruct the token array from the BSON stream
            // and verify the reconstructed stream
            auto retokens=BSON2Tokens(stream);
            assert(retokens.length == tokens.length);
            writefln("tokens.length=%s", tokens.length);

            foreach(i;0..tokens.length) {
                assert(retokens[i].type == tokens[i].type);
                assert(retokens[i].token == tokens[i].token);
            }
            //
            // Parse function
            //
            auto builder=new ScriptBuilder;
            immutable(Token)[] base_tokens;
            // parse_function should fail because end of function is missing
            assert(builder.parse_functions(retokens, base_tokens));
            // base_tokens.length is non zero because it contains Error tokens
            assert(base_tokens.length > 0);

            assert(base_tokens[0].type == ScriptType.ERROR);
            // No function has been declared
            assert(functions.length == 0);
        }

        //     assert(builder.BSON2Token(stream, retokens));
        // }
            writefln("3 tokens.length=%s", tokens.length);

        tokens~=token_endfunc;
            writefln("4 tokens.length=%s", tokens.length);

        {
        //
        // Function builder
        //
            BSON[] codes;

            // Build BSON array of the token list
            foreach(t; tokens) {
                codes~=Token2BSON(t);
            }
            // Build the BSON stream
            auto bson_stream=new BSON();
            bson_stream["code"]=codes;
            auto stream=bson_stream.expand;


            //
            // Reconstruct the token array from the BSON stream
            // and verify the reconstructed stream
            writefln("5 tokens.length=%s", tokens.length);
            auto retokens=BSON2Tokens(stream);
            assert(retokens.length == tokens.length);
            foreach(i;0..tokens.length) {
                assert(retokens[i].type == tokens[i].type);
                assert(retokens[i].token == tokens[i].token);
            }
            writefln("6 tokens.length=%s", tokens.length);
            writefln("6 retokens.length=%s", retokens.length);

            //
            // Parse function
            //
            auto builder=new ScriptBuilder;
            immutable(Token)[] base_tokens;
            // parse_function should NOT fail because end of function is missing
            assert(!builder.parse_functions(retokens, base_tokens));
            writefln("7 retokens.length=%s", retokens.length);
            // base_tokens.length is zero because it should not contain any Error tokens
            assert(base_tokens.length == 0);

//            assert(base_tokens[0].type == ScriptType.ERROR);
            // No function has been declared
            assert(functions.length == 1);
            // Check if function named "Test" is declared
            assert("Test" in functions);

            writeln("Unittest end");
            auto func=functions["Test"];


            // Check that the number of function tokens is correct
            writefln("func.tokens.lengt=%s",func.tokens.length);
            assert(func.tokens.length == 41);

            //
            // Expand all loop to conditinal and unconditional jumps
            //
            auto loop_expanded_tokens = expand_loop(func.tokens);
            writefln("func.tokens.length=%s", loop_expanded_tokens.length);
            foreach(i,t; loop_expanded_tokens) {
                 writefln("%s]:%s", i, t.toText);
            }
            assert(func.tokens.length == 77);

            // assert(!builder.parse_functions(retokens));
        // writeln("End of unittest");
        // writefln("%s",functions.length);
        // foreach(name, ref f; functions) {
        //     writefln("\t%s %s\n",name,f.tokens.length);
        // }
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
    static immutable(Token) token_put={
      token : "!",
      type : ScriptType.PUT
    };
    static immutable(Token) token_get= {
      token : "@",
      type : ScriptType.GET
    };
    static immutable(Token) token_inc= {
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
    static immutable(Token) token_invert= {
        // invert
      token : "invert",
      type : ScriptType.WORD
    };
    static immutable(Token) token_repeat= {
        // repeat
      token : "repeat",
      type : ScriptType.REPEAT
    };
    static immutable(Token) token_until= {
        // until
      token : "until",
      type : ScriptType.UNTIL
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

    static immutable(Token) var_I(uint i) @safe pure nothrow {
        immutable(Token) result = {
          token : "I_"~to!string(i),
          type : ScriptType.VAR
        };
        return result;
    };
    static immutable(Token) var_to_I(uint i) @safe pure nothrow {
        immutable(Token) result = {
          token : "I_TO_"~to!string(i),
          type : ScriptType.VAR
        };
        return result;
    };

    static immutable(Token)[] expand_loop(immutable(Token)[] tokens) @safe {
        uint loop_index;
        immutable(ScriptType)[] begin_loops;
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
                    begin_loops ~= t.type;
                case BEGIN:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : BEGIN,
                      jump : loop_index
                    };
                    scope_tokens~=token;
                    loop_index++;
                    begin_loops ~= t.type;
                    break;
                case LOOP:
                case INCLOOP:
                    // loop
                    // I_ dup @ 1 + dup ! I_TO @ >=
                    // +loop
                    // >r I_ dup @ <r + dup ! I_TO @ >=
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "DO expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };

                        scope_tokens~=error;
                    }
                    else {
                        if ( begin_loops[$-1] == DO ) {
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
                        }
                        else {
                            immutable(Token) error = {
                              token : "DO begub loop expect not "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                        }
                        begin_loops.length--;
                    }
                    break;
                case WHILE:
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "BEGIN expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };
                        scope_tokens~=error;

                    }
                    else {
                        if ( begin_loops[$-1] == BEGIN ) {
                            scope_tokens~=token_if;
                            scope_tokens~=token_leave;
                            scope_tokens~=token_endif;
                        }
                        else {
                            immutable(Token) error = {
                              token : "BEGIN expect before "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                        }
                    }
                    break;
                case UNTIL:
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "BEGIN expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };
                        scope_tokens~=error;
                    }
                    else {
                        if ( begin_loops[$-1] == BEGIN ) {
                            scope_tokens~=token_invert;
                            scope_tokens~=token_if;
                            scope_tokens~=token_repeat;
                            scope_tokens~=token_endif;
                        }
                        else {
                            immutable(Token) error = {
                              token : "BEGIN expect before "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                        }
                    }
                    break;
                case LEAVE:
                    scope_tokens~=t;
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

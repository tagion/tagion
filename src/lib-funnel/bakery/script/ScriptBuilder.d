module bakery.script.ScriptBuilder;

import std.conv;

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
    alias ScriptElement function() opcreate;
    package static opcreate[string] opcreators;
    alias ScriptInterpreter.ScriptType ScriptType;
    alias ScriptInterpreter.Token Token;
    /**
       Build as script from bson data stream
     */
    @safe
    class ScriptTokenError : ScriptElement {
        immutable(Token) token;
        private string msg;
        this(immutable(Token) token, string msg) {
            super(0);
            this.token=token;
            this.msg=msg;
        }
        ScriptElement opCall(const Script s, ScriptContext sc) const {
            check(s, sc);
            throw new ScriptBuilderException(msg~token.toText);
            return null;
        }
        string toText() const {
            return token.token~" "~msg;
        }
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
        //
        //  begin
        //      opcode opcode
        //      begin
        //        opcode opcode
        //      until
        //  until


        tokens~=token_func("Test");
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
        tokens~=token_repeat;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_until;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_until;

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
            auto retokens=ScriptInterpreter.BSON2Tokens(stream);
            assert(retokens.length == tokens.length);
            // Add token types to the token stream
            retokens=ScriptInterpreter.Tokens2Tokens(retokens);
            // writefln("tokens.length=%s", tokens.length);
            // writefln("retokens.length=%s", retokens.length);
            // Reconstructed tokens is one less because
            // : test is converted into one token
            // {
            //   token : "Test",
            //   type  : FUNC
            // }
            assert(retokens.length+1 == tokens.length);

            // Forth tokens
            // : Test
            assert(tokens[0].token==":"); // Function declare symbol
            assert(tokens[1].token=="Test"); // Function name
            assert(tokens[0].type==ScriptType.WORD);
            assert(tokens[1].type==ScriptType.WORD);

            // Reconstructed
            assert(retokens[0].token=="Test");
            assert(retokens[0].type==ScriptType.FUNC); // Type change to FUNC

            // Cut out the function declaration
            immutable tokens_test=tokens[2..$];
            immutable retokens_test=retokens[1..$];
            // The reset of the token should be the same
            foreach(i;0..tokens_test.length) {
                // writefln("%s] retokens[i].type=%s  tokens[i].type=%s",
                //     i,
                //     retokens_test[i].type,
                //     tokens_test[i].type);
                assert(retokens_test[i].type == tokens_test[i].type);
                assert(retokens_test[i].token == tokens_test[i].token);
            }

            //
            // Parse function
            //
            auto builder=new ScriptBuilder;
            immutable(Token)[] base_tokens;
            Script script;
            // parse_function should fail because end of function is missing
            assert(builder.parse_functions(script, retokens, base_tokens));
            assert(script !is null);
            // base_tokens.length is non zero because it contains Error tokens
            assert(base_tokens.length > 0);

            assert(base_tokens[0].type == ScriptType.ERROR);
            // No function has been declared
            assert(script.functions.length == 0);
        }

        //     assert(builder.BSON2Token(stream, retokens));
        // }
//            writefln("3 tokens.length=%s", tokens.length);

        tokens~=token_endfunc;
//            writefln("4 tokens.length=%s", tokens.length);

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

            auto retokens=ScriptInterpreter.BSON2Tokens(stream);
            retokens=ScriptInterpreter.Tokens2Tokens(retokens);
            //
            // Parse function
            //
            auto builder=new ScriptBuilder;
            immutable(Token)[] base_tokens;
            Script script;
            // parse_function should NOT fail because end of function is missing
            assert(!builder.parse_functions(script, retokens, base_tokens));
            // base_tokens.length is zero because it should not contain any Error tokens
            assert(base_tokens.length == 0);

            // No function has been declared
            assert(script.functions.length == 1);
            // Check if function named "Test" is declared
            assert("Test" in script.functions);

            auto func=script.functions["Test"];


            // Check that the number of function tokens is correct
            assert(func.tokens.length == 50);

            //
            // Expand all loop to conditinal and unconditional jumps
            //
            auto loop_expanded_tokens = builder.expand_loop(func);
            // foreach(i,t; loop_expanded_tokens) {
            //      writefln("%s]:%s", i, t.toText);
            // }
            writefln("%s", loop_expanded_tokens.length);
            assert(loop_expanded_tokens.length == 68);

            auto condition_jump_tokens=builder.add_jump_label(loop_expanded_tokens);
            assert(builder.error_tokens.length == 0);
        }
    }
    uint get_var(string var_name) const {
        return var_indices[var_name];
    }
    unittest { // Simple function test
        string source=
            ": test\n"~
            "  * -\n"~
            ";\n"
            ;
        auto src=new ScriptInterpreter(source);
        // Convert to BSON object
        auto bson=src.toBSON;
        // Expand to BSON stream
        auto data=bson.expand;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, data);

        auto sc=new ScriptContext(10, 10, 10, 10);
        sc.data_push(3);
        sc.data_push(2);
        sc.data_push(5);

        writefln("%s", sc.data_peek(0).value);
        writefln("%s", sc.data_peek(1).value);
        writefln("%s", sc.data_peek(2).value);

        sc.trace=false;
        script.run("test", sc);
        assert( sc.data_pop.value == -7 );

    }
    unittest { // Simple if test
        string source=
            ": test\n"~
            "  if  \n"~
            "  111  \n"~
            "  then  \n"~
            ";\n"
            ;
        auto src=new ScriptInterpreter(source);
        // Convert to BSON object
        auto bson=src.toBSON;
        // Expand to BSON stream
        auto data=bson.expand;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, data);

        auto sc=new ScriptContext(10, 10, 10, 10);
        sc.data_push(10);
        sc.data_push(0);

        script.run("test", sc);
        assert(sc.data_pop.value == 10);

        sc.data_push(10);

        script.run("test", sc);
        assert(sc.data_pop.value == 111);

    }
    unittest { // Simple if else test

        string source=
            ": test\n"~
            "  if  \n"~
            "    -1  \n"~
            "  else  \n"~
            "    1  \n"~
            "  then  \n"~
            ";\n"
            ;

        auto src=new ScriptInterpreter(source);
        // Convert to BSON object
        auto bson=src.toBSON;
        // Expand to BSON stream
        auto data=bson.expand;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, data);

        auto sc=new ScriptContext(10, 10, 10, 10);

        sc.trace=false;
        // Test IF ELSE true (top != 0)
        sc.data_push(10);
        script.run("test", sc);
        assert(sc.data_pop.value == -1);

        // Test 'IF ELSE' false (top == 0)
        sc.data_push(0);
        script.run("test", sc);
        assert(sc.data_pop.value == 1);

    }

    unittest { // Variable
        string source=
            ": test\n"~
            " 10 \n"~
            "  variable X\n"~
            "  X !\n"~
            ";\n"
            ;

        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

//        sc.trace=true;
        // Set variable X to 10
        sc.data_push(10);
        script.run("test", sc);
        auto var=sc[builder.get_var("X")];
        assert(var.value == 10);
    }

    unittest { // Variable get and put
        string source=
           ": test\n"~
            "  variable X\n"~
            "  variable Y\n"~
            "  17 X !\n"~
            "  13 Y !\n"~
            "  X @ Y @\n"~
            ";\n"
            ;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

//        sc.trace=true;
        // Put and Get variable X and Y

        script.run("test", sc);
        // Check Y value
        assert(sc.data_pop.value == 13);
        assert(sc[builder.get_var("Y")].value == 13);

        // Check X value
        assert(sc.data_pop.value == 17);
        assert(sc[builder.get_var("X")].value == 17);
    }

    unittest { // None standard unitary operator in variables
        string source=
            ": test\n"~
            " variable X\n"~
            " 7 X !\n"~
            " 3 X !-\n"~
            " X @\n"~
            ";"
            ;

        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

//        sc.trace=true;
        // Put and Get variable X and Y

        script.run("test", sc);
        assert(sc.data_pop.value == -4);

    }
    unittest {
        string source=
            ": testA\n"~
            "  local X\n"~
            "  1 X !\n"~
            "  testB \n"~
            "  X @\n"~
            ";\n"~

            ": testB\n"~
            "  local X\n"~
            "  2 X !\n"~
            "  X @\n"~
            ";\n"~

            "  \n"
            ;

        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

        // sc.trace=true;
        // Put and Get variable X and Y

        script.run("testA", sc);
        assert(sc.data_pop.value == 1);
        assert(sc.data_pop.value == 2);


    }

    unittest { // DO LOOP
        string source=
            ": test\n"~
            "variable X\n"~
            " do \n"~
            "  X @ 1+ X ! \n"~
            " loop \n"~
            " X @\n"~
            ";"
            ;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

        sc.trace=true;
        // Put and Get variable X and Y

        sc.data_push(10);
        sc.data_push(0);
        script.run("test", sc);
        assert(sc.data_pop.value == 10);
//        writefln("pop=%s", sc.data_pop.value);
    }

    unittest { // DO +LOOP
        string source=
            ": test\n"~
            "variable X\n"~
            " do \n"~
            "  X @ 1+ X ! \n"~
            " 2 \n"~
            " +loop \n"~
            " X @\n"~
            ";"
            ;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

        sc.trace=true;
        // Put and Get variable X and Y

        sc.data_push(10);
        sc.data_push(0);
        script.run("test", sc);
        assert(sc.data_pop.value == 5);

//        writefln("pop=%s", sc.data_pop.value);
    }

    unittest {
        string source=": test variable X begin X @ 1 + X !  X @ 10 == until X @ ;";
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, source);

        auto sc=new ScriptContext(10, 10, 10, 10);

        sc.trace=true;
        // Put and Get variable X and Y

        // sc.data_push(10);
        // sc.data_push(0);
//        writefln("#### %s, ", source);
        script.run("test", sc);
        assert(sc.data_pop.value == 10);

//        writefln("pop=%s", sc.data_pop.value);
    }

private:
    uint var_count;
    uint[string] var_indices;
    uint allocate_var(string var_name) {
        if ( var_name !in var_indices ) {
            var_indices[var_name]=var_count;
            var_count++;
        }
        return var_indices[var_name];
    }
    bool is_var(string var_name) pure const nothrow {
        return (var_name in var_indices) !is null;
    }
    immutable(Token)[] error_tokens;
    // Test aid function
    static immutable(Token)[] token_func(string name) {
        immutable(Token)[] result;
        immutable(Token) func_declare={
          token : ":",
          type  : ScriptType.WORD
        };
        immutable(Token) func_name={
          token : name,
          type  : ScriptType.WORD
        };
        result~=func_declare;
        result~=func_name;
        return result;
    };
    static immutable(Token) token_endfunc={
      token : ";",
      type : ScriptType.WORD
    };

    //
    static immutable(Token) token_put={
      token : "!",
      type : ScriptType.WORD
    };
    static immutable(Token) token_get= {
      token : "@",
      type : ScriptType.WORD
    };
    @safe
    static immutable(Token)[] token_loop_progress(immutable ScriptType type, immutable uint i)
        in {
            assert( (type == ScriptType.LOOP) || (type == ScriptType.ADDLOOP));
        }
    body {
        // Loop increase
        auto loc_index=loc_I~to!string(i);
        immutable(Token)[] result= [
            {
              token : loc_index,
              type  : ScriptType.INDEXGET
            },
            {
                // Increas by one or add
              token : (type == ScriptType.LOOP)?"1+":"+",
              type : ScriptType.WORD
            },
            {
              token : loc_index,
              type  : ScriptType.INDEXPUT
            }
        ];
        return result;
    }
    static immutable(Token) token_add= {
        // Increase by one
      token : "!+",
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
    static immutable(Token) token_inc_r= {
        // r> 1 + dup >r
      token : "@r1+",
      type : ScriptType.WORD
    };
    static immutable(Token) token_get_r= {
        // r@
      token : "r@",
      type : ScriptType.WORD
    };

    static immutable(Token) token_gt= {
        // greater than
      token : ">",
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
    static immutable(Token) token_not_if= {
        // repeat
      token : "not_if",
      type : ScriptType.NOT_IF
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
      type : ScriptType.ADDLOOP
    };

    enum loc_I="I#";
    enum loc_to_I="I_TO#";
    @safe
    static immutable(Token) local_I(ScriptType type, string loc_name)(ref Script.Function f, uint i) {
        static assert( (type == ScriptType.INDEXGET) || (type == ScriptType.INDEXPUT));
        string name=loc_name~to!string(i);
        // static if (type == ScriptType.INDEXPUT) {
        //     if ( !f.is_loc(name) ) {
        //         f.allocate_loc(name);
        //     }
        // }
        immutable(Token) result = {
          token : name,
          type : type
        };
        return result;
    };
    @safe
    bool parse_functions(
        ref Script script,
        immutable(Token[]) tokens,
        out immutable(Token)[] base_tokens) {
        immutable(Token)[] function_tokens;
        string function_name;
        bool fail=false;
        bool inside_function;
        if ( script is null ) {
            script=new Script;
        }
        foreach(t; tokens) {
            // writefln("parse_function %s",t.toText);
            if ( (t.token==":") || (t.type == ScriptType.FUNC) ) {

                if ( inside_function || (function_name !is null) ) {
                    immutable(Token) error = {
                      token : "Function declaration inside functions not allowed",
                      line : t.line,
                      type : ScriptType.FUNC
                    };
                    function_tokens~=t;
                    function_tokens~=error;
                    base_tokens~=error;
                    fail=true;

                }
                if ( t.token !in script.functions ) {
//                    writefln("%s",t.token);
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
            else if ( t.token==";" ) {
//                writefln("%s",function_name);
                if (inside_function) {
                    immutable(Token) exit = {
                      token : "$exit",
                      line : t.line,
                      type : ScriptType.EXIT
                    };
                    function_tokens~=exit;
                    Script.Function func={
                      name : function_name,
                      tokens : function_tokens
                    };
                    script.functions[function_name]=func;
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
//            writeln("Inside function");
            immutable(Token) error = {
              token : "No function end found",
              type : ScriptType.ERROR
            };
            base_tokens~=error;
            fail=true;
        }
        return fail;
    }

    immutable(Token)[] expand_loop(Script.Function f) @safe {
        uint loop_index;
        immutable(ScriptType)[] begin_loops;
        //immutable
        immutable(Token)[] scope_tokens;
        foreach(t; f.tokens) {
            with(ScriptType) switch (t.type) {
                case DO:
                    // Insert forth opcode
                    // I#i !
                    // I_TO#i !
                    scope_tokens~=local_I!(INDEXPUT, loc_I)(f, loop_index);
                    scope_tokens~=local_I!(INDEXPUT, loc_to_I)(f, loop_index);
                    scope_tokens~=token_begin;
                    begin_loops ~= t.type;
                    loop_index++;
                    break;
                case BEGIN:
                    scope_tokens~=token_begin;
                    begin_loops ~= t.type;
                    loop_index++;
                    break;
                case LOOP:
                case ADDLOOP:
                    // loop
                    // I#i !1+
                    // I_TO#i @ >= if goto-begin
                    //
                    // +loop
                    // I#i !+
                    // I_TO#i @ >= if goto-begin
                    loop_index--;
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "DO expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };
                        scope_tokens~=error;
                        error_tokens~=error;
                    }
                    else {
                        if ( begin_loops[$-1] == DO ) {
                            scope_tokens~=token_loop_progress(t.type, loop_index);
                            // if (t.type == LOOP) {
                            //     scope_tokens~=token_inc;
                            // }
                            // else {
                            //     scope_tokens~=token_add;
                            // }
                            scope_tokens~=local_I!(INDEXGET, loc_I)(f, loop_index);
                            scope_tokens~=local_I!(INDEXGET, loc_to_I)(f, loop_index);

                            scope_tokens~=token_gt;
                            scope_tokens~=token_not_if;

                        }
                        else {
                            immutable(Token) error = {
                              token : "DO begin loop expect not "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                            error_tokens~=error;
                        }
                        begin_loops.length--;
                        loop_index--;
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
                        error_tokens~=error;

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
                            error_tokens~=error;
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
                        error_tokens~=error;

                    }
                    else {
                        if ( begin_loops[$-1] == BEGIN ) {
                            // scope_tokens~=token_invert;
                            // scope_tokens~=token_if;
                            // scope_tokens~=token_not_if;
                            scope_tokens~=token_until;
                            // scope_tokens~=token_endif;
                            loop_index--;
                        }
                        else {
                            immutable(Token) error = {
                              token : "BEGIN expect before "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                            error_tokens~=error;
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
    @safe
    immutable(Token)[] add_jump_label(immutable(Token[]) tokens) {
        uint jump_index;
        immutable(uint)[] conditional_index_stack;
        immutable(uint)[] loop_index_stack;
        immutable(Token)[] scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) switch (t.type) {
                case IF:
                    jump_index++;
                    conditional_index_stack~=jump_index;
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : conditional_index_stack[$-1]
                    };
                    scope_tokens~=token;
                    break;
                case ELSE:
                    immutable(Token) token_else={
                      token : t.token,
                      line : t.line,
                      type : LABEL,
                      jump : conditional_index_stack[$-1]
                    };
                    conditional_index_stack.length--;
                    jump_index++;
                    conditional_index_stack~=jump_index;
                    immutable(Token) token_goto={
                      token : "$else_goto", // THEN is us a jump target of the IF
                      line  : t.line,
                      type  : GOTO,
                      jump  : conditional_index_stack[$-1]
                    };
                    scope_tokens~=token_goto;
                    scope_tokens~=token_else;
                    break;
                case ENDIF:
                    immutable(Token) token_endif={
                      token : t.token,
                      line : t.line,
                      type : LABEL,
                      jump : conditional_index_stack[$-1]
                    };
                    conditional_index_stack.length--;
                    scope_tokens~=token_endif;
                    break;
                case BEGIN:
                    jump_index++;
                    loop_index_stack~=jump_index;
                    immutable(Token) token_begin={
                      token : t.token,
                      line : t.line,
                      type : LABEL,
                      jump : loop_index_stack[$-1]
                    };
                    jump_index++;
                    loop_index_stack~=jump_index;
                    scope_tokens~=token_begin;
                    break;
                case UNTIL:
                case REPEAT:
                case NOT_IF:
                    if ( loop_index_stack.length > 1 ) {
                        ScriptType goto_type;
                        if ( t.type == REPEAT ) {
                            goto_type = GOTO;
                        }
                        else if ( t.type == UNTIL ) {
                            goto_type = IF;
                        }
                        else {
                            goto_type = NOT_IF;
                        }
                        immutable(Token) token_repeat={
                          token : t.token,
                          line : t.line,
                          type : goto_type,
                          jump : loop_index_stack[$-2]
                        };
                        immutable(Token) token_end={
                          token : t.token,
                          line : t.line,
                          type : LABEL,
                          jump : loop_index_stack[$-1]
                        };
                        loop_index_stack.length-=2;
                        scope_tokens~=token_repeat;
                        scope_tokens~=token_end;
                    }
                    else {
                        immutable(Token) error={
                          token : "Repeat unexpected",
                          line : t.line,
                          type : ERROR
                        };
                        error_tokens~=error;
                        scope_tokens~=error;
                    }
                    break;
                case LEAVE:
                    if ( loop_index_stack.length > 1 ) {
                        immutable(Token) token_leave={
                          token : t.token,
                          line : t.line,
                          type : GOTO,
                          jump : loop_index_stack[$-1]
                        };
                        scope_tokens~=token_leave;
                    }
                    else {
                        immutable(Token) error={
                          token : "Leave unexpected",
                          line : t.line,
                          type : ERROR
                        };
                        error_tokens~=error;
                        scope_tokens~=error;
                    }
                    break;
                case DO:
                case WHILE:
                case LOOP:
                case ADDLOOP:
                    immutable(Token) error={
                      token : "The opcode "~to!string(t.type)~
                      " should be eliminated by loop_expand function",
                      line : t.line,
                      type : ERROR
                    };
                    scope_tokens~=error;
                    error_tokens~=error;
                    break;
                default:
                    scope_tokens~=t;
                    break;
                }
        }
        return scope_tokens;
    }
    static this() {
        enum binaryOp=["+", "-", "*", "/", "%", "|", "&", "^", "<<" ];
        enum compareOp=["<", "<=", "==", "!=", ">=", ">"];
        enum stackOp=[
            "dup", "swap", "drop", "over",
            "rot", "-rot", "-rot", "-rot",
            "tuck",
            "2dup", "2drop", "2swap", "2over",
            "2nip", "2tuck",
            ">r", "r>", "r@"
            ];
        enum unitaryOp=["1-", "1+", "r@1+"];
        void build_opcreators(string opname) {
            void createBinaryOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptBinaryOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createBinaryOp!(oplist[1..$])(opname);
                    }
                }
            }
            void createCompareOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptCompareOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createCompareOp!(oplist[1..$])(opname);
                    }
                }
            }
            void createStackOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptStackOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createStackOp!(oplist[1..$])(opname);
                    }
                }
            }
            void createUnitaryOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptUnitaryOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createUnitaryOp!(oplist[1..$])(opname);
                    }
                }
            }

            createBinaryOp!(binaryOp)(opname);
            createCompareOp!(compareOp)(opname);
            createStackOp!(stackOp)(opname);
            createUnitaryOp!(unitaryOp)(opname);
        }
        foreach(opname; binaryOp~compareOp~stackOp~unitaryOp) {
            build_opcreators(opname);
        }

    }
    ScriptElement createElement(string op) {
        if ( op in opcreators ) {
            return opcreators[op]();
        }
        return null;
    }
    immutable(Token)[] build(ref Script script, string source) {
        auto src=new ScriptInterpreter(source);
        // Convert to BSON object
        auto bson=src.toBSON;
        // Expand to BSON stream
        auto data=bson.expand;
        return build(script, data);
    }
    immutable(Token)[] build(ref Script script, immutable(Token)[] tokens) {
        immutable(Token)[] results;
        if ( parse_functions(script, tokens, results) ) {
            return results;
        }
        foreach(ref f; script.functions) {
            auto loop_tokens=expand_loop(f);
            writefln("FUNC %s", f.name);
            writefln("%s", f.toText);
            writeln("--- ---");
            f.tokens=add_jump_label(loop_tokens);
            writefln("%s", f.toText);
        }
        build_functions(script);
        return null;
    }
    immutable(Token)[] build(ref Script script, immutable ubyte[] data) {
        auto tokens=ScriptInterpreter.BSON2Tokens(data);
        // Add token types
        tokens=ScriptInterpreter.Tokens2Tokens(tokens);
        return build(script, tokens);
    }
    void build_functions(ref Script script) {
        struct ScriptLabel {
            ScriptElement target; // Script element to jump to
            ScriptJump[] jumps; // Script element to jump from
        }
        scope ScriptElement[] function_scripts;
        foreach(name, ref f; script.functions) {
            scope ScriptLabel*[uint] script_labels;
            ScriptElement forward(immutable uint i=0, immutable uint n=0)
                in {
                    // Empty
                }
            out(result) {
                    if ( i < f.tokens.length ) {
                        assert( result !is null );
                    }
                }
            body {
                ScriptElement result;
                if ( i < f.tokens.length ) {
                    auto t=f.tokens[i];
                    with(ScriptType) final switch (t.type) {
                        case LABEL:
                            auto label=forward(i+1, n);
                            if ( t.jump !in script_labels) {
                                script_labels[t.jump]=new ScriptLabel;
                            }
                            assert(script_labels[t.jump].target is null);
                            script_labels[t.jump].target=label;
                            return label;
                        break;
                        case GOTO:
                            auto jump=new ScriptJump;
                            if ( t.jump !in script_labels) {
                                script_labels[t.jump]=new ScriptLabel;
                            }
                            script_labels[t.jump].jumps~=jump;
                            result=jump;
                            break;
                        case IF:
                        case NOT_IF:
                            ScriptConditionalJump jump;
                            if ( t.type == IF ) {
                                jump=new ScriptConditionalJump;
                            }
                            else {
                                jump=new ScriptNotConditionalJump;
                            }
                            if ( t.jump !in script_labels) {
                                script_labels[t.jump]=new ScriptLabel;
                            }
                            script_labels[t.jump].jumps~=jump;
                            result=jump;
                            break;
                        case NUMBER:
                        case HEX:
                            result=new ScriptNumber(t.token);
                            break;
                        case TEXT:
                            result=new ScriptText(t.token);
                            break;
                        case EXIT:
                            result=new ScriptExit();
                            break;
                        case ERROR:
                            result=new ScriptTokenError(t,"");
                            break;
                        case WORD:
                            result=createElement(t.token);
                            writefln("t.token=%s", t.token);
                            if ( result is null ) {
                                // Possible function call
                                result=new ScriptCall(t.token);
                            }
                            break;
                        case PUT:
                            if ( is_var(t.token) ) {
                                result=new ScriptPutVar(t.token, get_var(t.token));
                            }
                            else if ( f.is_loc(t.token) ) {
                                result=new ScriptPutLoc(t.token, f.get_loc(t.token));
                            }
                            else {
                                auto msg="Variable name '"~t.token~"' not found";
                                result=new ScriptTokenError(t, msg);
                            }
                            break;
                        case GET:
                            if ( is_var(t.token) ) {
                                result=new ScriptGetVar(t.token, get_var(t.token));
                            }
                            else if ( f.is_loc(t.token) ) {
                                result=new ScriptGetLoc(t.token, f.get_loc(t.token));
                            }
                            else {
                                auto msg="Variable name '"~t.token~"' not found";
                                result=new ScriptTokenError(t, msg);
                            }
                            break;
                        case INDEXPUT:
                            result=new ScriptPutLoc(t.token, f.auto_get_loc(t.token));
                            break;
                        case INDEXGET:
                            if ( f.is_loc(t.token) ) {
                                result=new ScriptGetLoc(t.token, f.get_loc(t.token));
                            }
                            else {
                                auto msg="Loop index '"~t.token~"' not found";
                                result=new ScriptTokenError(t, msg);
                            }
                            break;
                        case VAR:
                            // Allocate variable
                            if ( is_var(t.token) ) {
                                result=new ScriptTokenError(t,
                                    "Variable "~t.token~" is already defined");
                            }
                            else {
                                allocate_var(t.token);
                                return forward(i+1, n);
                            }
                            break;
                        case LOCAL:
                            if ( f.is_loc(t.token) ) {
                                result=new ScriptTokenError(t,
                                    "Local variable "~t.token~" is already defined");
                            }
                            else {
                                f.allocate_loc(t.token);
                                return forward(i+1, n);
                            }
                            break;
                        case FUNC:
                        case ELSE:
                        case ENDIF:
                        case DO:
                        case LOOP:
                        case ADDLOOP:
                        case BEGIN:
                        case UNTIL:
                        case WHILE:
                        case REPEAT:
                        case LEAVE:
                        case UNKNOWN:
                        case COMMENT:
                            assert(0, "This "~to!string(t.type)~" pseudo script tokens '"~t.token~
                                "' should have been replace by an executing instructions at this point");
                        case EOF:
                            assert(0, "EOF instructions should have been removed at this point");
                        }
                    result.next=forward(i+1, n+1);
                    result.set_location(n, t.token, t.line, t.pos);
                }
                return result;
            }
            auto func_script=forward;
            function_scripts~=func_script;
            f.opcode=func_script;
            // Connect all the jump labels
            foreach(ref label; script_labels) {
                foreach(ref jump; label.jumps) {
                    jump.set_jump(label.target);
                }
            }
            // Set the number of allocated local variables
            // in the current function
            // the local is used for loop parameters also
        }
        foreach(fs; function_scripts) {
            for(auto s=fs; s !is null; s=s.next) {
                auto call_script = cast(ScriptCall)s;
                if ( call_script !is null ) {
                    if ( call_script.name in script.functions) {
                        // The function is defined in the function tabel
                        auto func=script.functions[call_script.name];
                        if ( func.opcode !is null ) {
                            // Insert the script element to call Script Element
                            // Sets then number of local variables in the function
                           call_script.set_call( func.opcode, func.local_size );

                        }
                        else {
                            auto error=new ScriptError("The function "~call_script.name~
                                " does not contain any opcodes", call_script);
                            call_script.set_call(error);
                        }
                    }
                    else if ( call_script.name !in var_indices) {
                        // If name is not a variable
                        auto error=new ScriptError("The function or variable named "~call_script.name~
                            " is not defined ",call_script);
                        call_script.set_call(error);
                    }
                }
            }
        }

    }
}

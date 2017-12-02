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
    alias ScriptElement function() opcreate;
    package static opcreate[string] opcreators;
    alias ScriptInterpreter.Type ScriptType;
    alias ScriptInterpreter.Token Token;
    /**
       Build as script from bson data stream
     */
    @safe
    class ScriptTokenError : ScriptElement {
        immutable(Token) token;
        this(immutable(Token) token) {
            super(0);
            this.token=token;
        }
        override ScriptElement opCall(const Script s, ScriptContext sc) const {
            check(s, sc);
            throw new ScriptBuilderException(token.toText);
            return null;
        }
    }

    @safe
    static immutable(Token)[] BSON2Tokens(immutable(ubyte[]) data) {
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
        bool declare;
        while(!range.empty) {
            auto word=range.front;
            if ( word.isDocument ) {
                auto word_doc= word.get!Document;
                immutable _token = word_doc["token"].get!string;
                auto _type = cast(ScriptType)(word_doc["type"].get!int);
                enum text_line="line";
                immutable _line = word_doc.hasElement(text_line)?
                    cast(uint)(word_doc[text_line].get!int):0;
                enum text_pos="pos";
                immutable _pos = word_doc.hasElement(text_pos)?
                    cast(uint)(word_doc[text_pos].get!int):0;
                writefln("__token=%s %s", _token, to!string(_type));
                with (ScriptType) {
//                    _type=NOP;
                    switch (lowercase(_token)) {
                    case "if":
                        _type=IF;
                        break;
                    case "else":
                        _type=ELSE;
                        break;
                    case "endif":
                    case "then":
                        _type=ENDIF;
                    break;
                    case "do":
                        _type=DO;
                        break;
                    case "loop":
                        _type=LOOP;
                        break;
                    case "begin":
                        _type=BEGIN;
                        break;
                    case "until":
                        _type=UNTIL;
                        break;
                    case "while":
                        _type=WHILE;
                        break;
                    case "repeat":
                        _type=REPEAT;
                        break;
                    case "leave":
                        _type=LEAVE;
                        break;
                    case "variable":
                        declare=true;
                        continue;
                    default:
                        /*
                          Empty
                        */
                    }
                    if ( declare ) {
                    }
                    immutable(Token) t={
                      token : _token,
                      type : _type,
                      line : _line,
                      pos  : _pos
                    };
                    tokens~=t;
                }
            }
            else {
                throw new ScriptBuilderException("Malformed Genesys script BSON stream document expected not "~to!string(word.type) );
            }
            range.popFront;
        }
        return tokens;
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
            auto retokens=BSON2Tokens(stream);
            assert(retokens.length == tokens.length);
//            writefln("tokens.length=%s", tokens.length);

            foreach(i;0..tokens.length) {
                assert(retokens[i].type == tokens[i].type);
                assert(retokens[i].token == tokens[i].token);
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
//            writefln("5 tokens.length=%s", tokens.length);
            auto retokens=BSON2Tokens(stream);
            assert(retokens.length == tokens.length);
            foreach(i;0..tokens.length) {
                assert(retokens[i].type == tokens[i].type);
                assert(retokens[i].token == tokens[i].token);
            }
            //           writefln("6 tokens.length=%s", tokens.length);
//            writefln("6 retokens.length=%s", retokens.length);

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

//            assert(base_tokens[0].type == ScriptType.ERROR);
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
            auto loop_expanded_tokens = builder.expand_loop(func.tokens);
            // foreach(i,t; loop_expanded_tokens) {
            //      writefln("%s]:%s", i, t.toText);
            // }

            assert(loop_expanded_tokens.length == 89);

            auto condition_jump_tokens=builder.add_jump_label(loop_expanded_tokens);
            assert(builder.error_tokens.length == 0);
            // foreach(i,t; condition_jump_tokens) {
            //      writefln("%s]:%s", i, t.toText);
            // }
            // assert(!builder.parse_functions(retokens));
        }
    }
    unittest {
        string source=
            ": test\n"~
            "  * -\n"~
            ";\n"
            ;
        writefln("Start ScriptBuilder unittest");
        auto src=new ScriptInterpreter(source);
        {
            auto preter=new ScriptInterpreter(source);
            writeln("------ tokens ----");
            foreach(t; preter.tokens) {
                writefln("t=%s", t.toText);
            }
            writeln("------ end tokens ----");
        }
        auto bson=src.parse;
        auto data=bson.expand;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, data);
        auto func=script["test"];
        import std.stdio;
        writef("toInfo'%s'",func.toInfo);
        writeln("Unittest end");

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
    uint get_var(string var_name) const {
        return var_indices[var_name];
    }
    immutable(Token)[] error_tokens;
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
            // writefln("%s",t.toText);
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
            else if ( t.type == ScriptType.ENDFUNC ) {
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

    immutable(Token)[] expand_loop(immutable(Token)[] tokens) @safe {
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
                    goto case BEGIN;
                case BEGIN:
                    scope_tokens~=token_begin;
                    loop_index++;
                    begin_loops ~= t.type;
                    break;
                case LOOP:
                case INCLOOP:
                    // loop
                    // I_ dup @ 1 + dup ! I_TO @ >= if goto-begin then
                    // +loop
                    // >r I_ dup @ <r + dup ! I_TO @ >=
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
                            scope_tokens~=token_invert;
                            scope_tokens~=token_if;
                            scope_tokens~=token_repeat;
                            scope_tokens~=token_endif;
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
                      token : "$if_label", // THEN is us a jump traget of the IF
                      line : t.line,
                      type : GOTO,
                      jump : conditional_index_stack[$-1]
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
                case REPEAT:
                    if ( loop_index_stack.length > 1 ) {
                        immutable(Token) token_repeat={
                          token : t.token,
                          line : t.line,
                          type : GOTO,
                          jump : loop_index_stack[$-2]
                        };
                        immutable(Token) token_end={
                          token : t.token,
                          line : t.line,
                          type : LABEL,
                          jump : loop_index_stack[$-1]
                        };
                        loop_index_stack.length-=2;
                        scope_tokens~=token_begin;
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
                case INCLOOP:
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
            "2nip", "2tuck"
            ];
        void build_opcreators(string opname) {
            void createBinaryOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptBinary!(op);
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
            void createCompare(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptCompare!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createCompare!(oplist[1..$])(opname);
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

            createBinaryOp!(binaryOp)(opname);
            createCompare!(compareOp)(opname);
            createStackOp!(stackOp)(opname);
        };
        foreach(opname; binaryOp~compareOp~stackOp) {
            build_opcreators(opname);
        }

    }
    ScriptElement createElement(string op) {
        if ( op in opcreators ) {
            return opcreators[op]();
        }
        return null;
    }
    immutable(Token)[] build(ref Script script, immutable(Token)[] tokens) {
        immutable(Token)[] results;
        writefln("tokens.length=%s", tokens.length);
        foreach(i,t;tokens) {
            writefln("Token %s] %s", i, t.token);
        }
        if ( parse_functions(script, tokens, results) ) {
            return results;
        }
        writefln("script.functions.length=%s", script.functions.length);
        foreach(f; script.functions) {
            writefln("func=%s", f.name);
            auto loop_tokens=expand_loop(f.tokens);
            f.tokens=add_jump_label(loop_tokens);
        }
        build_functions(script);
        return null;
    }
    immutable(Token)[] build(ref Script script, immutable ubyte[] data) {
        auto tokens=BSON2Tokens(data);
        // writeln(":::::build");
        foreach(t;tokens) {
            writefln("==>%s", t.toText);
        }
        return build(script, tokens);
    }
    void build_functions(ref Script script) {
        struct ScriptLabel {
            ScriptElement target; // Script element to jump to
            ScriptElement[] jumps; // Script element to jump from
        }
        scope ScriptElement[] function_scripts;
        foreach(name,f; script.functions) {
            scope ScriptLabel[uint] script_labels;
            ScriptElement forward(immutable uint i=0) {
                ScriptElement result;
                if ( i < f.tokens.length ) {
                    auto t=f.tokens[i];
                    with(ScriptType) final switch (t.type) {
                        case LABEL:
                            result=forward(i+1);
                            assert(( (t.jump in script_labels) !is null) && (script_labels[t.jump].target !is null) );
                            script_labels[t.jump].target=result;
                        break;
                        case GOTO:
                            result=new ScriptJump;
                            script_labels[t.jump].jumps~=result;
                            break;
                        case IF:
                            result=new ScriptConditionalJump;
                            script_labels[t.jump].jumps~=result;
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
                            result=new ScriptTokenError(t);
                            break;
                        case WORD:
                            result=createElement(t.token);
                            if ( result is null ) {
                                // Possible function call
                                result=new ScriptCall(t.token);
                            }
                            break;
                        case PUT:
                            if ( is_var(t.token) ) {
                                result=new ScriptPutVar(t.token, get_var(t.token));
                            }
                            else {
                                result=new ScriptTokenError(t);
                            }
                            break;
                        case GET:
                            if ( is_var(t.token) ) {
                                result=new ScriptGetVar(t.token, get_var(t.token));
                            }
                            else {
                                result=new ScriptTokenError(t);
                            }
                            break;
                        case VAR:
                            allocate_var(t.token);
                            result=forward(i+1);
                            break;
                        case NOP:
                        case FUNC:
                        case ENDFUNC:
                        case ELSE:
                        case ENDIF:
                        case DO:
                        case LOOP:
                        case INCLOOP:
                        case BEGIN:
                        case UNTIL:
                        case WHILE:
                        case REPEAT:
                        case LEAVE:
                        case THEN:
                        case INDEX:
                            //
                        case UNKNOWN:
                        case COMMENT:
                            assert(0, "This "~to!string(t.type)~" pseudo script tokens opcode should have been replace by executing instructions at this point");
                        case EOF:
                            assert(0, "EOF instructions should have been removed at this point");
                        }
                    result.next=forward(i+1);
                    result.set_location(t.token, t.line, t.pos);
                }
                return result;
            }
            auto func_script=forward;
            function_scripts~=func_script;
            f.opcode=func_script;
            // Connect all the jump labels
            foreach(label; script_labels) {
                foreach(jump; label.jumps) {
                    auto s=cast(ScriptJump)jump;
                    s.set_jump(label.target);
                }
            }
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
                            call_script.set_jump( func.opcode );
                        }
                        else {
                            call_script.set_jump(
                                new ScriptError("The function "~call_script.name~
                                    " does not contain any opcodes", call_script)
                                );
                        }
                    }
                    else {
                        call_script.set_jump(
                            new ScriptError("The function named "~call_script.name~
                                " is not defined ",call_script)
                            );
                    }
                }
            }
        }
    }
}

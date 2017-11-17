module bakery.script.ScriptBuild;

import std.conv;
import bakery.script.ScriptInterpreter;
import bakery.script.Script;
import bakery.utils.BSON;

@safe
class ScriptBuildException : ScriptException {
    this( immutable(char)[] msg ) {
        super( msg );
    }
}


class ScriptBuild {
    struct Function {
        string name;
        immutable(Token)[] tokens;
        ScriptElement opcode;
        bool compiled;
    }
    private Function[string] functions;
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
                throw new ScriptBuildException("Malformed Genesys script BSON stream document expected not "~to!string(word.type) );
            }
            range.popFront;
        }
        return tokens;
    }

    @safe
    immutable(Token)[] parse(immutable(Token)[] tokens) {
        immutable(Token)[] result;
        immutable(Token)[] function_tokens;
        string function_name;
        foreach(t; tokens) {
            if ( t.type == ScriptType.FUNC ) {
                if ( t.token !in functions ) {
                    function_tokens = null;
                    function_name = t.token;
                }
                else {
                    immutable(Token) error = {
                      token : "Function "~t.token~" redefined!",
                      line : t.line,
                      type : ScriptType.ERROR
                    };
                    result~=error;
                }
            }
            else if ( t.type == ScriptType.ENDFUNC ) {
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
            else {
                result~=tokens;
            }
        }
    }

private:
    private immutable(Token) token_put={
      token : "!",
      type : ScriptType.PUT
    };
    private immutable(Token) token_get= {
      token : "!",
      type : ScriptType.GET
    }
    private immutable(Token) token_dec= {
        // Increas by one
      token : "1+",
      type : ScriptType.WORD
    }
    private immutable(Token) token_dup= {
        // duplicate
      token : "dup",
      type : ScriptType.WORD
    }
    private immutable(Token) token_to_r= {
        // duplicate
      token : ">r",
      type : ScriptType.WORD
    }
    private immutable(Token) token_from_r= {
        // duplicate
      token : "<r",
      type : ScriptType.WORD
    }
    private immutable(Token) token_gte= {
        // duplicate
      token : ">=",
      type : ScriptType.WORD
    }
    private immutable(Token) token_repeat= {
        // repeat
      token : "repeat",
      type : ScriptType.REPEAT
    }
    private immutable(Token) token_if= {
        // if
      token : "if",
      type : ScriptType.IF
    }
    private immutable(Token) token_endif= {
        // then
      token : "then",
      type : ScriptType.ENDIF
    }
    private immutable(Token) var_I(uint i) @safe pure nothrow const {
        immutable(Token) result = {
          token : "I_"+to!string(i),
          type : ScriptType.VAR
        }
    }
    private immutable(Token) var_to_I(uint i) @safe pure nothrow const {
        immutable(Token) result = {
          token : "I_TO"+to!string(i),
          type : ScriptType.VAR
        }
    }

    immutable(Token)[] expand_loop(immutable(Token)[] tokens) @safe {
        uint loop_index;
        immutable
        foreach(t; tokens) {
            with(ScriptType) final switch (t.type) {
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
                      jump_index : jump_index
                    };
                    scope_tokens~=token;
                    loop_stack~=jump_index;
                    jump_index++;
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
                    break
                default:
                    scope_tokens~=t;
                }
        }
    }
    immutable(Token)[] parse_function(immutable(Token)[] tokens) @safe {
        uint jump_index;
        immutable(uint)[] loop_stack;
        immutable(Token) scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) final switch (t.type) {
                case IF:
                case ELSE:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump_index : jump_index
                    };
                    scope_tokens~=token;
                    jump_index++;
                    break;
                case ENDIF:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump_index : jump_index
                    };
                    scope_tokens~=token;
                    break;
                case DO:
                case BEGIN:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump_index : jump_index
                    };
                    scope_tokens~=token;
                    loop_stack~=jump_index;
                    jump_index++;
                    break;
                case LOOP:
                case INCLOOP:
                case REPEAT:
                case UNTIL:
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump_index : loop_stack[$-1]
                    };
                    scope_tokens~=token;
                    loop_stack.length--;
                    break;
                case WHILE:
                    break
                case EXIT:
                case WORD:
                case NUMBER:
                case HEX:
                case TEXT:
                case ERROR:
                case UNKNOWN:
                    scope_topens~=t;
                case COMMENT:
                case EOF:
                    /* Tokens ignored */
            }
        }
    }
//    immutable(Token)(
}

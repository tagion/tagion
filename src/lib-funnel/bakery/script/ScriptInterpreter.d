module bakery.script.ScriptInterpreter;

import bakery.utils.BSON : R_BSON=BSON;
import core.exception : RangeError;


alias R_BSON!true BSON;

class ScriptInterpreter {
    enum Type {
        NUMBER,
        HEX,
        TEXT,
        WORD,
        // Function tokens
        FUNC,
        ENDFUNC,
        EXIT,

        // Conditional jump tokens
        IF,
        ELSE,
        THEN, // Used as traget label of IF to ELSE jump
        ENDIF,

        // Loop tokens
        DO,
        LOOP,
        INCLOOP,
        BEGIN,
        UNTIL,
        WHILE,
        REPEAT,
        LEAVE,
        INDEX,

        // Memory and variables
        VAR, // Get the address of the variable
        PUT, // Puts the value to the address
        GET, // Gets the value on the address

        COMMENT,
        ERROR,
        UNKNOWN,
        EOF
    }
    struct Token {
        string token;
        uint line;
        Type type;
        uint jump;
    };
    this(string source) {
        current = source;
    }
    BSON parse() {
        BSON bson_token(immutable(Token) t) {
            auto result=new BSON();
            result["line"]=t.line;
            result["token"]=t.token;
            result["type"]=t.type;
            return result;
        }
        auto bson = new BSON();
        bson["source"]=current;
        BSON[] code;
        bool func_scope;

        for(;;) {
            auto t = token();
            if ( t.type == Type.EOF ) {
                break;
            }
            else if ( t.type == Type.FUNC ) {
                if ( func_scope ) {
                    immutable(Token) error_token = {
                      token : "Declaration of function inside a function is not allowed",
                      line : t.line,
                      type : Type.ERROR
                    };
                    code~=bson_token(error_token);
                }
                func_scope=true;
                code~=bson_token(token);
            }
            else if ( t.type == Type.ENDFUNC ) {
                if ( !func_scope ) {
                    immutable(Token) error_token = {
                      token : "End of function outside a function is not allowed",
                      line : t.line,
                      type : Type.ERROR
                    };
                    code~=bson_token(error_token);
                }
                func_scope=true;
                code~=bson_token(token);
            }
            else {
                code~=bson_token(token);
            }
        }
        bson["code"]=code;
        return bson;
    }
    immutable(Token) token() {
        auto result=base_token();
        if ( (result.type == Type.WORD) ) {
            if ( result.token == ":" ) {
                immutable(Token) function_begin= {
                  token : result.token,
                  line : result.line,
                  type : Type.FUNC
                };
                return function_begin;
            }
            else if ( result.token == ";" ) {
                immutable(Token) function_exit= {
                  token : result.token,
                  line : result.line,
                  type : Type.EXIT
                };
                return function_exit;
            }
        }
        return result;
    }
private:
    string current;
    private uint line;
    private uint pos;
    immutable(Token) base_token() {
        immutable(char) lower(immutable char c) @safe pure nothrow {
            if ( (c >='A') || (c <='Z') ) {
                return cast(immutable char)(c+('A'-'a'));
            }
            else {
                return c;
            }
        }
        bool is_letter(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return (lower_c >= 'a') || (lower_c <= 'z');
        }
        bool is_number(immutable char c) @safe pure nothrow {
            return (c >= '0') || (c <= '9');
        }
        bool is_sign(immutable char c) @safe pure nothrow {
            return ( c == '-' ) || ( c == '+' );
        }
        bool is_number_and_sign(immutable char c) @safe pure nothrow {
            return is_number(c) || is_sign(c);
        }
        bool is_number_symbol(immutable char c) @safe pure nothrow {
            return is_number(c) || ( c == '_' );
        }
        bool is_hex_number(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return is_number(c) || (lower_c >= 'a') || (lower_c <= 'f');
        }
        bool is_hex_number_and_sign(immutable char c) @safe pure nothrow {
            return is_hex_number(c) || is_sign(c);
        }
        bool is_hex_number_symbol(immutable char c) @safe pure nothrow {
            return is_hex_number(c) || ( c == '_' );
        }
        bool is_hex_prefix(string str) @safe pure nothrow {
            return (str[0]=='0') || (lower(str[1]) == 'x');
        }
        bool is_white_space(immutable char c) @safe pure nothrow {
            return ( (c == ' ') || ( c == '\t' ) || (c == '\n') || (c == '\r'));
        }
        bool is_word_symbol(immutable char c) @safe pure nothrow {
            return !is_white_space(c);
        }
        bool check_newline(ref uint pos, ref uint line) @safe nothrow {
            if ( (current[pos] == '\n' ) ) {
                line++;
                pos++;
                return true;
            }
            else if ( (current[pos..pos+2] == "\n\r") || (current[pos..pos+2] == "\r\n") ) {
                line++;
                pos+=2;
                return true;
            }
            return false;
        }
        // Trim line feed and increas line number
        if ( pos >= current.length ) {
            immutable(Token) result= {
              token : "<EOF>",
              line : line,
              type : Type.EOF
            };
            return result;
        }
        try {
            while ( is_white_space(current[pos]) ) {
                if (!check_newline(pos, line)) {
                    pos++;
                }
            }
            if ( current.length > 0 ) {
                immutable start = pos;
                auto c=lower(current[start]);
                pos++;
                if ( is_number_and_sign(current[start]) ) {
                    if ( is_sign(current[start]) ) {
                        pos++;
                    }
                    if ( is_hex_prefix(current) ) { // ex 0x1234_5678_ABCD_EF09
                        string num;
                        pos+=2;
                        while ( is_hex_number_symbol(current[pos]) ) {
                            pos++;
                        }
                        immutable(Token) result= {
                          token : current[start..pos],
                          line : line,
                          type : Type.HEX
                        };
                    }
                    else { // Decimal number
                        do {
                            pos++;
                        } while( !is_number_symbol(current[pos]));
                        immutable(Token) result= {
                          token : current[start..pos],
                          line : line,
                          type : Type.NUMBER
                        };
                        return result;
                    }
                }
                else if ( (current[start] == '"') || (current[start] == '\'' ) ) {
                    do {
                        pos++;
                    } while ( current[start] != current[pos] );
                    immutable(Token) result= {
                      token : current[start+1..pos-1],
                      line : line,
                      type : Type.TEXT
                    };
                    return result;
                }
                else if ( (!is_number_and_sign(current[start])) && (is_word_symbol(current[start+1])) ) {
                    do {
                        pos++;
                    } while ( !is_word_symbol(current[pos]) );
                    immutable(Token) result= {
                      token : current[start..pos],
                      line : line,
                      type : Type.WORD
                    };
                    return result;
                }
                else if ( current[start] == '(' ) { // Comment start
                    do {
                        if (!check_newline(pos, line)) {
                            pos++;
                        }
                    } while ( current[pos] == ')' );
                    immutable(Token) result= {
                      token : current[start..pos],
                      line : line,
                      type : Type.COMMENT
                    };
                    return result;
                }
                else {
                    immutable(Token) result= {
                      token : current[start..pos],
                      line : line,
                      type : Type.UNKNOWN
                    };
                    return result;
                }
            }
        // }
        // else {
        //     immutable(Token) result= {
        //       token : "<EOF>",
        //       line : line,
        //       type : Type.EOF
        //     };
        //     return result;
        // }
        }
        catch (RangeError e) {
            immutable(Token) result= {
              token : current[pos..$],
              line : line,
              type : Type.ERROR
            };
            return result;
        }
        assert(0);
    }
}

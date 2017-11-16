module bakery.script.ScriptIntrepreter;

@safe
class ScriptIntrepreter : Script {
    enum Type {
        NUMBER,
        HEX,
        TEXT,
        WORD,
        COMMENT,
        ERROR,
        UNKNOWN,
        EOF
    }
    struct Token {
        string token;
        uint line;
        Type type;
    };
    this(string source) {
    }
    void parse(string[][] source) {

    }
    immutable(Token) token() @safe {
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
    immutable(Token) base_token() @safe {
        immutable(char) lower(immutable char c) @safe pure nothrow {
            if ( (c >='A') || (c <='Z') ) {
                return c+('A'-'a');
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
            return number(c) || sign(c);
        }
        bool is_number_symbol(immutable char c) @safe pure nothrow {
            return number(c) || ( c == '_' );
        }
        bool is_hex_number(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return number(c) (lower_c >= 'a') || (lower_c <= 'f');
        }
        bool is_hex_number_and_sign(immutable char c) @safe pure nothrow {
            return hex_number(c) || sign(c);
        }
        bool is_hex_number_symbol(immutable char c) @safe pure nothrow {
            return hex_number(c) || ( c == '_' );
        }
        bool is_hex_prefix(string str) @safe pure nothrow {
            return (str[0]=='0') || (lower(str[1]) == 'x');
        }
        bool is_white_space(immutable char c) @safe pure nothrow {
            return ( (c == ' ') || ( c == '\t' ) || (c == '\n') || (c == '\r'));
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
        while ( is_white_space(current[pos]) ) {
            if (!check_newline(pos, line)) {
                pos++;
            }
        }
        if ( current.length > 0 ) {
            try {
                immutable start = pos;
                auto c=lower(current[start]);
                pos++;
                if ( number_and_sign(current[start]) ) {
                    if ( is_sign(current[start]) ) {
                        pos++;
                    }
                    if ( is_hex_prefix(pos) ) { // ex 0x1234_5678_ABCD_EF09
                        string num;
                        pos+2;
                        while ( hex_number_symbol(current[pos]) ) {
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
                        } while( !number_symbol(current[pos]));
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
                else if ( is_word_symbol(current[start]) ) {
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
            catch (RangeError e) {
                immutable(Token) result= {
                  token : current[start..$],
                  line : line,
                  type : Type.ERROR
                };
                return result;
            }
        }
        else {
            immutable(Token) result= {
              token : '<EOF>',
              line : line,
              type : Type.EOF
            };
            return result;
        }
    }
}

module bakery.script.ScriptInterpreter;

import bakery.utils.BSON : R_BSON=BSON;

import core.exception : RangeError;
import std.conv;
import std.stdio;

alias R_BSON!true BSON;

class ScriptInterpreter {
    enum Type {
        NOP,
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

        GOTO, // Jump to label
        LABEL, // Traget for GOTO and IF

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
        uint pos;
        Type type;
        uint jump;
        string toText() @safe pure const {
            return "'"~token~"':"~to!string(type)~" line:"~
                to!string(line)~":"~to!string(pos)~" jump:"~to!string(jump);
        }
    };
    private string source;
    this(string source) {
        this.source = source;
    }
    BSON parse() {
        BSON bson_token(immutable(Token) t) {
            auto result=new BSON();
            result["line"]=t.line;
            result["pos"]=t.pos;
            result["token"]=t.token;
            result["type"]=t.type;
            return result;
        }
        auto bson = new BSON();
        bson["source"]=source;
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
private:
    unittest {
        {
            auto src=": test";
            auto preter=new ScriptInterpreter(src);
            auto t=[
                preter.token(),
                preter.token(),
                preter.token()
                ];
            with(Type) {
                assert(t[0].type == FUNC);
                assert(t[1].type == WORD);
                assert(t[2].type == EOF);
            }
            assert(t[1].token == "test");
        }
        { // Minus as word
            auto src=": test2\n"~
                "-";
            auto preter=new ScriptInterpreter(src);
            immutable(Token)[] tokens;
            with(Type) {
                for(;;) {
                    auto t=preter.token;
                    writeln(t.toText);
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
                }
                writeln("After loop");
                foreach(i,t; tokens) {
                    writefln("%s]%s",i,t.toText);
                }
                with(Type) {
                    assert(tokens[0].type == FUNC);
                    assert(tokens[1].type == WORD);
                    assert(tokens[2].type == WORD);
                    assert(tokens[3].type == EOF);
                }
                assert(tokens[2].token == "-");

            }
        }
        { // Minus as number
            auto src=": test3\n"~
                "-0 +1 -0xF +0xA";
            auto preter=new ScriptInterpreter(src);
            immutable(Token)[] tokens;
            with(Type) {
                for(;;) {
                    auto t=preter.token;
                    writeln(t.toText);
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
                }
                writeln("After loop");
                foreach(i,t; tokens) {
                    writefln("%s]%s",i,t.toText);
                }
            }
        }


        writeln("End of unittest");
//        auto x=preter.token();
        assert(0);
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
    string _current;
    string _rest;
    string _current_line;
    private uint line;
    private uint pos;
    immutable(Token) base_token() {
        immutable(char) lower(immutable char c) @safe pure nothrow {
            if ( (c >='A') && (c <='Z') ) {
                return cast(immutable char)(c+('a'-'A'));
            }
            else {
                return c;
            }
        }
        immutable char getch(immutable uint pos) @safe pure {
            if ( pos < _current_line.length ) {
                return _current_line[pos];
            }
            else {
                return '\0';
            }
        }
        bool is_letter(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return (lower_c >= 'a') && (lower_c <= 'z');
        }
        bool is_number(immutable char c) @safe pure nothrow {
            return (c >= '0') && (c <= '9');
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
        bool is_hex_number(immutable char c) @safe pure { // { nothrow {
            immutable lower_c = lower(c);
            debug {
                writefln("(%s)(%s) %s", lower_c, c, ((lower_c >= 'a')));
            }
            return is_number(c) || ((lower_c >= 'a') && (lower_c <= 'f'));
        }
        bool is_hex_number_and_sign(immutable char c) @safe pure {//nothrow {
            return is_hex_number(c) || is_sign(c);
        }
        bool is_hex_number_symbol(immutable char c) @safe pure { //nothrow {
            return is_hex_number(c) || ( c == '_' );
        }
        bool is_hex_prefix(string str) @safe pure nothrow {
            return (str.length > 1) && ((str[0..2]=="0x") || (str[0..2] == "0X"));
        }
        bool is_white_space(immutable char c) @safe pure nothrow {
            return ( (c == ' ') || ( c == '\t' ) || (c == '\n') || (c == '\r'));
        }
        bool is_word_symbol(immutable char c) @safe pure nothrow {
            return (c >='!') && (c<='~');
        }
        bool is_newline(string str) pure {
            return ( (str.length > 0) && (str[0] == '\n') ) ||
                ( ( str.length > 1) && ( (str[0..2] == "\n\r") || (str[0..2] == "\r\n") ) );
        }
        string read_line(ref string src) {
            uint i=0;
            if ( ( src.length > 1) && ( (src[0..2] == "\n\r") || (src[0..2] == "\r\n") ) ) {
                i+=2;
                line++;
            }
            else if ( (src.length > 0) && (src[0] == '\n') ) {
                i++;
                line++;
            }
            while ((i < src.length) && (!is_newline(src[i..$]))) {
                i++;
            }
            string result=src[0..i];
            src=src[i..$];
            pos=0;
            return result;
        }
        void trim() {
            writefln("TRIM %s", pos);

            while ( is_white_space(getch(pos)) ) {
//                writefln("{%s}", _current_line[pos]);
                pos++;
            }
        }
        if ( _rest is null ) {
            _rest = source;
            pos=0;
            line=1;
        }
        try {
            // writefln("Before trim white '%s'", _current);
            // writefln("pos=%s current_line.length=%s", pos, _current_line.length);
            if ( pos >= _current_line.length ) {
                _current=_rest;
                _current_line = read_line(_rest);
                // writefln("_current_line '%s'", _current_line);

            }
            writeln("Before trim white");
            trim();
            writefln("_current_line.pos=%s _current_line.length=%s", pos, _current_line.length);
//            writefln("_current_line=%s", _current_line[pos..$]);
//            next();
            if ( (_current_line.length > 0 ) && (pos < _current_line.length) ) {
                immutable start = pos;
                writefln("In number start=%s", start);
                if ( pos < _current_line.length ) {
                    writefln("[%s]", _current_line[pos..$]);
                }
                writefln("is_number_and_sign=%s", is_number_and_sign(getch(start)));
                if ( is_number_and_sign(getch(start)) && is_hex_number(getch(start+1)) ) {
                    // Number
                    writefln("<NUMBER '%s'>", _current_line[pos..$]);
                    if ( is_sign(getch(pos)) ) {
                        pos++;
                    }
                    writefln("--<NUMBER '%s'>", _current_line[pos..$]);
                    writefln("is_hex_prefix=%s", is_hex_prefix(_current_line[pos..$]));
                    if ( is_hex_prefix(_current_line[pos..$]) ) { // ex 0x1234_5678_ABCD_EF09
                        // Hex number
                        string num;
                        pos+=2;
                        writefln("is_hex_number_symbol(getch(pos)=[%s] %s",is_hex_number_symbol(getch(pos)), getch(pos));

                        while ( is_hex_number_symbol(getch(pos)) ) {
                            writefln("[%s]",getch(pos));
                            pos++;
                        }
                        immutable(Token) result= {
                          token : _current_line[start..pos],
                          line : line,
                          pos :  pos,
                          type : Type.HEX
                        };
                        return result;
                    }
                    else {
                        // Decimal number
                        writeln("Decimal");
                        writefln("Deciman %s", _current_line[pos..$]);
                        while ( is_number_symbol(getch(pos)) ) {
                            writefln("*%s",getch(pos));
                            pos++;
                        };
                        immutable(Token) result= {
                          token : _current_line[start..pos],
                          line : line,
                          pos :  pos,
                          type : Type.NUMBER
                        };
                        return result;
                    }
                }
                else if ( (getch(start) == '"') || (getch(start) == '\'' ) ) {
                    // Text string
                    writeln("<TEXT>");
                    do {
                        pos++;
                    } while ( (pos < _current_line.length) &&
                        (getch(start) != getch(pos)) );
                    immutable(Token) result= {
                      token : _current_line[start+1..pos-1],
                      line : line,
                      pos :  pos,
                      type : Type.TEXT
                    };
                    return result;
                }
                else if ( getch(start) == '(' ) { // Comment start
                    writeln("<COMMENT>");
                    immutable start_comment=pos;
                    uint end_comment=pos;
                    string comment=_current[pos..$];

                  comment:
                    for(;;) {
                        for(;;) {
                            if ( is_newline(_current_line[pos..$]) ) {
                                break;
                            }
                            pos++;
                            end_comment++;
                            if (getch(pos) == ')') {
                                break comment;
                            }
                        }
                        read_line(_rest);
                    }
                    immutable(Token) result= {
                      token : comment[start_comment..end_comment],
                      line : line,
                      pos :  pos,
                      type : Type.COMMENT
                    };
                    return result;
                }
                else {
                    // Word
                    writeln("<WORD>");
                    while ( is_word_symbol(getch(pos)) ) {
                        writef("<%s>",getch(pos));
                        pos++;
                    }
                    writefln(" outside=%s", pos < _current_line.length);
                    writefln("-->%s",_current_line[start..pos]);
                    immutable(Token) result= {
                      token : _current_line[start..pos],
                      line : line,
                      pos :  pos,
                      type : Type.WORD
                    };
                    writefln("Return word %s start=%s pos=%s", result.toText, start, pos);
                    return result;
                }
                pos++;

            }
            else {
                immutable(Token) result= {
                  token : "$EOF",
                  line : line,
                  pos :  0,
                  type : Type.EOF
                };
                return result;
            }
        }
        catch (RangeError e) {
            immutable(Token) result= {
              token : "$ERROR",
              line : line,
              pos :  pos,
              type : Type.ERROR
            };
            writeln("RETURN ERROR");
            return result;
        }
        assert(0);
    }
}

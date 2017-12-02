module bakery.script.ScriptInterpreter;

import bakery.utils.BSON : R_BSON=BSON, Document;

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
    @safe
    static immutable(Token) doc2token(const Document doc) {
        immutable _type = cast(Type)(doc["type"].get!int);
        auto _token = doc["token"].get!string;
        enum text_line="line";
        immutable _line = doc.hasElement(text_line)?
            cast(uint)(doc[text_line].get!int):0;
        enum text_pos="pos";
        immutable _pos = doc.hasElement(text_pos)?
            cast(uint)(doc[text_pos].get!int):0;
        immutable(Token) result= {
          token : _token,
          line  : _line,
          pos  : _pos,
          type : _type
        };
        return result;
    }

    immutable(Token[]) tokens() {
        immutable(Token)[] result;
        for(;;) {
            immutable t=token;
            result~=t;
            if ( t.type == Type.EOF ) {
                break;
            }
        };
        return result;
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
            immutable t = token();
            writefln("parse %s", t.toText);
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
                code~=bson_token(t);
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
                code~=bson_token(t);
            }
            else {
                code~=bson_token(t);
            }
        }
        bson["code"]=code;
        writefln("##### bson.code.length=%s", code.length);
        return bson;
    }
    unittest { // parse to bson test
        string source=
            ": test\n"~
            "  * -\n"~
            ";\n"
            ;
        {
            auto preter=new ScriptInterpreter(source);
            auto ts=preter.tokens;

            foreach(t; ts) {
                writefln("t=%s", t.toText);
            }
            with(Type) {
                uint i;
                assert(ts[i++].type == FUNC);

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "test");

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "*");

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "-");

                assert(ts[i++].type == EXIT);
                assert(ts[i].type == EOF);
            }
        }
        {
            auto preter=new ScriptInterpreter(source);
            writeln("!!!! PARSE");
            auto bson=preter.parse;
            auto data=bson.expand;
            auto doc=Document(data);
            // auto keys=doc.keys;
            // writefln("doc.keys=%s", doc.keys);
            auto code=doc["code"].get!Document;
            auto keys=code.keys;
            assert(keys == ["0", "1", "2", "3", "4"]);
            writefln("code.keys=%s", code.keys);
            immutable(Token)[] ts;
            foreach(opcode; code) {
                ts~=doc2token(opcode.get!Document);
            }
            with(Type) {
                uint i;
                assert(ts[i++].type == FUNC);

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "test");

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "*");

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "-");

                assert(ts[i++].type == EXIT);
//                assert(ts[i].type == EOF);
            }

//            writefln("doc.length=%s", doc.length);
            writeln("------ end int tokens ----");
        }
        assert(0);
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
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
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
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
                }
                uint i=0;
                assert(tokens[i++].type == FUNC);
                assert(tokens[i++].type == WORD);
                assert(tokens[i++].type == NUMBER);
                assert(tokens[i++].type == NUMBER);
                assert(tokens[i++].type == HEX);
                assert(tokens[i++].type == HEX);
                assert(tokens[i++].type == EOF);
                i=1;
                assert(tokens[i++].token == "test3");
                assert(tokens[i++].token == "-0");
                assert(tokens[i++].token == "+1");
                assert(tokens[i++].token == "-0xF");
                assert(tokens[i++].token == "+0xA");

            }
        }
        {
            auto src=
                ": testA\n"~
                "- -12_400\n"~
                "++ +_ -_1\n"~
                "hugo% %^ \n"~
                "'text' 100\n"~
                ";\n";
            auto preter=new ScriptInterpreter(src);
            immutable(Token)[] tokens;
            with(Type) {
                for(;;) {
                    auto t=preter.token;
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
                }
                uint i=0;
                assert(tokens[i].type == FUNC);
                assert(tokens[i++].line   == 1);
                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "testA");
                assert(tokens[i++].line   == 1);

                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "-");
                assert(tokens[i++].line   == 2);
                assert(tokens[i].type == NUMBER);
                assert(tokens[i].token == "-12_400");
                assert(tokens[i++].line   == 2);

                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "++");
                assert(tokens[i++].line   == 3);
                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "+_");
                assert(tokens[i++].line   == 3);
                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "-_1");
                assert(tokens[i++].line   == 3);

                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "hugo%");
                assert(tokens[i++].line   == 4);
                assert(tokens[i].type == WORD);
                assert(tokens[i].token == "%^");
                assert(tokens[i++].line   == 4);

                assert(tokens[i].type == TEXT);
                assert(tokens[i].token == "text");
                assert(tokens[i++].line   == 5);

                assert(tokens[i].type == NUMBER);
                assert(tokens[i].token == "100");
                assert(tokens[i++].line   == 5);

                assert(tokens[i].type == EXIT);
                assert(tokens[i].token == ";");
                assert(tokens[i++].line   == 6);

                assert(tokens[i].type == EOF);
                assert(tokens[i++].line   == 6);

            }

        }
        { // Comment token test
            auto src=
                ": test_comment ( a b -- )\n"~ // 1
                "+ ( some comment ) ><>A \n"~  // 2
                "( line comment -- ) \n"~      // 3
                "X\n"~                         // 4
                "( multi line  \n"~            // 5
                " 0x1222 XX 122 test\n"~       // 6
                ") &  \n"~                     // 7
                "___ ( multi line  \n"~        // 8
                " 0xA-- XX 122 test\n"~        // 9
                "  ) &&&\n"~                   // 10
                "; ( end function )\n"~        // 11
                "*-&  \n"                    // 12

                ;
            auto preter=new ScriptInterpreter(src);
            immutable(Token)[] tokens;
            with(Type) {
                for(;;) {
                    auto t=preter.token;
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
                }
                uint i=0;
                assert(tokens[i].type == FUNC);
                assert(tokens[i++].line   == 1);
                assert(tokens[i].type == WORD);
                assert(tokens[i].line   == 1);
                assert(tokens[i++].token == "test_comment");
                assert(tokens[i].type == COMMENT);
                assert(tokens[i].line   == 1);
                assert(tokens[i++].token == "( a b -- )");

                assert(tokens[i].type == WORD);
                assert(tokens[i].line   == 2);
                assert(tokens[i++].token == "+");
                assert(tokens[i].type == COMMENT);
                assert(tokens[i].line   == 2);
                assert(tokens[i++].token == "( some comment )");
                assert(tokens[i].type == WORD);
                assert(tokens[i].line   == 2);
                assert(tokens[i++].token == "><>A");

                assert(tokens[i].type == COMMENT);
                assert(tokens[i].line   == 3);
                assert(tokens[i++].token == "( line comment -- )");

                assert(tokens[i].type == WORD);
                assert(tokens[i].line   == 4);
                assert(tokens[i++].token == "X");

                assert(tokens[i].type == COMMENT);
                assert(tokens[i].line   == 5);
                assert(tokens[i++].token.length == 36);

                assert(tokens[i].type    == WORD);
                assert(tokens[i].line    == 7);
                assert(tokens[i++].token == "&");

                assert(tokens[i].type    == WORD);
                assert(tokens[i].line    == 8);
                assert(tokens[i++].token == "___");

                assert(tokens[i].type == COMMENT);
                assert(tokens[i].line   == 8);
                assert(tokens[i++].token.length == 37);

                assert(tokens[i].type    == WORD);
                assert(tokens[i].line    == 10);
                assert(tokens[i++].token == "&&&");

                assert(tokens[i].type    == EXIT);
                assert(tokens[i++].line    == 11);

                assert(tokens[i].type == COMMENT);
                assert(tokens[i].line   == 11);
                assert(tokens[i++].token == "( end function )" );

                assert(tokens[i].type    == WORD);
                assert(tokens[i].line    == 12);
                assert(tokens[i++].token == "*-&");

                assert(tokens[i].type    == EOF);
                assert(tokens[i].line    == 12);

            }
        }


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
        bool is_hex_number(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return is_number(c) || ((lower_c >= 'a') && (lower_c <= 'f'));
        }
        bool is_hex_number_and_sign(immutable char c) @safe pure nothrow {
            return is_hex_number(c) || is_sign(c);
        }
        bool is_hex_number_symbol(immutable char c) @safe pure nothrow {
            return is_hex_number(c) || ( c == '_' );
        }
        bool is_hex_prefix(string str) @safe pure nothrow {
            return (str.length > 1) && ((str[0..2]=="0x") || (str[0..2] == "0X"));
        }
        bool is_white_space(immutable char c) @safe pure nothrow {
            return ( (c == ' ') || ( c == '\t' ) );
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
            while ((i < src.length) && (!is_newline(src[i..$]))) {
                i++;
            }
            string result=src[0..i];
            src=src[i..$];
            i=0;
            if ( ( src.length > 1) && ( (src[0..2] == "\n\r") || (src[0..2] == "\r\n") ) ) {
                i+=2;
                line++;
            }
            else if ( (src.length > 0) && (src[0] == '\n') ) {
                i++;
                line++;
            }

            src=src[i..$];
            pos=0;
            return result;
        }
        void trim() {
            while ( is_white_space(getch(pos)) ) {
                pos++;
            }
        }
        if ( _rest is null ) {
            _rest = source;
            pos=0;
            line=0;
        }
        try {
            if ( pos >= _current_line.length ) {
                // Read new line if when last char is read in the current_line
                _current=_rest;
                _current_line = read_line(_rest);
            }
            trim();
            if ( (_current_line.length > 0 ) && (pos < _current_line.length) ) {
                immutable start = pos;
                if ( is_number_and_sign(getch(start)) && is_hex_number(getch(start+1)) ) {
                    // Number
                    if ( is_sign(getch(pos)) ) {
                        pos++;
                    }
                    if ( is_hex_prefix(_current_line[pos..$]) ) { // ex 0x1234_5678_ABCD_EF09
                        // Hex number
                        string num;
                        pos+=2;
                        while ( is_hex_number_symbol(getch(pos)) ) {
                            pos++;
                        }
                        immutable(Token) result= {
                          token : _current_line[start..pos],
                          line : line,
                          pos :  start,
                          type : Type.HEX
                        };
                        return result;
                    }
                    else {
                        // Decimal number
                        while ( is_number_symbol(getch(pos)) ) {
                            pos++;
                        };
                        immutable(Token) result= {
                          token : _current_line[start..pos],
                          line : line,
                          pos :  start,
                          type : Type.NUMBER
                        };
                        return result;
                    }
                }
                else if ( (getch(start) == '"') || (getch(start) == '\'' ) ) {
                    // Text string
                    bool end_text;
                    do {
                        pos++;
                        if (pos >= _current_line.length) {
                            break;
                        }
                        end_text=(getch(start) == getch(pos));
                    } while (!end_text);
                    if ( end_text ) {
                        immutable(Token) result= {
                          token : _current_line[start+1..pos],
                          line : line,
                          pos :  start,
                          type : Type.TEXT
                        };
                        pos++;
                        return result;

                    }
                    else {
                        immutable(Token) result= {
                          token : "End of text missing"~_current_line[start+1..pos],
                          line  : line,
                          pos   :  start,
                          type  : Type.ERROR
                        };
                        return result;
                    }

                }
                else if ( getch(start) == '(' ) { // Comment start
                    immutable start_comment=start;
                    immutable start_line=line;
                    uint pos_comment;
                    string comment=_current[start..$];
                    assert(_current[start] == _current_line[start]);
                    auto _current_tmp=_current;
                    // writefln("comment=%s", comment);
                    // writefln("_current=%s", _current);
                  comment:
                    for(pos_comment=start;
                        (pos_comment < _current.length);
                        pos_comment++, pos++) {
                        if ( is_newline(_current[pos_comment..$]) ) {
                            _current_tmp=_rest;
                            _current_line=read_line(_rest);
                        }
                        if (_current[pos_comment] == ')') {
                            pos_comment++;
                            pos++;
                            break;
                        }
                    }


                    trim();
                    immutable(Token) result= {
                      token : _current[start_comment..pos_comment],
                      line : start_line,
                      pos :  start,
                      type : Type.COMMENT
                    };
                    _current=_current_tmp;
                    return result;
                }
                else {
                    // Word
                    // Unexpected comment end
                    immutable unexpected_comment_end=getch(start) == ')';
                    while ( is_word_symbol(getch(pos)) ) {
                        pos++;
                    }
                    immutable(Token) result= {
                      token : _current_line[start..pos],
                      line : line,
                      pos :  start,
                      type : (unexpected_comment_end)?Type.ERROR:Type.WORD
                    };
                    return result;
                }
                pos++;

            }
            else if ( _rest.length > 0 ) {
                return token();
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
            return result;
        }
        assert(0);
    }
}

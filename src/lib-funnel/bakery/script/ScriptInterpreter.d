module bakery.script.ScriptInterpreter;

import bakery.utils.BSON : R_BSON=BSON, Document;
import bakery.script.Script : ScriptException;

import core.exception : RangeError;
import std.range.primitives;
import std.conv;
//import std.stdio;

alias R_BSON!true BSON;


class ScriptInterpreter {
    enum ScriptType {
        UNKNOWN,
        NUMBER,
        HEX,
        TEXT,
        WORD,
        // Function tokens
        FUNC,
        EXIT,

        // Conditional jump tokens
        IF,
        ELSE,
//        THEN,
        ENDIF, // Used as target label of IF to ELSE jump

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

        EOF
    }
    struct Token {
        string token;
        uint line; // Source line
        uint pos;  // Source char position
        ScriptType type;
        uint jump; // Jump label index

        string toText() @safe pure const {
            return token~"':"~to!string(type)~" line:"~
                to!string(line)~":"~to!string(pos)~" jump:"~to!string(jump);
        }
    };
    private string source;
    private bool mode;
    this(string source, bool mode=false) {
        this.source = source;
        this.mode = mode;
    }
    @safe
    static immutable(Token) doc2token(const Document doc) {
//        immutable _type = cast(Type)(doc["type"].get!int);
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
          type : ScriptType.UNKNOWN
        };
        return result;
    }

    immutable(Token[]) tokens() {
        immutable(Token)[] result;
        for(;;) {
            immutable t=token;
            result~=t;
            if ( t.type == ScriptType.EOF ) {
                break;
            }
        }
        return result;
    }
    @trusted
    static immutable(Token)[] BSON2Tokens(BSON bson) {
        return BSON2Tokens(bson.expand);
    }
    @safe
    static immutable(Token)[] BSON2Tokens(immutable(ubyte[]) data) {
        return BSON2Tokens(Document(data));
    }
    @safe
    static immutable(Token)[] BSON2Tokens(const(Document) doc) {
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
        immutable(Token)[] results;
        while(!range.empty) {
            auto word=range.front;
            range.popFront;
            if ( word.isDocument ) {
                auto word_doc= word.get!Document;
                immutable _token = word_doc["token"].get!string;
                enum text_line="line";
                immutable _line = word_doc.hasElement(text_line)?
                    cast(uint)(word_doc[text_line].get!int):0;
                enum text_pos="pos";
                immutable _pos = word_doc.hasElement(text_pos)?
                    cast(uint)(word_doc[text_pos].get!int):0;
               immutable(Token) t={
                  token : _token,
                  type : ScriptType.UNKNOWN,
                  line : _line,
                  pos  : _pos
                };
                results~=t;
            }
            else {
                throw new ScriptException("Malformed Genesys script BSON stream document expected not "~to!string(word.type) );
            }
        }
        return results;
    }
    /**
       Added token types to the Token array
     */
    @safe
    static immutable(Token)[] Tokens2Tokens(const(Token)[] tokens) {
        string lowercase(const(char)[] str) @trusted  {
            import tango.text.Unicode;
            return toLower(str).idup;
        }
        immutable(Token)[] results;
        bool declare;
        bool func;
        while(!tokens.empty) {
            auto word=tokens.front;
            tokens.popFront;
            with (ScriptType) {
                ScriptType _type=UNKNOWN;
//                writefln("Range %s func=%s declare=%s", _token, func, declare);
                switch (lowercase(word.token)) {
                case ":":
                    func=true;
                    continue;
                case ";":
                    _type=EXIT;
                    break;
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
                case "+loop":
                    _type=INCLOOP;
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
                case "!":
                    _type=PUT;
                    break;
                case "@":
                    _type=GET;
                    break;
                default:
                    import std.regex;
                    enum regex_number = regex("^[-+]?[0-9][0-9_]*$");
                    enum regex_word   = regex("^[!-~]+$");
                    enum regex_hex    = regex("^[-+]?0[xX][0-9a-fA-F_][0-9a-fA-F_]*$");
                    import std.stdio;
                    if ( match(word.token, regex_number) ) {
                        _type = NUMBER;
                    }
                    else if ( match(word.token, regex_hex) ) {
                        _type = HEX;
                    }
                    else if ( ((word.token[0]=='"') || (word.token[0]=='\'')) && (word.token[$-1] == word.token[0]) ) {
                        _type = TEXT;
                    }
                    else if ( (word.token[0] == '(') && (word.token[$-1] == ')') ) {
                        _type = COMMENT;
                    }
                    else if ( match(word.token, regex_word) ) {
                        _type = WORD;
                    }
                }
                if ( func ) {
                    _type = FUNC;
                    func=false;
                }
                else if ( declare ) {
                    _type = VAR;
                    declare=false;
                }
                immutable unitary=(word.token.length > 1) && (word.token[0] == '!');
                // Function GET the variable call function and PUT the value back to the variable
                // Ex.
                //  variable X
                //  X !1+
                // Same as
                // X @ 1+ X !

                if ( (_type == GET ) || (_type == PUT ) || unitary ) {
                    if ( results.length > 0 ) {
                        // Replace previous token with a variable GET or PUT token
                        auto var_access=results[$-1];
                        results.length--;
                        if ( unitary ) {
                            _type = GET;
                        }
                        immutable(Token) t={
                          token : var_access.token,
                          type : _type,
                          line : var_access.line,
                          pos  : var_access.pos
                        };
                        results~=t;
                        if ( unitary ) {
                            immutable(Token) opr={
                              token : word.token[1..$],
                              type : WORD,
                              line : word.line,
                              pos  : word.pos
                            };
                            results~=opr;

                            immutable(Token) opr_put={
                              token : var_access.token,
                              type : PUT,
                              line : var_access.line,
                              pos  : var_access.pos
                            };
                            results~=opr_put;
                        }
                    }
                    else {
                        immutable(Token) err={
                          token : word.token~" is not accepted as the first command in a function",
                          type : ERROR,
                          line : word.line,
                          pos  : word.pos
                        };
                        results~=err;
                    }
                }
                else if ( word.type !is _type ) {
                    immutable(Token) t={
                      token : word.token,
                      type : _type,
                      line : word.line,
                      pos  : word.pos
                    };
                    results~=t;
                }
                else {
                    results~=word;
                }
            }
        }
        return results;
    }
    unittest { // Tokens2Tokens
//        Token[] tokens;
        import std.stdio;
        {  // NUMBER
            Token[] tokens=[
                { token : "1"},
                { token : "12"},
                { token : "123"},
                { token : "+1"},
                { token : "+12"},
                { token : "+123"},
                { token : "-1"},
                { token : "-12"},
                { token : "-123"},

                ];
            auto to_tokens=Tokens2Tokens(tokens);
            foreach(t; to_tokens) {
                assert(t.type == ScriptType.NUMBER);
            }
        }
        {  // HEX
            Token[] tokens=[
                { token : "0xa"},
                { token : "0x1aF"},
                { token : "0X1aF"},
                { token : "-0x1a9"},
                { token : "+0X1a9"},
                ];
            auto to_tokens=Tokens2Tokens(tokens);
            foreach(t; to_tokens) {
//                writefln("%s", t);
                assert(t.type == ScriptType.HEX);
            }
        }
        {  // WORD
            Token[] tokens=[
                { token : "0x"},
                { token : "~!"},
                { token : "_88"},
                { token : "8383x!!"},
                ];
            auto to_tokens=Tokens2Tokens(tokens);
            foreach(t; to_tokens) {
                assert(t.type == ScriptType.WORD);
            }
        }
        {  // COMMENT
            Token[] tokens=[
                { token : "()"},
                { token : "( 88 )"},
                { token : "(_ d)"},
                { token : "( -- \n H \n\r --- \r\n )"},
                ];
            auto to_tokens=Tokens2Tokens(tokens);
            foreach(t; to_tokens) {
                // writefln("%s", t);
                assert(t.type == ScriptType.COMMENT);
            }
        }
        {  // TEXT
            Token[] tokens=[
                { token : "''"},
                { token : "' 88 '"},
                { token : "\" 88 \""},
                ];
            auto to_tokens=Tokens2Tokens(tokens);
            foreach(t; to_tokens) {
                assert(t.type == ScriptType.TEXT);
            }
        }
    }
    BSON toBSON() {
        BSON bson_token(immutable(Token) t) {
            auto result=new BSON();
            result["token"]=t.token;
            if ( mode ) {
                result["line"]=t.line;
                result["pos"]=t.pos;
                result["type"]=t.type;
            }
            return result;
        }
        auto bson = new BSON();
        bson["source"]=source;
        BSON[] code;
        for(;;) {
            immutable t = token();
            if ( t.type == ScriptType.EOF ) {
                break;
            }
            code~=bson_token(t);
        }
        bson["code"]=code;
        return bson;
    }
    unittest { // parse to bson test
        string source=
            ": test\n"~
            "  * -\n"~
            ";\n"
            ;
        {
            auto preter=new ScriptInterpreter(source, true);
            auto ts=preter.tokens;

            with(ScriptType) {
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
            auto preter=new ScriptInterpreter(source, true);
            auto bson=preter.toBSON;
            auto data=bson.expand;
            auto doc=Document(data);
            // auto keys=doc.keys;
            // writefln("doc.keys=%s", doc.keys);
            auto code=doc["code"].get!Document;
            auto keys=code.keys;
            assert(keys == ["0", "1", "2", "3", "4"]);
            immutable(Token)[] ts;
            foreach(opcode; code) {
                immutable t=doc2token(opcode.get!Document);
                ts~=t;
            }
            ts=Tokens2Tokens(ts);
            with(ScriptType) {
                uint i;
                assert(ts[i].type == FUNC);

//                assert(ts[i].type == WORD);
                assert(ts[i++].token == "test");

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "*");

                assert(ts[i].type == WORD);
                assert(ts[i++].token == "-");

                assert(ts[i++].type == EXIT);
//                assert(ts[i].type == EOF);
            }

        }

    }

private:
    unittest {
        {
            auto src=": test";
            auto preter=new ScriptInterpreter(src, true);
            auto t=[
                preter.token(),
                preter.token(),
                preter.token()
                ];
            with(ScriptType) {
                assert(t[0].type == FUNC);
                assert(t[1].type == WORD);
                assert(t[2].type == EOF);
            }
            assert(t[1].token == "test");
        }
        { // Minus as word
            auto src=": test2\n"~
                "-";
            auto preter=new ScriptInterpreter(src, true);
            immutable(Token)[] tokens;
            with(ScriptType) {
                for(;;) {
                    auto t=preter.token;
                    tokens~=t;
                    if ( (t.type == EOF) || (t.type == ERROR) ) {
                        break;
                    }
                }
                with(ScriptType) {
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
            auto preter=new ScriptInterpreter(src, true);
            immutable(Token)[] tokens;
            with(ScriptType) {
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
            auto preter=new ScriptInterpreter(src, true);
            immutable(Token)[] tokens;
            with(ScriptType) {
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
            auto preter=new ScriptInterpreter(src, true);
            immutable(Token)[] tokens;
            with(ScriptType) {
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
        if ( (result.type == ScriptType.WORD) ) {
            if ( result.token == ":" ) {
                immutable(Token) function_begin= {
                  token : result.token,
                  line : result.line,
                  type : ScriptType.FUNC
                };
                return function_begin;
            }
            else if ( result.token == ";" ) {
                immutable(Token) function_exit= {
                  token : result.token,
                  line : result.line,
                  type : ScriptType.EXIT
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
    static immutable(char) lower(immutable char c) @safe pure nothrow {
        if ( (c >='A') && (c <='Z') ) {
            return cast(immutable char)(c+('a'-'A'));
        }
        else {
            return c;
        }
    }
    static bool is_letter(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return (lower_c >= 'a') && (lower_c <= 'z');
        }
        static bool is_number(immutable char c) @safe pure nothrow {
            return (c >= '0') && (c <= '9');
        }
        static bool is_sign(immutable char c) @safe pure nothrow {
            return ( c == '-' ) || ( c == '+' );
        }
    static bool is_number_or_sign(immutable char c) @safe pure nothrow {
            return is_number(c) || is_sign(c);
        }
        static bool is_number_symbol(immutable char c) @safe pure nothrow {
            return is_number(c) || ( c == '_' );
        }
        static bool is_hex_number(immutable char c) @safe pure nothrow {
            immutable lower_c = lower(c);
            return is_number(c) || ((lower_c >= 'a') && (lower_c <= 'f'));
        }
        static bool is_hex_number_or_sign(immutable char c) @safe pure nothrow {
            return is_hex_number(c) || is_sign(c);
        }
        static bool is_hex_number_symbol(immutable char c) @safe pure nothrow {
            return is_hex_number(c) || ( c == '_' );
        }
        static bool is_hex_prefix(string str) @safe pure nothrow {
            return (str.length > 1) && ((str[0..2]=="0x") || (str[0..2] == "0X"));
        }
        static bool is_white_space(immutable char c) @safe pure nothrow {
            return ( (c == ' ') || ( c == '\t' ) );
        }
        static bool is_word_symbol(immutable char c) @safe pure nothrow {
            return (c >='!') && (c<='~');
        }
        static bool is_newline(string str) pure {
            return ( (str.length > 0) && (str[0] == '\n') ) ||
                ( ( str.length > 1) && ( (str[0..2] == "\n\r") || (str[0..2] == "\r\n") ) );
        }
    immutable(Token) base_token() {
        immutable char getch(immutable uint pos) @safe pure {
            if ( pos < _current_line.length ) {
                return _current_line[pos];
            }
            else {
                return '\0';
            }
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
                if ( is_number_or_sign(getch(start)) && is_hex_number(getch(start+1)) ) {
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
                          type : ScriptType.HEX
                        };
                        return result;
                    }
                    else {
                        // Decimal number
                        while ( is_number_symbol(getch(pos)) ) {
                            pos++;
                        }
                        immutable(Token) result= {
                          token : _current_line[start..pos],
                          line : line,
                          pos :  start,
                          type : ScriptType.NUMBER
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
                          type : ScriptType.TEXT
                        };
                        pos++;
                        return result;

                    }
                    else {
                        immutable(Token) result= {
                          token : "End of text missing"~_current_line[start+1..pos],
                          line  : line,
                          pos   :  start,
                          type  : ScriptType.ERROR
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
                      type : ScriptType.COMMENT
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
                      type : (unexpected_comment_end)?ScriptType.ERROR:ScriptType.WORD
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
                  type : ScriptType.EOF
                };
                return result;
            }
        }
        catch (RangeError e) {
            immutable(Token) result= {
              token : "$ERROR",
              line : line,
              pos :  pos,
              type : ScriptType.ERROR
            };
            return result;
        }
        assert(0);
    }
}

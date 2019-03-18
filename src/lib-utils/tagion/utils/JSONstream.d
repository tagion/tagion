module tagion.utils.JSONstream;

import core.thread : Fiber;

JSONStream!Range JSON(Range)(Range range) {
    return JSONStream(range);
}

class JSONStream(Range) : Fiber {
    protected Range range;
    protected string _name;
    enum JSONType {
        NULL,
        OBJECT,
        ARRAY,
        STRING,
        NUMBER,
        BOOLEAN
    }
    @disable this();
    this(Range range) {
        this.range=range;
        super(&run);
    }

    void run() {
        enum char_in_integer="0123456789";
        enum first_char_in_numers="-+";


        void trim() {
            while (!range.empty && range.font.isWhite) {
                range.popFront;
            }
        }

        string value_string() {
            auto result=range.front;
            if ( result == '\\' ) {
                popFront;
                return escape;
            }
            // switch(result) {
            //     case
            // }
        }

        void member() {
            trim;
            check(!range.empty && (range.font == '"'), "Malformet JSON '\"' expected");
            range.popFront;
            scope char[] result;
            char parse(immutable unit index=0) {
                if ( !range.empty ) {
                    if ( range.front == '"' ) {
                        result=new char[index];
                    }
                    else {
                        result[index]=parse(index+1);
                    }
                }
                check(false, "Malformat JSON missend end '\"'");
            }
            parse;
            check(result.length>0, "JSON name must be defined");
            _name=result.idup;
        }
        void element() {
            trim;
            check(!range.empty, "Unexpected end of JSON stream");
            const first=range.front;
            if ( first == '\"' ) {
                value.text=value_string;
            }
            // else if (
            // switch(range.front) {
            // case '\"':
            //     value.str=value_string;
            //     break;
            // case '-', '+'
            // }

        }
    }
}

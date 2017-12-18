module bakery.script.Script;

//private import tango.core.Exception;

import std.bigint;
import std.internal.math.biguintnoasm : BigDigit;
import std.stdio;
import std.conv;

import bakery.utils.BSON : R_BSON=BSON, Document;

alias R_BSON!true GBSON;

@safe
class ScriptException : Exception {
    this( immutable(char)[] msg ) {
        writefln("msg=%s", msg);
        super( msg );
    }
}

@trusted
class Value {
    enum Type {
        INTEGER,
        FUNCTION,
        TEXT,
        BSON,
        DOCUMENT
    }
    union BInt {
        private BigInt value;
        private const(ScriptElement) opcode;
        private string text;
        private uint   bson_index;
        private Document  doc;

        /* This struct is just read only for the BitInt value */
        immutable struct {
            immutable(BigDigit[]) data;
            immutable bool sign;
        }
        struct {
            private BigDigit[] jam_data;
            private bool jam_sign;

            package void scramble() nothrow {
                BigDigit random() nothrow {
                    scamble_value=(scamble_value * 1103515245) + 12345;
                    return scamble_value;
                }
                foreach(ref jam; jam_data) {
                    jam=random();
                }
                jam_sign= (random() & 0x1) == 0x1 ;
            }
            package void dump()  @trusted {

                writeln("Scramble");
                writeln(jam_data.length);
                writeln(jam_data);
                writeln(jam_sign);
            }
        }
        static BigDigit scamble_value=~0;
    }

    private BInt data;
    private Type _type;
    this(long x, immutable bool bson_type=false) {
        if ( bson_type ) {
            _type=Type.BSON;
            data.bson_index = cast(uint)x;
        }
        else {
            _type=Type.INTEGER;
            data.value = BigInt(x);
        }

    }
    this(const BigInt x) {
        _type=Type.INTEGER;
        data.value = x;
    }
    this(string x) {
        _type=Type.TEXT;
        data.text = x;
    }
    this(const(ScriptElement) s) {
        _type=Type.FUNCTION;
        data.opcode=s;
    }
    this(const Document doc) {
        _type=Type.DOCUMENT;
        data.doc=doc;
    }
    // this(const uint bson_index) {
    //     _type=Type.BSON;
    //     data.bson_index=bson_index;
    // }
    // this(const(Value) v) {
    //     _type=v.type;
    //     with(Type) final switch(v.type) {
    //         case INTEGER:
    //             data.value=BigInt(v.data.value);
    //             break;
    //         case FUNCTION:
    //             data.opcode=v.data.opcode;
    //             break;
    //         case TEXT:
    //             data.text=v.data.text;
    //             break;
    //         }
    // }
    // this(const(Value) v) {
    //     _type=v.type;
    //     with(Type) final switch(v.type) {
    //         case INTEGER:
    //             data.value=v.data.value;
    //             break;
    //         case FUNCTION:
    //             data.opcode=v.data.opcode;
    //             break;
    //         case TEXT:
    //             data.text=v.data.text;
    //             break;
    //         }
    // }

    static Value opCall(T)(T x) {
        static if ( is(T:const(Value)) || is(T:const(Value)*) ) {
            with(Type) final switch(x.type) {
                case INTEGER:
                    return new Value(x.value);
                case FUNCTION:
                    return new Value(x.text);
                case TEXT:
                    return new Value(x.opcode);
                case BSON:
                    return new Value(x.bson_index);
                case DOCUMENT:
                    return new Value(x.doc);
                }
        }
        else {
            return new Value(x);
        }
    }
    Type type() pure const nothrow {
        return _type;
    }
    const(BigInt) value() const {
        if ( type == Type.INTEGER) {
            return data.value;
        }
        throw new ScriptException(to!string(Type.INTEGER)~" expected not "~to!string(type));
    }
    string text() const {
        if ( type == Type.TEXT) {
            return data.text;
        }
        throw new ScriptException(to!string(Type.TEXT)~" expected not "~to!string(type));
    }
    const(ScriptElement) opcode() const {
        if ( type == Type.FUNCTION) {
            return data.opcode;
        }
        throw new ScriptException(to!string(Type.FUNCTION)~" expected not "~to!string(type));
    }
    const(Document) doc() const {
        if ( type == Type.DOCUMENT ) {
            return data.doc;
        }
        throw new ScriptException(to!string(Type.DOCUMENT)~" expected not "~to!string(type));
    }
    uint bson_index() const {
        if ( type == Type.BSON ) {
            return data.bson_index;
        }
        throw new ScriptException(to!string(Type.BSON)~" expected not "~to!string(type));
    }
    immutable(ubyte[]) buffer() const {
        if ( type == Type.INTEGER) {
            return (cast(ubyte[])data.data).idup;
        }
        throw new ScriptException(to!string(Type.INTEGER)~" expected not "~to!string(type));
    }
    T get(T)() const {

        static if ( is(T==const(BigInt)) ) {
            return value;
        }
        else static if ( is(T==string) ) {
            return text;
        }
        else static if ( is(T==const(ScriptElement)) ) {
            return opcode;
        }
        else {
            static assert(0, "Type "~T.stringof~" not supported");
        }
    }

    ~this() {
        // The value is scrambled to reduce the properbility of side channel attack
        // writefln("Scramble before %s", data.value);
        // data.scramble;
        // writefln("Scramble after %s", data.value);
    }
}

unittest {
    // Numbers
    auto a=const(Value)(10);
    assert(a.type == Value.Type.INTEGER);
    assert(a.value == 10);

    enum num="1234567890_1234567890_1234567890_1234567890";
    auto b=Value(BigInt(num));
    assert(b.type == Value.Type.INTEGER);
    assert(b.value == BigInt(num));


}

@safe
class ScriptContext {
    public bool trace;
    private string indent;
    private const(Value)[] data_stack;
    private const(Value)[] return_stack;
    package Value[] variables;
    package Value[][] locals_stack;
//    private uint data_stack_index;
//    private uint return_stack_index;
    private immutable uint data_stack_size;
    private immutable uint return_stack_size;
    private uint iteration_count;
    private int data_stack_index;
    private int return_stack_index;
    private GBSON[] bsons;
    private uint bsons_count;
    this(const uint data_stack_size,
        const uint return_stack_size,
        const uint var_size,
        const uint iteration_count,
        const uint bsons_size=1) {
        this.data_stack_size=data_stack_size;
        this.return_stack_size=return_stack_size;
        this.variables=new Value[var_size];
        this.iteration_count=iteration_count;
        foreach(ref v; variables) {
            v=Value(0);
        }
        if ( bsons_size != 0 ) {
            this.bsons=new GBSON[bsons_size];
        }
    }
    const(Value) opIndex(uint i) {
        return variables[i];
    }
    ref GBSON bson(uint i) {
        if ( i < bsons.length ) {
            if ( bsons[i] is null ) {
                return bsons[i];
            }
        }
        throw new ScriptException("BSON index out of range");
    }
    @trusted
    const(Value) data_pop() {
        scope(exit) {
            if ( data_stack.length > 0 ) {
                data_stack.length--;
            }
        }
        if ( data_stack.length == 0 ) {
            throw new ScriptException("Data stack empty");
        }
        return data_stack[$-1];
    }
    void data_push(T)(T v, immutable bool bson_type=false) {
        if ( data_stack.length < data_stack_size ) {
            static if ( is(T:const Value) ) {
                data_stack~=v;
            }
            else {
                static if ( is(v : const(long)) ) {
                    data_stack~=const(Value)(v, bson_type);
                }
                else {
                    data_stack~=const(Value)(v);
                }
            }
        }
        else {
            throw new ScriptException("Data stack overflow");
        }
    }
    const(Value) data_peek(immutable uint i=0) const {
        if ( data_stack.length <= i ) {
            throw new ScriptException("Data stack empty");
        }
        return data_stack[$-1-i];
    }
    @safe
    void return_push(T)(T v) {
        if ( return_stack.length < return_stack_size ) {
            static if ( is(T:const Value) ) {
                return_stack~=v;
            }
            else {
                return_stack~=const(Value)(v);
            }
        }
        else {
            throw new ScriptException("Return stack overflow");
        }
    }
    @trusted
    const(Value) return_pop() {
        scope(exit) {
            if ( return_stack.length > 0 ) {
                return_stack.length--;
            }
        }
        if ( return_stack.length == 0 ) {
            throw new ScriptException("Return stack empty");
        }
        return return_stack[$-1];
    }
    const(Value) return_peek(immutable uint i=0) const {
        if ( return_stack.length <= i ) {
            throw new ScriptException("Data stack empty");
        }
        return return_stack[$-1-i];
    }
    void check_jump() {
        if ( iteration_count == 0 ) {
            throw new ScriptException("Iteration limit");
        }
        iteration_count--;
    }
    void push_locals(Value[] locals) {
        locals_stack~=locals;
    }
    Value[] pop_locals() {
        scope(exit) {
            if ( locals_stack.length > 0 ) {
                locals_stack.length--;
            }
        }
        if ( locals_stack.length == 0 ) {
            throw new ScriptException("Local stack empty");
        }
        return locals_stack[$-1];
    }
    Value[] locals() {
        if ( locals_stack.length == 0 ) {
            throw new ScriptException("Local stack empty");
        }
        return locals_stack[$-1];
    }
//    @trusted
    unittest {
        auto sc=new ScriptContext(8, 8, 8, 8);
        enum num="1234567890_1234567890_1234567890_1234567890";
        // Data stack test
        sc.data_push(BigInt(num));
        auto pop_a=sc.data_pop.value;
        assert(pop_a == BigInt(num));
    }
}


@safe
interface ScriptBasic {
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const
    in {
        assert(s !is null);
        assert(sc !is null);
    }
    const(ScriptElement) next(ScriptElement n)
    in {
        assert(next is null, "Next script element is should not be change");
    }
    inout(ScriptElement) next() inout pure nothrow;
    string toText() const;
}

@safe
abstract class ScriptElement : ScriptBasic {
    private ScriptElement _next;
    private uint line, pos;
    private uint n; // Token index
    private string token;
    immutable uint runlevel;
    this(immutable uint runlevel) {
        this.runlevel=runlevel;
    }
    // const(ScriptElement) opCall(const Script s, ScriptContext sc) const
    // in {
    //     assert(sc !is null);
    // }
    // body {
    //     return _next;
    // }
    const(ScriptElement) next(ScriptElement n)
    in {
        assert(_next is null, "Next script element is should not be change");
    }
    body {
        _next = n;
        return _next;
    }
    inout(ScriptElement) next() inout pure nothrow {
        return _next;
    }

    package void set_location(const uint n, string token, const uint line, const uint pos) {
        assert(this.token.length == 0);
        this.token = token;
        this.line = line;
        this.pos = pos;
        this.n=n;
    }
    void check(const Script s, const ScriptContext sc) const
        in {
            assert( sc !is null);
            assert( s !is null);
        }
    body {

        if ( runlevel > s.runlevel ) {
            throw new ScriptException("Opcode not allowed in this runlevel");
        }
    }

    string toInfo() pure const nothrow {
        import std.conv;
        string result;
        result=token~" "~to!string(line)~":"~to!string(pos);
        return result;
    }

    uint index() const {
        return n;
    }

}

@safe
class ScriptError : ScriptElement {
    private const(ScriptElement) problem_element;
    private string error;
    this(string error, const(ScriptElement) problem_element) {
        this.error=error;
        this.problem_element=problem_element;
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const  {
        import std.stdio;
        writefln("Aborted: %s", error);
        writeln(problem_element.toInfo);
        return null;
    }
    string toText() const {
        return "error:"~error;
    }
}

@safe
class ScriptJump : ScriptElement {
    private bool turing_complete;
    private ScriptElement _jump;
    this() {
        super(0);
    }
    void set_jump(ScriptElement target)
    in {
        assert(target !is null);
        assert(_jump is null, "Jump target should not be changed");
    }
    out {
        assert(this._jump !is null);
    }
    body {
        this._jump=target;
    }
    const(ScriptElement) jump() pure nothrow const {
        return _jump;
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if ( turing_complete ) {
            if ( !s.is_turing_complete) {
                throw new ScriptException("Illegal command in Turing complete mode");
            }
        }
        sc.check_jump();
        return _jump; // Points to the jump position
    }
    string toText() const {
        auto target=(_jump is null)?"null":to!string(_jump.n);
        return "goto "~target;
    }
    // override const(ScriptElement) next(ScriptElement n) {
    //     // Ignore
    //     writefln("JUMP set %s %s",n is null, _next is null);
    //     return _next;
    // }

}

@safe
class ScriptConditionalJump : ScriptJump {
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const  {
        check(s, sc);
        sc.check_jump();

        if ( sc.data_pop.value != 0 ) {
            return _next;
        }
        else {
            return _jump;
        }
    }
    override string toText() const {
        auto target_false=(_jump is null)?"null":to!string(_jump.n);
        auto target_true=(_next is null)?"null":to!string(_next.n);
        return "if.false goto "~target_false;
    }

}


@safe
class ScriptNotConditionalJump : ScriptConditionalJump {
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const  {
        check(s, sc);
        sc.check_jump();

        if ( sc.data_pop.value == 0 ) {
            return _next;
        }
        else {
            return _jump;
        }
    }
    override string toText() const {
        auto target_false=(_jump is null)?"null":to!string(_jump.n);
        auto target_true=(_next is null)?"null":to!string(_next.n);
        return "if.true goto "~target_false;
    }
}

@safe
class ScriptExit : ScriptElement {
    this() {
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if (sc.trace) {
            if ( sc.indent.length > 0) {
                sc.indent.length--;
            }
        }
        auto ret=sc.return_pop;
        if ( ret.type == Value.Type.FUNCTION ) {
            sc.pop_locals;
            return ret.get!(const(ScriptElement));
        }
        else {
            return new ScriptError("Return stack type fail, return address expected bot "~to!string(ret.type),this);
        }

    }
    string toText() const {
        return "exit";
    }

}

@safe
class ScriptCall : ScriptJump {
    private string func_name;
    // Number of local variables
    private uint loc_size;
    this(string func_name) {
        this.func_name=func_name;
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s,sc);
        sc.return_push(_next);
        if (sc.trace) {
            sc.indent~=" ";
        }
        writefln("Call %s loc_size=%s", func_name, loc_size);
        auto locals=new Value[loc_size];
        foreach(ref v; locals) {
            v=Value(0);
        }
        sc.push_locals(locals);
        return _jump;
    }
    override void set_jump(ScriptElement target) {
        assert(0, "Use set_call instead of set_jump");
    }
    void set_call(ScriptElement target, immutable uint locals=0)
        in {
            assert(loc_size == 0);
        }
    body {
        super.set_jump(target);
        writefln("set_call %s locals=%s", func_name, locals);
        loc_size = locals;
    }
    override string toText() const {
        return "call "~func_name;
    }
    string name() const {
        return func_name;
    }
}



@safe
class ScriptNumber : ScriptElement {
    private BigInt x;
    this(string number) {
        this.x=BigInt(number);
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(x);
        return _next;
    }
    @trusted
    string toText() const {
        import std.format : format;

        if ( x.ulongLength == 1 ) {
            return format("%d", x);
        }
        else {
            return format("0x%x", x);
        }
    }

}

@safe
class ScriptText : ScriptElement {
    private string text;
    this(string text) {
        this.text=text;
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(text);
        return _next;
    }
    string toText() const {
        return '"'~text~'"';
    }
}

@safe
class ScriptGetVar : ScriptElement {
    private immutable uint var_index;
    private immutable(char[]) var_name;
    this(string var_name, uint var_index) {
        this.var_name = var_name;
        this.var_index = var_index;
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(sc.variables[var_index]);
        return _next;
    }
    string toText() const {
        return var_name~" @";
    }

}


@safe
class ScriptPutVar : ScriptElement {
    immutable uint var_index;
    private string var_name;
    this(string var_name, uint var_index) {
        this.var_name = var_name;
        this.var_index = var_index;
        super(0);
    }
    @trusted
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto var=sc.data_pop();
        sc.variables[var_index]=Value(var);
        return _next;
    }
    string toText() const {
        return var_name~" !";
    }

}

@safe
class ScriptGetLoc : ScriptElement {
    private immutable uint loc_index;
    private immutable(char[]) loc_name;
    this(string loc_name, uint loc_index) {
        this.loc_name = loc_name;
        this.loc_index = loc_index;
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(sc.locals[loc_index]);
        return _next;
    }
    string toText() const {
        return loc_name~" @";
    }

}

@safe
class ScriptPutLoc : ScriptElement {
    immutable uint loc_index;
    private string loc_name;
    this(string loc_name, uint loc_index) {
        this.loc_name = loc_name;
        this.loc_index = loc_index;
        super(0);
    }
    @trusted
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto var=sc.data_pop();
        sc.locals[loc_index]=Value(var);
        return _next;
    }
    string toText() const {
        return loc_name~" !";
    }

}

@safe
class ScriptGetBSON : ScriptElement {
    private immutable uint bson_index;
    private immutable(char[]) bson_name;
    this(string bson_name, uint bson_index) {
        this.bson_name = bson_name;
        this.bson_index = bson_index;
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(bson_index, true);
        return _next;
    }
    string toText() const {
        return bson_name~" @";
    }

}

@safe
class ScriptPutBSON : ScriptElement {
    immutable uint bson_index;
    private string bson_name;
    this(string bson_name, uint bson_index) {
        this.bson_name = bson_name;
        this.bson_index = bson_index;
        super(0);
    }
    @trusted
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto a=sc.data_pop();
        if ( a.type == Value.Type.BSON ) {
            sc.bsons[bson_index]=sc.bsons[a.bson_index];
            return _next;
        }
        else {
            return new ScriptError("Type "~to!string(Value.Type.BSON)~" expect and not "~to!string(a.type), this);
        }
    }
    string toText() const {
        return bson_name~" !";
    }

}

/* Arhitmentic opcodes */

@safe
class ScriptUnitaryOp(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    @trusted
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        static if ( op == "1-" ) {
            sc.data_push(sc.data_pop.value - 1);
        }
        else static if ( op == "1+" ) {
            sc.data_push(sc.data_pop.value + 1);
        }
        else static if ( op == "r@1+" ) {
            // r@ 1 + dup >r
            auto r=sc.return_pop.value+1;
            sc.data_push(r);
            sc.return_push(r);
        }
        else {
            static assert(0, "Unitary operator "~op.stringof~" not defined");
        }

        return _next;
    }
    string toText() const {
        return op;
    }
}



@safe
class ScriptBinaryOp(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    @trusted
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        scope BigInt a, b;
        try {
            a=sc.data_pop.value;
            b=sc.data_pop.value;
        }
        catch ( Exception e ) {
            return new ScriptError("Type or operator problem", this);
        }
        static if ( (op == "/") || (op == "%" ) ) {
            if ( a == 0 ) {
                return new ScriptError("Division by zero", this);
            }
        }
        static if ( op == "<<" ) {
            if ( a < 0 ) {
                return new ScriptError("Left shift divisor must be positive", this);
            }
            if ( a == 0 ) {
                sc.data_push(b);
            }
            else {
                auto _a=cast(int)a;
                if ( a > s.max_shift_left ) {
                    return new ScriptError("Left shift overflow", this);
                }
                auto y=b << _a;
                sc.data_push(y);
            }
        }
        else static if ( op == ">>" ) {
            if ( a < 0 ) {
                return new ScriptError("Left shift divisor must be positive", this);
            }
            if ( a == 0 ) {
                sc.data_push(b);
            }
            else {
                auto _a=cast(uint)a;
                auto y=b >> _a;
                sc.data_push(y);
            }
        }
        else {

            mixin("sc.data_push(b" ~ op ~ "a);");
        }
        return _next;
    }
    string toText() const {
        return op;
    }
}

@safe
class ScriptCompareOp(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    @trusted
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        bool result;
        auto b=sc.data_pop.value;
        auto a=sc.data_pop.value;
        mixin("result = a" ~ op ~ "b;");
        auto x=BigInt((result)?-1:0);
        sc.data_push(x);
        return _next;
    }
    string toText() const {
        return op;
    }
}

@safe
class ScriptStackOp(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        static if ( op ==  "dup" ) { // a -- a a
            sc.data_push(sc.data_peek);
        }
        else static if ( op == "swap" ) { // ( a b -- b a )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            sc.data_push(b);
            sc.data_push(a);
        }
        else static if ( op == "drop" ) {  // ( a -- )
            sc.data_pop;
        }
        else static if ( op == "over" ) { // ( a b -- a b a )
            sc.data_push(sc.data_peek(1));
        }
        else static if ( op == "rot" ) { // ( a b c -- b c a )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            auto c=sc.data_pop;
            sc.data_push(a);
            sc.data_push(c);
            sc.data_push(b);
        }
        else static if ( op == "-rot" ) { // ( a b c -- c a b )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            auto c=sc.data_pop;
            sc.data_push(b);
            sc.data_push(a);
            sc.data_push(c);
        }
        else static if ( op == "nip" ) { // ( a b -- b )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            sc.data_push(b);
        }
        else static if ( op == "tuck" ) { // ( a b -- b a b )
            auto v=sc.data_peek(1);
            sc.data_push(v.value);
        }
        else static if ( op == "2dup" ) { // ( a b -- a b a b )
            auto va=sc.data_peek(0);
            auto vb=sc.data_peek(1);
            sc.data_push(vb.value);
            sc.data_push(va.value);
        }
        else static if ( op == "2swap" ) { // ( a b c d -- c b a b )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            auto c=sc.data_pop;
            auto d=sc.data_pop;
            sc.data_push(b);
            sc.data_push(a);
            sc.data_push(d);
            sc.data_push(c);
        }
        else static if ( op == "2drop" ) { // ( a b -- )
            sc.data_pop;
            sc.data_pop;
        }
        else static if ( op == "2over" ) { // ( a b c d -- a b c d a b )
            auto va=sc.data_peek(2);
            auto vb=sc.data_peek(3);
            sc.data_push(va.value);
            sc.data_push(vb.value);
        }
        else static if ( op == "2nip" ) { // ( a b c d -- a b )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            auto c=sc.data_pop;
            auto d=sc.data_pop;
            sc.data_push(b);
            sc.data_push(a);
        }
        else static if ( op == "2tuck" ) {  // ( a b c d -- a b c d a b )
            auto a=sc.data_pop;
            auto b=sc.data_pop;
            auto c=sc.data_pop;
            auto d=sc.data_pop;
            sc.data_push(b);
            sc.data_push(a);
            sc.data_push(d);
            sc.data_push(c);
            sc.data_push(b);
            sc.data_push(a);
        }
        else static if ( op == ">r" ) {
            sc.return_push(sc.data_pop);
        }
        else static if ( op == "r>" ) {
            sc.data_push(sc.return_pop);
        }
        else static if ( op == "r@" ) {
            sc.data_push(sc.return_peek(0));
        }
        else {
            static assert(0, "Stack operator "~op.stringof~" not defined");
        }
        return _next;
    }
    string toText() const {
        return op;
    }
}

@safe
class Script {
    private import bakery.script.ScriptInterpreter : ScriptInterpreter;
    alias ScriptInterpreter.ScriptType ScriptType;
    alias ScriptInterpreter.Token Token;

    private bool trace;
    struct Function {
        string name;
        immutable(Token)[] tokens;
        private uint local_count;
        private uint[string] local_indices;
       //  private uint[uint] label_jump_table;
        ScriptElement opcode;
        bool compiled;
        string toInfo() pure const nothrow {
            string result;
            void foreach_loop(const ScriptElement s, const uint i) {
                if ( s !is null) {
                    result~=to!string(i)~"] ";
                    result~=s.toInfo;
                    result~="\n";
                    foreach_loop(s, i+1);
                }
            }
            return result;
        }
        uint allocate_loc(string loc_name) {
            writef("allocate_loc=%s", loc_name);
            if ( loc_name !in local_indices ) {
                local_indices[loc_name]=local_count;
                local_count++;
            }
            writefln(" loc_count=%s in function %s", local_count, name);
            return local_indices[loc_name];
        }
        bool is_loc(string loc_name) pure const nothrow {
            return (loc_name in local_indices) !is null;
        }
        // Number of local variables in the function
        uint local_size() pure const nothrow {
            return local_count;
        }
        uint get_loc(string loc_name) const {
            return local_indices[loc_name];
        }
        uint auto_get_loc(string loc_name) {
            if ( !is_loc(name) ) {
                allocate_loc(loc_name);
            }
            return get_loc(loc_name);
        }

        string toText() {
            string result;
            foreach(i,t; tokens) {
                result~=to!string(i)~")";
                result~=t.toText;
                result~="\n";
            }
            return result;
        }
    }
    package Function[string] functions;

    // private ScriptElement root, last;
    private uint runlevel;
    // private ScriptContext sc;
    enum max_shift_left=(1<<12)+(1<<7);

    void run(string func, ScriptContext sc) {
        void doit(const(ScriptElement) current) {
            if ( current !is null ) {
                try {
                    if ( sc.trace ) {
                        writefln("%s%s] %s", sc.indent, current.n, current.toText);
                    }
                    doit(current(this, sc));
                }
                catch (ScriptException e) {
                    auto error=new ScriptError(e.msg, current);
                }
            }
        }
        this.trace=trace;
        foreach(n, f; functions) {
            writefln("### FUNC %s %s", n, f.local_size);
        }
        if ( func in functions) {
            auto f=functions[func]; //.opcode;
            writefln("call %s local_size=%s %s", func, f.local_size, f.opcode !is null);
            auto start=new ScriptCall("$"~func);
            start.set_call(f.opcode, f.local_size);
            doit(start);
        }
    }
    bool is_turing_complete() pure nothrow const {
        return (runlevel > 1);
    }
    const(Function)* opIndex(string name) const {
        return name in functions;
    }
}

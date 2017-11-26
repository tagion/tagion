module bakery.script.Script;

//private import tango.core.Exception;

import std.bigint;
import std.internal.math.biguintnoasm : BigDigit;
import std.stdio;
import std.conv;

@safe
class ScriptException : Exception {
    this( immutable(char)[] msg ) {
        super( msg );
    }
}

@safe
struct Value {
    enum Type {
        INTEGER,
        FUNCTION,
        TEXT,
    }
    union BInt {
        private BigInt value;
        private const(ScriptElement) opcode;
        private string text;
        /* This struct is just read only for the BitInt value */
        immutable struct {
            immutable(BigDigit[]) data;
            immutable bool sign;
        }
        struct {
            private BigDigit[] jam_data;
            private bool jam_sign;

            package void scramble()  @trusted nothrow {
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
    @trusted
    this(ref const BigInt x) {
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
    Type type() pure const nothrow {
        return _type;
    }
    @trusted
    const(BigInt) value() const {
        if ( type == Type.INTEGER) {
            return data.value;
        }
        throw new ScriptException(to!string(Type.INTEGER)~" expected not "~to!string(type));
    }
    @trusted
    string text() const {
        if ( type == Type.TEXT) {
            return data.text;
        }
        throw new ScriptException(to!string(Type.TEXT)~" expected not "~to!string(type));
    }
    @trusted
    const(ScriptElement) func() const {
        if ( type == Type.FUNCTION) {
            return data.opcode;
        }
        throw new ScriptException(to!string(Type.FUNCTION)~" expected not "~to!string(type));
    }
    T get(T)() const {

        static if ( is(T==const(BigInt)) ) {
            return value;
        }
        else static if ( is(T==string) ) {
            return text;
        }
        else static if ( is(T==const(ScriptElement)) ) {
            return func;
        }
        else {
            static assert(0, "Type "~T.stringof~" not supported");
        }
    }
    ~this() {
        // The value is scrambled to reduce the properbility of side channel attack
        data.scramble;
    }
}

@safe
class ScriptContext {
    private const(Value)[] data_stack;
    private const(Value)[] return_stack;
    package const(Value)* var[];

//    private uint data_stack_index;
//    private uint return_stack_index;
    private immutable uint data_stack_size;
    private immutable uint return_stack_size;
    private uint iteration_count;
    this(const uint data_stack_size, const uint return_stack_size, immutable uint var_size,  ) {
        this.data_stack_size=data_stack_size;
        this.return_stack_size=return_stack_size;
        this.var=new const(Value)*[var_size];

//        data_stack=new const(Value)[data_stack_size];
//        return_stack=new const(ScriptElement)[return_stack_size];
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
    const(BigInt) data_pop_number() {
        return data_pop.get!(const(BigInt));
    }
    void data_push(T)(T v) {
        if ( data_stack.length < data_stack_size ) {
            static if ( is(T:const Value) ) {
                data_stack~=v;
            }
            else {
                data_stack~=const(Value)(v);
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
    // const(Value) return_pop() {
    //     scope(exit) {
    //         if ( return_stack.length > 0 ) {
    //             return_stack.length--;
    //         }
    //     }
    //     if ( return_stack.length == 0 ) {
    //         throw new ScriptException("Return stack empty");
    //     }
    //     return return_stack[$-1];
    // }
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
            throw new ScriptException("Data stack overflow");
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
            throw new ScriptException("Data stack empty");
        }
        return return_stack[$-1];
    }
    const(BigInt) return_pop_number() {
        return return_pop.get!(const(BigInt));
    }
    const(ScriptElement) return_pop_element() {
        return return_pop.get!(const(ScriptElement));
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
}


@safe
abstract class ScriptElement {
    private ScriptElement _next;
    private uint line, pos;
    private string token;
    immutable uint runlevel;
    this(immutable uint runlevel) {
        this.runlevel=runlevel;
    }
    const(ScriptElement) opCall(const Script s, ScriptContext sc) const
    in {
        assert(sc !is null);
    }
    body {
        return _next;
    }
    package const(ScriptElement) next(ScriptElement n)
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

    void set_location(string token, uint line, uint pos) {
        assert(this.token.length == 0);
        this.token = token;
        this.line = line;
        this.pos = pos;
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
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const  {
        import std.stdio;
        writefln("Aborted: %s", error);
        writeln(problem_element.toInfo);
        return null;
    }
}

@safe
class ScriptJump : ScriptElement {
    private bool turing_complete;
    this() {
        super(0);
    }
    void set_jump(ScriptElement target)
    in {
        assert(_next is null, "Jump target is should not be change");
    }
    body {
        _next=target;
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if ( turing_complete ) {
            if ( !s.is_turing_complete) {
                throw new ScriptException("Illigal command in Turing complete mode");
            }
        }
        sc.check_jump();
        return _next; // Points to the jump position
    }
}

@safe
class ScriptConditionalJump : ScriptJump {
    private ScriptElement _jump;
    override void set_jump(ScriptElement target)
        in {
            assert(_jump is null, "Jump target is should not be change");
        }
    body {
        _jump=target;
    }
    const(ScriptElement) jump() pure nothrow const {
        return _jump;
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const  {
        check(s, sc);
        if ( sc.data_pop_number != 0 ) {
            return _next;
        }
        else {
            return _jump;
        }
    }
}


@safe
class ScriptExit : ScriptElement {
    this() {
        super(0);
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto ret=sc.return_pop;
        if ( ret.type == Value.Type.FUNCTION ) {
            return ret.get!(const(ScriptElement));
        }
        else {
            return new ScriptError("Return stack type fail, return address expected bot "~to!string(ret.type),this);
        }

    }
}

@safe
class ScriptCall : ScriptJump {
    private ScriptElement _call;
    private string func_name;
    this(string func_name) {
        this.func_name=func_name;
    }
    override void set_jump(ScriptElement target)
        in {
            assert(_call is null, "Jump target is should not be change");
        }
    body {
        _call=target;
    }
    // package const(ScriptElement) call(ScriptElement n) {
    //     _call = n;
    //     return _call;
    // }
    const(ScriptElement) call() pure nothrow const {
        return _call;
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s,sc);
        sc.return_push(next);
        return _call;
    }
    string name() const pure nothrow {
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
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(x);
        return _next;
    }
}

@safe
class ScriptText : ScriptElement {
    private string text;
    this(string text) {
        this.text=text;
        super(0);
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(text);
        return _next;
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
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(*(sc.var[var_index]));
        return _next;
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
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto var=sc.data_pop();
        sc.var[var_index]=&var;
        return _next;
    }

}
/* Arhitmentic opcodes */

@safe
class ScriptInc : ScriptElement {
    this(ScriptElement next) {
        super(0);
        this._next = next;
    }
    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(sc.data_pop_number + 1);
        return _next;
    }
}

@safe
class ScriptDec : ScriptElement {
    this(ScriptElement next) {
        super(0);
        this._next = next;
    }
    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.data_push(sc.data_pop_number - 1);
        return _next;
    }
}



@safe
class ScriptBinary(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        scope BigInt a, b;
        try {
            a=sc.data_pop_number;
            b=sc.data_pop_number;
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
}

@safe
class ScriptCompare(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        bool result;
        mixin("result = sc.data_pop_number" ~ op ~ "sc.data_pop_number;");
        auto x=BigInt((result)?-1:0);
        sc.data_push(x);
        return _next;
    }
}

@safe
class ScriptStackOp(string O) : ScriptElement {
    enum op=O;
    this() {
        super(0);
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
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
        else {
            static assert(0, "Stack operator "~op.stringof~" not defined");
        }
        return _next;
    }
}

@safe
class Script {
    private ScriptElement root, last;
    immutable uint runlevel;
    private ScriptContext sc;
    enum max_shift_left=(1<<12)+(1<<7);
    this(ScriptContext sc, immutable uint runlevel=0, ScriptElement root=null) {
        this.runlevel=runlevel;
        this.sc=sc;
        this.root=root;
    }
    void run() {
        void doit(const(ScriptElement) current) {
            if ( current !is null ) {
                try {
                    doit(current(this, sc));
                }
                catch (ScriptException e) {
                    auto error=new ScriptError(e.msg, current);
                }
            }
        }
        doit(root);
    }
    void append(ScriptElement e) {
        if ( root is null ) {
            root = last = e;
        }
        else {
            last.next = e;
            last = e;
        }
    }
    bool is_turing_complete() pure nothrow const {
        return (runlevel > 1);
    }
}

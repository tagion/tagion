module bakery.script.Script;

//private import tango.core.Exception;

import std.bigint;
import std.internal.math.biguintnoasm : BigDigit;
import std.stdio;

@safe
class ScriptException : Exception {
    this( immutable(char)[] msg ) {
        super( msg );
    }
}

@safe
struct Value {

    union BInt {
        BigInt value;
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
    this(ref const BigInt x) {
        data.value = x;
    }
    // bool isTrue() @trusted pure nothrow const {
    //     return data.value != 0;
    // }
    ~this() {
        // The value is scrambled to reduce the properbility of side channel attack
        data.scramble;
    }
}

@safe
class ScriptContext {
    private const(Value)[] data_stack;
    private const(ScriptElement)[] return_stack;
//    private uint data_stack_index;
//    private uint return_stack_index;
    private immutable uint data_stack_size;
    private immutable uint return_stack_size;
    private uint iteration_count;
    this(const uint data_stack_size, const uint return_stack_size ) {
        this.data_stack_size=data_stack_size;
        this.return_stack_size=return_stack_size;
//        data_stack=new const(Value)[data_stack_size];
//        return_stack=new const(ScriptElement)[return_stack_size];
    }
    @trusted
    const(BigInt) data_pop() {
        scope(exit) {
            if ( data_stack.length > 0 ) {
                data_stack.length--;
            }
        }
        if ( data_stack.length == 0 ) {
            throw new ScriptException("Data stack empty");
        }
        return data_stack[$-1].data.value;
    }
    @safe
    void data_push(ref const BigInt v) {
        if ( data_stack.length < data_stack_size ) {
            data_stack~=const(Value)(v);
        }
        else {
            throw new ScriptException("Data stack overflow");
        }
    }
    void data_push(const BigInt v) {
        if ( data_stack.length < data_stack_size ) {
            data_stack~=const(Value)(v);
        }
        else {
            throw new ScriptException("Data stack overflow");
        }
    }
    const(ScriptElement) return_pop() {
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
    void return_push(const ScriptElement v) {
        if ( return_stack.length < return_stack_size ) {
            return_stack~=v;
        }
        else {
            throw new ScriptException("Return stack overflow");
        }
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
    private bool touched; // Set to true if the function has been executed
    immutable uint runlevel;
    this(immutable uint runlevel) {
        this.runlevel=runlevel;
    }
    ScriptElement opCall(const Script s, ScriptContext sc)
        in {
            assert(sc !is null);
        }
    body {
        return _next;
    }
    package const(ScriptElement) next(ScriptElement n) {
        _next = n;
        return _next;
    }
    const(ScriptElement) next() pure nothrow const {
        return _next;
    }
    void check(const Script s, const ScriptContext sc)
        in {
            assert( sc !is null);
            assert( s !is null);
        }
    body {

        if ( runlevel > s.runlevel ) {
            throw new ScriptException("Opcode not allowed in this runlevel");
        }
        else if ( s.runlevel < 2 ) {
            if ( touched ) {
                throw new ScriptException("Opcode has already been executed (loop not allowed in this runlevel)");
            }
        }
        touched = true;
    }
}

@safe
class ScriptConditional : ScriptElement {
    private ScriptElement _jump;
    this(ScriptElement next, ScriptElement jump) {
        super(0);
        this._next=next;
        this._jump=jump;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc)  {
        check(s, sc);
        if ( sc.data_pop != 0 ) {
            return _next;
        }
        else {
            return _jump;
        }
    }
}

@safe
class ScriptJump : ScriptElement {
    private bool turing_complete;
    this(ScriptElement next) {
        super(2);
        this._next=next;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc) {
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
class ScriptCall : ScriptElement {
    private ScriptElement call;
    this(ScriptElement next, ScriptElement call, immutable uint runlevel=2)
    in {
        assert( runlevel>=2 );
    }
    body {
        super(runlevel);
        this.next=next;
        this.call=call;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(s,sc);
        sc.return_push(next);
        return call;
    }
}


/*
class ScriptAdd : ScriptElement {

    override ScriptElement opCall(const ScriptContext sc) {

    }
}

*/

class PushLiteral(T) : ScriptElement {
    private BitInt x;
    this(const ScriptElement next, T x) {
        this.x = x;
        this._next = next;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(s, sc);
        sc.data_push(x);
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
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(s, sc);
        sc.data_push(sc.data_pop + 1);
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
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(s, sc);
        sc.data_push(sc.data_pop - 1);
        return _next;
    }
}


@safe
class ScriptBinary(alias op) : ScriptElement {
    this(ScriptElement next) {
        super(0);
        this._next = next;
    }
    @trusted
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(s, sc);
        mixin("sc.data_push(sc.data_pop" ~ op ~ "sc.data_pop);");
        return _next;
    }
}

@safe
class Script {
    private ScriptElement root, last;
    immutable uint runlevel;
    private ScriptContext sc;
    this(ScriptContext sc, immutable uint runlevel=0, ScriptElement root=null) {
        this.runlevel=runlevel;
        this.sc=sc;
        this.root=root;
    }
    void run() {
        for(ScriptElement current=root; current !is null; current=current(this, sc) ) {
            /* empty */
        }
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

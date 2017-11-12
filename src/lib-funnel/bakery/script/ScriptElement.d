
module bakery.script.ScriptElement;

alias long BitInt;

@safe
class Value {
    immutable(BitInt) data;
    this(immutable(BitInt) x) {
        data = x;
    }
    bool isTrue() pure nothrow const {
        return data != 0;
    }
}

@safe
class ScriptContext {
    private const(Value)[] data_stack;
    private const(ScriptElement)[] return_stack;
    private uint data_stack_index;
    private uint return_stack_index;
    private uint iteration_count;
    this(const uint data_stack_size, const uint return_data_size ) {
        data_stack=new Value[data_stack_size];
        return_stack=new Value[return_stack_size];
    }
    void data_push(const(Value) v) {
        if ( data_stack_index < data_stack.length) {
            data_stack[data_stack_index++]=v;
        }
        else {
            throw new ScriptException("Stack overflow");
        }
    }
    const(Value) data_pop() {
        if ( data_stack_index > 0 ) {
            data_stack_index--;
        }
        else {
            throw new ScriptException("Stack empty");
        }
        return data_stack[data_stack_index];

    }
    const(ScriptElement) return_pop() {
        if ( return_stack_index > 0 ) {
            return_stack_index--;
        }
        else {
            throw new ScriptException("Return stack empty");
        }
        return return_stack[return_stack_index];

    }
    void return_push(const(ScriptElement) v) {
        if ( data_stack_index < data_stack.length) {
            data_stack[stack_index++]=v;
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
    ScriptElement opCall(const Script s, ScriptContext sc)
        in {
            assert(sc !is null);
        }
    body {
        return next;
    }
    package void next(ScriptElement n) {
        _next = n;
        return _next;
    }
    const ScriptElement next() {
        return _next;
    }
    void check(const ScriptContext sc)
        in {
            assert( sc !is null);
        }
    body {

        if ( runlevel > sc.runlevel ) {
            throw new ScriptException("Opcode not allowed in this runlevel");
        }
        else if ( sc.runlevel < 2 ) {
            if ( touched ) {
                throw new ScriptException("Opcode has already been executed (loop not allowed in this runlevel)");
            }
        }
        touched = true;
    }
}

@safe
class ScriptConditional : ScriptElement {
    private const ScriptElement jump;
    this(const ScriptElement jump) {
        runlevel=0;
        this.next=next;
        this.jump=jump;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(sc);
        if ( sc.pop.isTrue ) {
            return next;
        }
        else {
            return jump;
        }
    }
}

@safe
class ScriptJump : ScriptElement {
    private bool turing_complete;
    this(const ScriptElement next) {
        runlevel=2;
        this.next=next;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(sc);
        if ( turing_complete ) {
            if ( !sc.turing_complete) {
                throw new ScriptException("Illigal command ");
            }
        }
        sc.check_jump();
        return next; // Points to the jump position
    }
}

@safe
class ScriptCall : ScriptElement {
    private const ScriptElement call;
    this(const ScriptElement next, const ScriptElement call, immutable uint runlevel=2)
    in {
        assert( runlevel>=2 );
    }
    body {

        this.next=next;
        this.call=call;
        this.runlevel=2;
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
    private immutable T x;
    this(const ScriptElement next, T x) {
        this.x = x;
    }
    override ScriptElement opCall(const Script s, ScriptContext sc) {
        check(s, sc);
    }
}

class Script {
    private ScriptElement root, last;
    immutable uint runlevel;
    private ScriptContext sc;
    this(ScriptElement root, ScriptContext sc, immutable uint runlevel) {
        this.runlevel=runlevel;
        this.sc=sc;
        this.root=root;
    }
    void run() {
        for(const ScriptElement current=root; current !is null; current=current(this, context) ) {
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
}

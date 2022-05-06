module tagion.script.Script;

import std.stdio;
import std.conv;
import std.uni : toUpper;
import std.typecons : Typedef, TypedefType;

import std.range : enumerate;
import std.traits : EnumMembers, isIntegral;
import std.regex;

import core.exception : RangeError;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONBase : HiBONType = Type, isHiBONType;
import tagion.hibon.HiBONException : HiBONException;
import tagion.basic.Types : Buffer, BillType;
import tagion.Keywords;
import tagion.basic.TagionExceptions : TagionException;
import tagion.script.ScriptParser : Token;
import tagion.basic.Message;

import tagion.script.ScriptParser : ScriptKeyword, Lexer;
import tagion.script.ScriptBase;
import tagion.script.ScriptBlocks;

@safe
class ScriptContext {
    enum Mode {
        NONE,
        REWIND,
        ABORT
    }

    package Mode _mode;
    final @property Mode mode() pure const nothrow {
        return _mode;
    }

    public bool trace;

    private ScriptError errorElement;

    private string indent;

    protected {
        Value[] variables;
        uint fuel;
        size_t local_index_offset;
        Value[] _globals;
        Value[] _locals;
        Value[] data_stack;
        size_t _stack_index;
        uint iteration_count;
    }

    bool proceed(const ScriptElement element) const pure nothrow {
        return (element !is null);
    }

    private {

        final void setGlobals(const size_t size) {
            _globals = variables[0 .. size];
            // Clear global variables
            local_index_offset = size;
            //            return _globals;
        }

        final const(size_t) setLocals(const size_t size, const bool clean = true) {
            //            const old_index_offset=local_index_offset;
            const old_size = _locals.length;
            local_index_offset += old_size; //_locals.length;

            //          const old_size=_locals.length;
            _locals = variables[local_index_offset .. local_index_offset + size];
            if (clean) {
                foreach (ref v; _locals) {
                    v = null;
                }
            }
            return old_size;
        }

        final const(size_t) restoreLocals(const size_t old_size)
        in {
            assert(local_index_offset >= old_size + _globals.length);
        }
        do {
            local_index_offset -= old_size;
            _locals = variables[local_index_offset .. local_index_offset + old_size];
            return local_index_offset;
        }

    }

    final const(Value[]) stack() const pure {
        return data_stack[0 .. _stack_index];
    }

    final inout(Value[]) globals() inout pure {
        return _globals;
    }

    final inout(Value[]) locals() inout pure {
        return _locals;
    }

    final size_t varIndex(const(Variable) var) const pure nothrow {
        return local_index_offset + var.index;
    }

    final size_t local_available() const pure
    in {
        import std.format;

        assert(local_index_offset <= variables.length,
                format("Local offset is out of range %d > %d",
                local_index_offset, variables.length));
    }
    do {
        return variables.length - local_index_offset;
    }

    const(Value) opIndex(in uint index) const pure {
        import std.stdio;

        return variables[index];
    }

    void opIndexAssign(T)(const T x, in uint index) {
        variables[index] = Value(x);
    }

    this(const uint data_stack_size,
            const uint var_size,
            const uint iteration_count,
            const uint fuel) {
        data_stack.length = data_stack_size;
        variables.length = var_size;
        this.iteration_count = iteration_count;
        this.fuel = fuel;
    }

    const(ScriptError) error() pure const nothrow {
        return errorElement;
    }

    string errorMessage() {
        if (this.error) {
            return errorElement.toText;
        }
        return null;
    }

    bool empty() const pure nothrow {
        return (_stack_index == 0);
    }

    Value pop() {



            .check(_stack_index > 0, "Data stack empty");
        _stack_index--;
        scope (failure) {
            _stack_index++;
        }
        return data_stack[_stack_index];
    }

    void push(T)(T v) {



            .check(_stack_index < data_stack.length, message(
                    "Stack overflow (Data stack size=%d)", data_stack.length));
        scope (exit) {
            _stack_index++;
        }
        static if (is(T == Value)) {
            data_stack[_stack_index] = v;
        }
        else {
            data_stack[_stack_index] = Value(v);
        }
    }

    size_t stack_pointer() const pure nothrow {
        return _stack_index;
    }

    const(bool) stack_empty() const pure nothrow {
        return _stack_index is 0;

    }

    inout(Value) peek(const uint i = 0) inout {



            .check(_stack_index > i,
                    message("Stack peek overflow, stack pointer is %d and access pointer is %d",
                    _stack_index, i));
        return data_stack[_stack_index - 1 - i];
    }

    void poke(const uint i, Value value) {



            .check(_stack_index > i,
                    message("Stack poke overflow, stack pointer is %d and access pointer is %d",
                    _stack_index, i));
        data_stack[_stack_index - 1 - i] = value;
    }

    unittest {
        auto sc = new ScriptContext(8, 8, 8, 100);
        enum num = "1234567890_1234567890_1234567890_1234567890";
        // Data stack test
        sc.push(Number(num));
        auto pop_a = sc.pop.by!(FunnelType.NUMBER);
        assert(pop_a == Number(num));
    }
}

@safe
abstract class ScriptElement {
    const(ScriptElement) next;
    const(Token) token;
    immutable uint runlevel;

    this(const(Token) token, const(ScriptElement) next, immutable uint runlevel) {
        this.runlevel = runlevel;
        this.token = token;
        this.next = next;
    }

    /**
       Froce the last pointer in the ScriptElement chain to be set to the next
    */
    @trusted
    static package void __force_bind(ref const ScriptElement root, const ScriptElement last) {
        void set_last(ref const ScriptElement current) {
            if (current.next !is null) {
                set_last(current.next);
            }
            else {
                emplace(&(current.next), last);
            }
        }

        if (root) {
            set_last(root);
        }
        else {
            emplace(&root, last);
        }
    }

    @safe static void dump(const ScriptElement current, const uint count = 10) {
        //        uint count=10;
        if (current) {
            assert(count > 0);
            writefln("-> %s", current.toText);
            dump(current.next, count - 1);
        }
    }

    const(ScriptElement) opCall(const Script s, ScriptContext sc) const
    in {
        assert(s !is null);
        assert(sc !is null);
    }

    @safe
    static struct Range {
        protected {
            ScriptElement next;
            bool about;
            ScriptContext context;
        }
        const(ScriptElement) start;
        const(Script) script;
        @trusted
        this(const ScriptElement start, const Script script, ref ScriptContext context) {
            this.start = start;
            //            rewind;
            this.next = cast(ScriptElement) start;
            this.context = context;
            this.script = script;
        }

        const pure nothrow {
            bool empty() {
                return (next is null) && !about;
            }

            const(ScriptElement) front() {
                return next;
            }
        }

        @trusted
        void popFront() {
            next = cast(ScriptElement) next(script, context);
            with (ScriptContext.Mode) {
                final switch (context.mode) {
                case NONE:
                    // empty
                    break;
                case REWIND:
                    rewind;
                    break;
                case ABORT:
                    about = true;
                }
            }
        }

        @trusted
        void rewind() {
            next = cast(ScriptElement)(start);
            context._mode = ScriptContext.Mode.NONE;
        }
    }

    final void check(const Script s, ScriptContext sc) const
    in {
        assert(sc !is null);
        assert(s !is null);
    }
    do {



            .check(runlevel <= s.runlevel,
                    message("Opcode %s is only allowed in runlevel %d but the current runlevel is %d",
                    toText, runlevel, s.runlevel));



        .check(sc.fuel >= cost,
                message("At opcode %s the script runs out of fuel",
                toText));
        sc.fuel -= cost;
    }

    string toInfo() pure const nothrow {
        import std.conv;

        string result;
        with (token) {
            return name ~ " " ~ line.to!string ~ ":" ~ pos.to!string;
        }
    }

    string toText() const {
        return token.name;
    }

    uint cost() const pure nothrow {
        return 1;
    }
}

@safe
class ScriptError : ScriptElement {
    enum uint error_runlevel = 0;
    const(ScriptElement) problem_element;
    const(TagionException) exception;
    immutable(string) msg;
    this(string msg, const(ScriptElement) problem_element, const(ScriptElement) next = null, const(
            TagionException) ex = null) {
        this.msg = msg;
        this.problem_element = problem_element;
        this.exception = ex;
        if (problem_element) {
            super(problem_element.token, next, 0);
        }
        else {
            immutable(Token) token = {name: "Unknown"};
            super(token, next, 0);
        }
    }

    this(string msg, const(Token) token, const(ScriptElement) next) {
        this.problem_element = null;
        this.exception = null;
        this.msg = msg;
        super(token, next, 0);
    }

    this(string msg, const(ScriptElement) problem_element, const(TagionException) ex) {
        this(msg, problem_element, null, ex);
    }

    this(const ScriptError e) {
        this(e.msg, e.problem_element, e.exception);
    }

    package this(immutable(Token) token, string error) {
        problem_element = null;
        exception = null;
        this.msg = msg;
        super(token, null, error_runlevel);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        import std.stdio : writefln, writeln;

        writefln("Aborted: %s", msg);
        if (problem_element) {
            writeln(problem_element.toInfo);
        }
        sc.errorElement = new ScriptError(this);
        return next;
    }

    override string toText() const {
        if (problem_element) {
            return message("error: %s, element: %s", msg, problem_element.toInfo);
        }
        else {
            return message("error: %s", msg);
        }
    }
}

@safe
class ScriptConditional : ScriptElement {
    const(ScriptElement) brance_true;
    const(ScriptElement) brance_false;
    this(const(Token) token,
            const(ScriptElement) brance_true,
            const(ScriptElement) brance_false,
            const(ScriptElement) next) {
        this.brance_false = brance_false;
        this.brance_true = brance_true;
        ScriptElement.__force_bind(this.brance_true, next);
        ScriptElement.__force_bind(this.brance_false, next);

        super(token, next, RunLevel.CONDITIONAL);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if (sc.pop.get!bool) {
            return brance_true;
            // if ( const ScriptElement result=s.run(brance_true, sc) ) {
            //     return result;
            // }
        }
        else {
            return brance_false;
            if (const ScriptElement result = s.run(brance_false, sc)) {
                return result;
            }
        }
        return next;
    }
}

enum RunLevel : uint {
    CONDITIONAL = 0,
    LOOP = 0,
    JUMP = 0,
}

@safe abstract class ScriptDoLoop : ScriptElement {
    const(Variable) I;
    const(Variable) TO;
    //    private Number to;

    @trusted
    this(const(Token) token, const(ScriptElement) next, const(Block) block) {
        const do_block = cast(DoLoopBlock) block;
        I = do_block.I;
        TO = do_block.TO;
        super(token, next, RunLevel.LOOP);
    }
}

@safe class ScriptDo : ScriptDoLoop {
    //    const(ScriptElement) loop_body;
    this(const(Token) token,
            const(ScriptElement) loop_body,
            const(ScriptElement) after_loop,
            const(Token) end_loop,
            DoLoopBlock block) {
        ScriptElement script_end_loop;
        with (ScriptKeyword) {
            if (Lexer.get(end_loop.name.toUpper) is LOOP) {
                script_end_loop = new ScriptLoop!LOOP(end_loop, loop_body, after_loop, block);
            }
            else {
                script_end_loop = new ScriptLoop!ADDLOOP(end_loop, loop_body, after_loop, block);
            }
        }
        ScriptElement.__force_bind(loop_body, script_end_loop);
        super(token, loop_body, block);
        foreach (jump; block.jumps) {
            jump.brance(loop_body, after_loop);
        }
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto _i = sc.pop();
        if (const(ScriptError) error = I.check(_i, this)) {
            return error;
        }
        sc.locals[I.index] = new Value(_i);
        auto _to = sc.pop;
        if (const(ScriptError) error = TO.check(_to, this)) {
            return error;
        }
        sc.locals[TO.index] = new Value(_to);
        return next;
    }
}

@safe class ScriptLoop(ScriptKeyword keyword) : ScriptDoLoop {
    static assert(keyword is ScriptKeyword.LOOP || keyword is ScriptKeyword.ADDLOOP,
            format("The keyword should %s or %s", ScriptKeyword.LOOP, ScriptKeyword.ADDLOOP));
    enum ADDLOOP = keyword is ScriptKeyword.ADDLOOP;
    const(ScriptElement) loop_body;
    this(const(Token) token,
            const(ScriptElement) loop_body,
            const(ScriptElement) next,
            const(Block) block) {
        this.loop_body = loop_body;
        super(token, next, block);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        static if (ADDLOOP) {
            const inc = sc.pop.get!Number;
            auto i_add_1 = sc.locals[I.index].get!Number + inc;
        }
        else {
            auto i_add_1 = sc.locals[I.index].get!Number + 1;
        }
        const to = sc.locals[TO.index].get!Number;
        sc.locals[I.index].set(i_add_1);
        if (i_add_1 < to) {
            // Jump to the start of the loop
            return loop_body;
        }
        return next;
    }
}

@safe class ScriptBegin : ScriptElement {
    //    const(ScriptElement) loop_body;
    this(const(Token) token,
            const(ScriptElement) loop_body,
            const(ScriptElement) after_loop,
            const(Token) end_loop,
            BeginLoopBlock block) {
        //this.loop_body=loop_body;
        ScriptElement script_end_loop;
        with (ScriptKeyword) {
            if (Lexer.get(end_loop.name.toUpper) is UNTIL) {
                script_end_loop = new ScriptUntil(end_loop, loop_body, after_loop);
            }
            else {
                script_end_loop = new ScriptRepeat(end_loop, loop_body, after_loop);
            }
        }
        ScriptElement.__force_bind(loop_body, script_end_loop);
        super(token, loop_body, RunLevel.LOOP);
        foreach (jump; block.jumps) {
            jump.brance(loop_body, after_loop);
        }
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        //        s.run(this, sc);
        return next;
    }
}

@safe class ScriptRepeat : ScriptElement {
    const(ScriptElement) loop_body;
    this(const(Token) token,
            const(ScriptElement) loop_body,
            const(ScriptElement) next) {
        this.loop_body = loop_body;
        super(token, next, RunLevel.LOOP);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        return loop_body;
    }
}

@safe class ScriptUntil : ScriptRepeat {
    this(const(Token) token,
            const(ScriptElement) loop_body,
            const(ScriptElement) next) {
        super(token, loop_body, next);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if (!sc.pop.get!bool) {
            // Jump to the start of the loop
            return loop_body;
        }
        return next;
    }
}

version (none) @safe
class ScriptNotConditionalJump : ScriptConditionalJump {
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.check_jump();

        if (sc.pop.value == 0) {
            return _next;
        }
        else {
            return _jump;
        }
    }

    override string toText() const {
        auto target_false = (_jump is null) ? "null" : to!string(_jump.n);
        auto target_true = (_next is null) ? "null" : to!string(_next.n);
        return "if.true goto " ~ target_false;
    }
}

@safe
class ScriptExit : ScriptElement {
    this(const(Token) token, ScriptElement next, immutable uint runlevel) {
        super(token, next, runlevel);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        return null;
    }

    override string toText() const {
        return "exit";
    }
}

@safe
class ScriptFunc : ScriptElement {
    enum uint call_runlevel = 0;
    protected uint local_size;
    this(const(Token) token) {
        super(token, null, call_runlevel);
    }

    @trusted
    package void define(const(ScriptElement) next, const(FunctionBlock) func_block) {
        local_size = func_block.local_size;
        emplace(&this.next, next);
    }

    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        size_t old_size;
        try {
            old_size = sc.setLocals(local_size);
        }
        catch (RangeError e) {
            return new ScriptError(
                    message("Local %d variables can not be allocated only %d are available",
                    local_size, sc.local_available),
                    this);
        }
        scope (exit) {
            sc.restoreLocals(old_size);
        }
        return s.run(next, sc);
    }

    override string toText() const pure {
        import std.format;

        return format("call %s", name);
    }

    string name() const pure nothrow {
        return token.name;
    }
}

@safe class ScriptCall : ScriptElement {
    const(ScriptFunc) func;
    this(const(Token) token, const(ScriptFunc) func, const(ScriptElement) next) {
        this.func = func;
        super(token, next, 0);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        func(s, sc);
        return next;
    }

    override string toText() const pure {
        return "call";
    }
}

@safe abstract class ScriptJump : ScriptElement {
    this(const(Token) token, const(ScriptElement) next, immutable uint runlevel) {
        super(token, next, runlevel);
    }

    void brance(const(ScriptElement) bachward, const(ScriptElement) forward);
}

@safe class ScriptWhile : ScriptJump {
    protected ScriptElement forward;
    this(const(Token) token, const(ScriptElement) next, Block block) {
        auto sub_block = cast(SubBlock) block;
        sub_block.jumps ~= this;
        super(token, next, RunLevel.JUMP);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if (!sc.pop.get!bool) {
            return forward;
        }
        return next;
    }

    @trusted
    override void brance(const(ScriptElement) bachward, const(ScriptElement) forward) {
        //        writefln
        emplace(&this.forward, cast(ScriptElement) forward);
    }
}

@safe class ScriptAgain : ScriptJump {
    protected ScriptElement backward;
    this(const(Token) token, const(ScriptElement) next, Block block) {
        auto sub_block = cast(SubBlock) block;
        sub_block.jumps ~= this;
        super(token, next, RunLevel.JUMP);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        return backward;
    }

    @trusted
    override void brance(const(ScriptElement) backward, const(ScriptElement) forward) {
        emplace(&this.backward, cast(ScriptElement) backward);
    }
}

@safe class ScriptLeave : ScriptJump {
    protected ScriptElement forward;
    this(const(Token) token, const(ScriptElement) next, Block block) {
        auto sub_block = cast(SubBlock) block;
        sub_block.jumps ~= this;
        super(token, next, RunLevel.JUMP);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        return forward;
    }

    @trusted
    override void brance(const(ScriptElement) backward, const(ScriptElement) forward) {
        emplace(&this.forward, cast(ScriptElement) forward);
    }
}

//
// Constants
//
@safe
class ScriptNumber : ScriptElement {
    private Number x;
    this(const(Token) token, const(ScriptElement) next) {
        this.x = Number(token.name);
        super(token, next, 0);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.push(x);
        return next;
    }

    @trusted
    override string toText() const {
        import std.format : format;

        if (x.ulongLength == 1) {
            return x.toDecimalString;
        }
        else {
            return "0x" ~ x.toHex();
        }
    }

}

@safe
class ScriptText : ScriptElement {
    this(const(Token) token, const(ScriptElement) next) {
        super(token, next, 0);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        sc.push(text);
        return next;
    }

    @property string text() const pure nothrow {
        return token.name[1 .. $ - 1];
    }

    override string toText() const {
        return '"' ~ text ~ '"';
    }
}

version (none) @safe
class ScriptPrintText : ScriptText {
    this(const(Token) token, string text, const(ScriptElement) next) {
        super(token, text, next, 0);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        import std.stdio;

        writeln(text);
        return next;
    }

    override string toText() const {
        return token.name;
    }
}

//
@safe
class ScriptGetVar : ScriptElement {
    immutable bool local;
    const(Variable) var;
    this(const(Token) token, const(ScriptElement) next, const(Variable) var, const bool local = false) {
        this.var = var;
        this.local = local;
        super(token, next, 0);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        if (local) {
            auto value = sc.locals[var.index];

            if (value) {
                sc.push(value);
            }
            else {
                sc.push(var.initial);
            }

        }
        else {
            auto value = sc.globals[var.index];
            if (value) {

                sc.push(value);
            }
            else {
                sc.push(var.initial);
            }
        }
        return next;
    }

    override string toText() const {
        return var.name ~ " @";
    }
}

@safe
class ScriptPutVar : ScriptElement {
    immutable bool local;
    const(Variable) var;
    this(const(Token) token, const(ScriptElement) next, const(Variable) var, const bool local = false) {
        this.var = var;
        this.local = local;
        super(token, next, 0);
    }

    // PutVar operators which are valid for ScriptBinaryOpPutVar
    enum operators = [
            "-!", "+!", "/!", "*!", "%!", "<<!", ">>!", "&!", "|!", "^!",
            "-!@", "+!@", "/!@", "*!@", "%!@", "<<!@", ">>!@", "&!@", "|!@", "^!@",
        ];
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto value = sc.pop();
        if (const(ScriptError) error = var.check(value, this)) {
            return error;
        }

        if (local) {
            sc.locals[var.index] = new Value(value);
        }
        else {
            sc.globals[var.index] = new Value(value);
        }

        return next;
    }

    override string toText() const {
        return var.name ~ " !";
    }

}

mixin template ScriptElementTemplate(string element_name, immutable uint level,
        bool CTOR = true, uint COST = 1,
        uint LINE = __LINE__, string FILE = __FILE__) {
    enum name = element_name;

    alias ScriptType = typeof(this);

    static if (CTOR) {
        this(const(Token) token, const(ScriptElement) next) {
            super(token, next, level);
        }

        static ScriptElement create(const(Token) token, const(ScriptElement) next) {
            return new ScriptType(token, next);
        }
    }

    static this() {
        import std.format;
        import std.stdio;

        assert(name !in Script.opcreators,
                format("Opcreator '%s' for %s has already been used (defined in %s:%d)",
                ScriptType.stringof, name, FILE, LINE));
        Script.opcreators[name] = &create;
    }

    override string toText() const {
        return name;
    }

    static assert(COST > 0, "Cost must be large than 0");
    static if (COST !is 1) {
        override uint cost() const pure nothrow {
            return COST;
        }
    }

}

/* Arhitmentic opcodes */

@safe
class ScriptUnitaryOp(string O) : ScriptElement {
    mixin ScriptElementTemplate!(O, 0);
    enum op = O;

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        with (FunnelType) {
            static if (op == "1-") {
                sc.push(sc.pop.by!NUMBER - 1);
            }
            else static if (op == "1+") {
                sc.push(sc.pop.by!NUMBER + 1);
            }
            else {
                static assert(0, "Unitary operator " ~ op.stringof ~ " not defined");
            }
        }
        return next;
    }

    override string toText() const {
        return op;
    }
}

static this() { // Create Unitary operators
    import std.format;

    static foreach (i, op; ["1-", "1+"]) {
        {
            enum code = format("alias ScriptType=ScriptUnitaryOp!\"%s\";", op);
            mixin(code);
        }
    }

}

@safe
class ScriptBinaryOp(string O) : ScriptElement {
    mixin ScriptElementTemplate!(O, 0);
    enum op = O;

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        Number b, a;
        try {
            with (FunnelType) {
                b = sc.pop.by!NUMBER;
                a = sc.pop.by!NUMBER;
            }
        }
        catch (TagionException ex) {
            return new ScriptError("Type or operator problem", this, ex);
        }
        static if ((op == "/") || (op == "%")) {
            if (b == 0) {
                return new ScriptError("Division by zero", this);
            }
        }
        static if (op == "<<") {
            if (b < 0) {
                return new ScriptError("Left shift divisor must be positive", this);
            }
            if (b == 0) {
                sc.push(a);
            }
            else {
                auto _b = cast(int) b;
                if (b > s.MAX_SHIFT_LEFT) {
                    return new ScriptError("Left shift overflow", this);
                }
                auto y = a << _b;
                sc.push(y);
            }
        }
        else static if (op == ">>") {
            if (b < 0) {
                return new ScriptError("Left shift divisor must be positive", this);
            }
            if (b == 0) {
                sc.push(a);
            }
            else {
                auto _b = cast(uint) b;
                auto y = a >> _b;
                sc.push(y);
            }
        }
        else {
            mixin("sc.push(a" ~ op ~ "b);");
        }
        return next;
    }

    override string toText() const {
        return op;
    }
}

static this() { // Create binary operators
    import std.format;

    static foreach (i, op; ["-", "+", "/", "*", "%", "<<", ">>", "&", "|", "^"]) {
        {
            enum code = format(`alias ScriptType=ScriptBinaryOp!"%s";`, op);
            mixin(code);
        }
    }
}

@safe
class ScriptCompareOp(string O) : ScriptElement {
    mixin ScriptElementTemplate!(O, 0);
    enum op = O;

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            auto b = sc.pop;
            auto a = sc.pop;

            bool result;
            with (FunnelType) {
                switch (b.type) {
                case NUMBER:
                    const a_val = a.by!NUMBER;
                    const b_val = b.by!NUMBER;
                    mixin("result = a_val" ~ op ~ "b_val;");
                    break;
                case TEXT:
                    const a_val = a.by!TEXT;
                    const b_val = b.by!TEXT;
                    mixin("result = a_val" ~ op ~ "b_val;");
                    break;
                case BINARY:
                    static if ((op == "==") || (op == "!=")) {
                        const a_val = a.by!BINARY;
                        const b_val = b.by!BINARY;
                        mixin("result = a_val" ~ op ~ "b_val;");
                    }
                    else {
                        goto default;
                        //                            return new ScriptError(format("Compare operator %s can not be used on %s type", O, b.type));
                    }
                    break;
                default:
                    return new ScriptError(message("Compare operator %s can not be used on %s type", O, b
                            .type), this);
                }
            }
            sc.push(result);
        }
        catch (TagionException ex) {
            return new ScriptError(message("Operator %s causes an fail", op), this, ex);
        }
        return next;
    }

    override string toText() const {
        return op;
    }
}

static this() { // Create binary operators
    import std.format;

    static foreach (op; ["==", "!=", ">", "<", ">=", "<="]) {
        {
            enum code = format("alias ScriptType=ScriptCompareOp!\"%s\";", op);
            mixin(code);
        }
    }
}

@safe
class ScriptStackOp(string O) : ScriptElement {
    mixin ScriptElementTemplate!(O, 0);
    enum op = O;
    static if (O == "2SWAP") {
        pragma(msg, "fixme(cbr): Some of the stack operations can be optimized using array.opSlice operations");
    }
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        static if (op == "DUP") { // a -- a a
            sc.push(sc.peek);
        }
        else static if (op == "SWAP") { // ( a b -- b a )
            auto a = sc.pop;
            auto b = sc.pop;
            sc.push(b);
            sc.push(a);
        }
        else static if (op == "DROP") { // ( a -- )
            sc.pop;
        }
        else static if (op == "OVER") { // ( a b -- a b a )
            sc.push(sc.peek(1));
        }
        else static if (op == "ROT") { // ( a b c -- b c a )
            auto c = sc.pop;
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(b);
            sc.push(c);
            sc.push(a);
        }
        else static if (op == "-ROT") { // ( a b c -- c a b )
            auto c = sc.pop;
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(c);
            sc.push(a);
            sc.push(b);
        }
        else static if (op == "NIP") { // ( a b -- b )
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(b);
        }
        else static if (op == "TUCK") { // ( a b -- b a b )
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(b);
            sc.push(a);
            sc.push(b);
        }
        else static if (op == "2DUP") { // ( a b -- a b a b )
            auto a = sc.peek(0);
            auto b = sc.peek(1);
            sc.push(a);
            sc.push(b);
        }
        else static if (op == "2SWAP") { // ( a b c d -- c b a b )
            auto d = sc.pop;
            auto c = sc.pop;
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(c);
            sc.push(b);
            sc.push(a);
            sc.push(d);
        }
        else static if (op == "2DROP") { // ( a b -- )
            sc.pop;
            sc.pop;
        }
        else static if (op == "2OVER") { // ( a b c d -- a b c d a b )
            auto b = sc.peek(2);
            auto a = sc.peek(3);
            sc.push(a);
            sc.push(b);
        }
        else static if (op == "2NIP") { // ( a b c d -- a b )
            auto d = sc.pop;
            auto c = sc.pop;
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(b);
            sc.push(a);
        }
        else static if (op == "2TUCK") { // ( a b c d -- a b c d a b )
            auto d = sc.pop;
            auto c = sc.pop;
            auto b = sc.pop;
            auto a = sc.pop;
            sc.push(a);
            sc.push(b);
            sc.push(a);
            sc.push(b);
            sc.push(d);
            sc.push(b);
        }
        else {
            static assert(0, "Stack operator " ~ op.stringof ~ " not defined");
        }
        return next;
    }
}

static this() { // Stack operations
    enum Operators = [
            "DUP", // a -- a a
            "SWAP", // ( a b -- b a )
            "DROP", // ( a -- )
            "OVER", // ( a b -- a b a )
            "ROT", // ( a b c -- b c a )
            "-ROT", // ( a b c -- c a b )
            "NIP", // ( a b -- b )
            "TUCK", // ( a b -- b a b )
            "2DUP", // ( a b -- a b a b )
            "2SWAP", // ( a b c d -- c b a b )
            "2DROP", // ( a b -- )
            "2OVER", // ( a b c d -- a b c d a b )
            "2NIP", // ( a b c d -- a b )
            "2TUCK", // ( a b c d -- a b c d a b )
        ];

    static foreach (i, op; Operators) { //
        import std.format;

        {
            enum code = format("alias ScriptType=ScriptStackOp!\"%s\";", op);
            mixin(code);
        }
    }

}

@safe
class ScriptOpPutVar(string O) : ScriptPutVar {
    static assert(O.length >= 2);
    static if (O[$ - 1] == '!') {
        enum op = O[0 .. $ - 1];
        enum PUSH_RESULT = false;
    }
    else static if (O[$ - 2 .. $] == "!@") {
        enum op = O[0 .. $ - 2];
        enum PUSH_RESULT = true;
    }
    else {
        static assert(0, format("Operator %s should be ! or !@ opertor", O));
    }

    this(const(Token) token, const(ScriptElement) next, const(Variable) var, const bool local = false) {
        super(token, next, var, local);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto value = sc.pop();
        if (const(ScriptError) error = var.check(value, this)) {
            return error;
        }
        Value var_a;
        if (local) {
            var_a = sc.locals[var.index];
        }
        else {
            var_a = sc.globals[var.index];
        }
        with (FunnelType) {
            switch (var.type) {
            case NUMBER:
                const b = value.by!NUMBER;
                auto a = var_a.by!NUMBER;
                static if ((op == "/") || (op == "%")) {
                    if (b == 0) {
                        return new ScriptError("Division by zero", this);
                    }
                }
                static if (op == "<<") {
                    if (b < 0) {
                        return new ScriptError("Left shift divisor must be positive", this);
                    }
                    if (b == 0) {
                        // Do nothing
                    }
                    else if (b > s.MAX_SHIFT_LEFT) {
                        return new ScriptError("Left shift overflow", this);
                    }
                    else {
                        auto _b = cast(uint) b;
                        a <<= _b;
                    }
                }
                else static if (op == ">>") {
                    if (b < 0) {
                        return new ScriptError("Left shift divisor must be positive", this);
                    }
                    if (b == 0) {
                        // Do nothing
                    }
                    else {
                        auto _b = cast(uint) b;
                        a >>= _b;
                        //                        sc.push(y);
                    }
                }
                else {
                    import std.format;

                    enum code = format("a%s=b;", op);
                    mixin(code);
                    //                    writefln("OP %s a=%s b=%s code=%s c=%s", O, a, b, code, c);
                }
                if (local) {
                    sc.locals[var.index] = new Value(a);
                }
                else {
                    sc.globals[var.index] = new Value(a);
                }
                static if (PUSH_RESULT) {
                    sc.push(a);
                }
                break;
            case TEXT:
                static if (op == "+") {
                    string a = var_a.by!TEXT;
                    const b = sc.pop.by!TEXT;
                    a ~= b;
                    if (local) {
                        sc.locals[var.index] = new Value(a);
                    }
                    else {
                        sc.globals[var.index] = new Value(a);
                    }
                    static if (PUSH_RESULT) {
                        sc.push(a);
                    }
                }
                else {
                    goto default;
                }
                break;
            default:
                return new ScriptError(message("Invalid operator %s for type %s", O, var.type), this);
            }
        }
        return next;
    }

    override string toText() const {
        return message("%s %s", var.name, O);
    }
}

static this() { // Create put assign operators
    import std.format;

    static foreach (i, op; ScriptPutVar.operators) {
        {
            enum code = format("alias ScriptType=ScriptOpPutVar!\"%s\";", op);
            mixin(code);
        }
    }
}

enum TraceType = [
        "TRACE_ON",
        "TRACE_OFF",
    ];

@safe
class ScriptTrace(string O = TraceType[0]) : ScriptElement {
    enum op = O;
    mixin ScriptElementTemplate!(O, 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        static if (O == "TRACE_ON") {
            sc.trace = true;
        }
        else static if (O == "TRACE_OFF") {
            sc.trace = false;
        }
        else {
            static assert(0, format("Invalid operator name %s for %s", O, T.stringof));
        }
        return next;
    }

    override string toText() const {
        return O;
    }
}

static this() {
    static foreach (op; TraceType) {
        {
            alias ScriptType = ScriptTrace!op;
        }
    }
}

version (none) @safe
class ScriptPrintStack : ScriptElement {
    mixin ScriptElementTemplate!(".S", 0);
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        writeln("Stack:");
        size_t stack_index;
        foreach_reverse (v; sc.stack) {
            writefln("%02d] %s", stack_index, v);
            stack_index++;
        }
        return next;
    }
}

// Dot commands
enum Dot {
    L = ".L",
    V = ".V",
    S = ".S"
}

@safe
class ScriptDebugPrint(Dot O) : ScriptElement {
    enum name = O.stringof;
    const Block block;

    this(const(Token) token, const(ScriptElement) next, const(Block) block) {
        this.block = block;
        super(token, next, 0);
    }

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        import std.stdio;

        check(s, sc);
        static if (O is Dot.S) {
            writefln("Stack: %s", block.funcName);
            size_t stack_index;
            foreach_reverse (v; sc.stack) {
                writefln("%s %03d] %s", sc.indent, stack_index, v);
                stack_index++;
            }
        }
        else static if (O is Dot.L) {
            writefln("Locals: %s", block.funcName);
            foreach (v; block.localVariables) {
                writefln("%s %03d:%s %s", sc.indent, sc.varIndex(v), v.name, sc.locals[v.index]);
            }
        }
        else static if (O is Dot.V) {
            writefln("Globals: %s", block.funcName);
            foreach (v; s.variables) {
                writefln("%s .%03d:%s %s", sc.indent, v.index, v.name, sc.globals[v.index]);
            }
        }
        else {
            static assert(0, format("Dot code %s not defined yet", O));
        }
        return next;
    }
}

// Should be create automaticaly when a hibon variable is used
version (none) @safe
class ScriptCreateHiBON : ScriptElement {
    /*
        creates a new bson in the bsons array as an element
        and returns the bsons_index on the stack.
    */
    mixin ScriptElementTemplate!("createbson", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        try {
            auto hibon = new HiBON;
            sc.push(hibon);
            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this);
        }
    }
}

@safe
class ScriptPutHiBON : ScriptElement {
    /*
        Stores a bson_value in a bson object at the specified field.
        bsons_index bson_key bson_value bson!
    */
    mixin ScriptElementTemplate!("bson!", 0);

    //    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        try {
            auto hibon_value = sc.pop;
            auto hibon_key = sc.pop.by!(FunnelType.TEXT);
            auto hibon = sc.pop.by!(FunnelType.HIBON);



            .check(hibon_key.length !is 0, "The hibon field name cannot be empty");

            //            auto hibon=sc.hibon(hibons_index);

            with (FunnelType) final switch (hibon_value.type) {
            case NONE:
                return new ScriptError(
                        message("Not possible to store a %s in a hibon value", hibon_value.type), this);
                break;
            case NUMBER:
                hibon[hibon_key] = hibon_value.by!NUMBER;
                break;
            case TEXT:
                hibon[hibon_key] = hibon_value.by!TEXT;
                break;
            case HIBON:
                hibon[hibon_key] = hibon_value.by!HIBON; //sc.hibon(hibon_index);
                break;
            case DOCUMENT:
                hibon[hibon_key] = hibon_value.by!DOCUMENT;
                break;
            case BINARY:
                hibon[hibon_key] = hibon_value.by!BINARY;
                break;
            }

            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an Script Exception: " ~ ex.msg, this);
        }
        catch (HiBONException ex) {
            return new ScriptError(name ~ " got an HiBON Exception: " ~ ex.msg, this);
        }
        catch (ConvOverflowException ex) {
            return new ScriptError(name ~ " got an Conversion Overflow Exception: " ~ ex.msg, this);
        }
    }
}

//ulong

@safe
class ScriptGetBSON : ScriptElement {
    /*
        Gets a bson_value in a bson object at the specified field.
        bsons_index bson_key bson!
    */
    mixin ScriptElementTemplate!("bson@", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        try {
            with (FunnelType) {
                auto hibon_key = sc.pop.by!TEXT;
                auto hibon = sc.pop().by!(FunnelType.HIBON);
                Value value;
                auto hibon_elm = hibon[hibon_key];
            TypeCase:
                switch (hibon_elm.type) {
                    static foreach (E; EnumMembers!HiBONType) {
                        static if (isHiBONType(E)) {
                case E:
                            static if (__traits(compiles, Value(hibon_elm.by!E))) {
                                value = Value(hibon_elm.by!E);
                                break TypeCase;
                            }
                            goto default;
                        }
                    }
                default:
                    throw new ScriptException(message("HiBON type %s is not supported by Funnel", hibon_elm
                            .type));
                }
                sc.push(value);
                return next;
            }
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this, ex);
        }
        catch (HiBONException ex) {
            return new ScriptError(name ~ " got an BSON Exception: " ~ ex.msg, this, ex);
        }
    }
}

@safe
class ScriptExpandHiBON : ScriptElement {
    mixin ScriptElementTemplate!("expandhibon", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        check(s, sc);
        auto hibon = sc.pop.by!(FunnelType.HIBON);
        sc.push(Document(hibon.serialize));
        return next;
    }
}

@safe
class ScriptGetDocument : ScriptElement {
    /*
        Gets a doc value in a document object at the specified field.
        document doc_key doc@
    */
    mixin ScriptElementTemplate!("doc@", 0);

    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            Document.Element getDoc(const Value doc_key, out ScriptError error) {
                with (FunnelType) {
                    switch (doc_key.type) {
                    case TEXT:
                        immutable key = doc_key.by!TEXT;
                        const doc = sc.pop.by!DOCUMENT;
                        return doc[key];
                        break;
                    case NUMBER:
                        const num = doc_key.by!NUMBER;
                        const index = num.to!uint;
                        const doc = sc.pop.by!DOCUMENT;
                        return doc[index];
                        break;
                    default:
                        error = new ScriptError(
                                message("Document key must be either a %s or %s but is %s",
                                TEXT, NUMBER, doc_key.type), this);
                        return Document.Element(null);
                    }
                }
            }

            auto doc_key = sc.pop;

            ScriptError error;
            auto doc_elm = getDoc(doc_key, error);

            if (error) {
                return error;
            }

            Value value;
            with (HiBONType) {
            TypeCase:
                switch (doc_elm.type) {
                    static foreach (E; EnumMembers!HiBONType) {
                case E:
                        static if (isHiBONType(E)) {
                            alias T = HiBON.Value.TypeT!E;
                            static if (__traits(compiles, Value(doc_ele.get!T))) {
                                value = Value(doc_elm.get!T);
                                break TypeCase;
                            }
                            goto default;
                        }
                    }
                default:
                    return new ScriptError(message("Bson_Type: %s not implemented", doc_elm.type), this);
                }
            }
            sc.push(value);

            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(message("%s got an exception: %s", name, ex.msg), this, ex);
        }
        catch (HiBONException ex) {
            return new ScriptError(message("%s got an BSON Exception: %s", name, ex.msg), this, ex);
        }
    }
}

@safe
class ScriptGetLength : ScriptElement {
    /*
        Gets the length of a document or hibon array
        object length@
    */
    mixin ScriptElementTemplate!("length@", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            auto obj = sc.pop;

            with (FunnelType) {
                switch (obj.type) {
                case HIBON:
                    auto hibon = obj.by!HIBON;
                    sc.push(hibon.length);
                    break;
                case DOCUMENT:
                    auto doc = obj.by!DOCUMENT;
                    sc.push(doc.length);
                    break;
                default:
                    return new ScriptError(
                            message("Can only get length of HiBON and Doc types, not: %s", obj.type),
                            this
                    );
                }
            }

            //          sc.push(value);
            return next;
        }
        catch (HiBONException ex) {
            return new ScriptError(message("%s got an BSON Exception: %s", name, ex.msg), this);
        }
    }
}

@safe
class ScriptAssert : ScriptElement {
    /*
        Asserts if the value on the stack is true
        otherwise throws a scriptexception
    */
    mixin ScriptElementTemplate!("assert", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            with (FunnelType) {
                const msg = sc.pop.by!TEXT;
                const flag = sc.pop.by!NUMBER;

                if (!flag) {
                    return new ScriptError(
                            message("Assert error: %s", msg),
                            this);
                }
            }
            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(
                    message("%s got an exception: %s", name, ex.msg),
                    this, ex);
        }
    }
}

@safe
class ScriptConcat : ScriptElement {
    /*
        Cancatenates to arrays, immutable(ubyte)[]=Buffer, returns a ~ b
        buffer_a buffer_b concat
    */
    mixin ScriptElementTemplate!("concat", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            Buffer buffer_b = sc.pop.get!Buffer;
            Buffer buffer_a = sc.pop.get!Buffer;

            sc.push(buffer_a ~ buffer_b);

            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this);
        }
    }
}

// Should be implement as a range
version (none) @safe
class ScriptGetKeys : ScriptElement {
    /*
        Return all keys from a Document/HBSON as a document, HBSON or Document, returns Document
        document keys@
    */
    mixin ScriptElementTemplate!("keys@", 0);

    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            auto obj = sc.pop;

            //            string[] keys;
            auto result = new HiBON();

            with (FunnelType) {
                switch (obj.type) {
                case HIBON:
                    auto hibon = sc.hibon(obj.get!(HiBONIndex));
                    foreach (i, key; hibon.keys.enumerate(uint(0))) {
                        result[i] = key;
                    }
                    break;
                case DOCUMENT:
                    const doc = obj.get!Document;
                    foreach (i, key; doc.keys.enumerate(uint(0))) {
                        result[i] = key;
                    }
                    //                    keys=doc.keys.array;
                    break;

                default:
                    return new ScriptError(message("Can only use Hibon and Doc types, not: %s", obj
                            .type), this);
                }
            }

            // foreach ( index, key; keys) {
            //     result[index]=key;
            // }

            auto value = Value(Document(result.serialize));

            sc.push(value);
            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(message("%s got an exception: %s", name, ex.msg), this, ex);
        }
        catch (HiBONException ex) {
            return new ScriptError(message("%s got an BSON Exception: %s", name, ex.msg), this, ex);
        }
    }
}

@safe
class ScriptHasKey : ScriptElement {
    /*
        Assess if a key exists in a Document/HBSON, Returns -1(true) or 0(false)
        document key hasKey@
    */
    mixin ScriptElementTemplate!("hasKey@", 0);

    @trusted
    override const(ScriptElement) opCall(const Script s, ScriptContext sc) const {
        try {
            check(s, sc);
            auto key_obj = sc.pop;
            auto obj = sc.pop;

            string key;
            with (FunnelType) {
                switch (key_obj.type) {
                case TEXT:
                    key = key_obj.by!TEXT;
                    break;
                case NUMBER:
                    key = (key_obj.by!NUMBER).to!string;
                    break;
                default:
                    return new ScriptError(message("Can only use text and integers as key types, not: %s", obj
                            .type), this);
                }
            }

            bool result;
            with (FunnelType) {
                switch (obj.type) {
                case HIBON:
                    const hibon = obj.by!HIBON;
                    //                    sc.hibon(obj.get!(HiBONIndex));
                    result = hibon.hasMember(key);
                    break;
                case DOCUMENT:
                    auto doc = obj.by!DOCUMENT;
                    result = doc.hasMember(key);
                    break;
                default:
                    return new ScriptError(message("Can only use HiBON and Doc as document types, not: %s", obj
                            .type), this);
                }
            }

            sc.push(Value(result));
            return next;
        }
        catch (ScriptException ex) {
            return new ScriptError(name ~ " got an exception: " ~ ex.msg, this);
        }
        catch (HiBONException ex) {
            return new ScriptError(name ~ " got an BSON Exception: " ~ ex.msg, this);
        }
    }
}

@safe
class Script {
    const Script super_script;
    this(const Script super_script = null) {
        if (super_script) {
            this.variable_count = super_script.variable_count;
        }
        this.super_script = super_script;
    }

    @safe static class Variable {
        immutable FunnelType type;
        immutable(string) name;
        uint index;
        this(string name, const FunnelType type) {
            this.name = name;
            this.type = type;
            //            this.index=index;
        }

        const(ScriptError) check(ref const(Value) value, const(ScriptElement) element) const {
            if (value.type !is type) {
                return new ScriptError(message("Variable %s type mismatch expected %s but got %s",
                        name, type, value.type), element);
            }
            return null;
        }

        Value initial() const {
            with (FunnelType) {
                final switch (type) {
                case NONE:
                    assert(0, "Invalid value type");
                case TEXT:
                    return new Value("");
                case HIBON:
                    return new Value(new HiBON);
                case DOCUMENT:
                    return new Value(Document());
                case BINARY:
                    immutable(ubyte)[] binary;
                    return new Value(binary);
                case NUMBER:
                    return new Value(0);
                }
            }
            assert(0);
        }
    }

    @safe static class BoundVariable(T = void) : Variable {
        enum BIG = is(T == void);
        alias BoundVariableT = BoundVariable!T;
        static if (BIG) {
            const Number min;
            const Number max;
            this(string name, const Number min, const Number max) {
                super(name, FunnelType.NUMBER);
                this.min = min;
                this.max = max;
            }
        }
        else {
            static assert(isIntegral!T);
            this(string name) {
                super(name, FunnelType.NUMBER);
            }

            enum min = T.min;
            enum max = T.min;
        }

        override const(ScriptError) check(ref const(Value) value, const(ScriptElement) element) const {
            const check_type = super.check(value, element);
            if (check_type) {
                return check_type;
            }
            const num = value.by!(FunnelType.NUMBER);
            if ((num >= min) && (num <= max)) {
                return null;
            }
            return new ScriptError(message("Value %s outside the range [%d..%d] defined for variable %s",
                    num, min, max, name), element);
        }

        override Value initial() const {
            return new Value(min);
        }
    }

    alias Opcreate = ScriptElement function(const(Token) token, const(ScriptElement) next);

    package static Opcreate[string] opcreators;

    static ScriptElement createElement(string op, const(Token) token, lazy const(ScriptElement) element) {
        if (op in opcreators) {
            return Script.opcreators[op](token, element);
        }
        return null;
    }

    package ScriptFunc[string] functions;

    void defineFunc(string func_name, ScriptFunc call) {



            .check((func_name in functions) is null, message("Function %s already defined", func_name));
        functions[func_name] = call;
    }

    const(ScriptFunc) getFunc(string name) const pure {
        const result = functions.get(name, null);
        if ((super_script !is null) && (result is null)) {
            return super_script.getFunc(name);
        }
        return result;
    }

    package void setFunc(string name, const(ScriptElement) next, const(FunctionBlock) block) {
        auto def = functions.get(name, null);



        .check(def !is null, message("Function %s has not been defined", name));
        def.define(next, block);
    }

    private Variable[string] variables;
    private uint variable_count;

    uint num_of_globals() const pure nothrow {
        return variable_count;
    }

    void defineVar(ref Variable var) {



            .check(!existVar(var.name), message("Multiple declaration of variable '%s'", var.name));
        var.index = variable_count;
        variables[var.name] = var;
        variable_count++;
    }

    bool existVar(string var_name) const pure nothrow {
        const result = var_name in variables;
        if ((super_script !is null) && (result is null)) {
            return super_script.existVar(var_name);
        }
        return result !is null;
    }

    const(Variable) getVar(string var_name) const {
        const result = variables.get(var_name, null);
        if ((super_script !is null) && (result is null)) {
            return super_script.getVar(var_name);
        }
        return result;
    }

    uint opCall(string var_name) const {
        const var_toUpper = var_name.toUpper;



        .check(existVar(var_toUpper), message("Variable '%s' is not defined", var_name));
        return getVar(var_toUpper).index;
    }

    private uint runlevel;
    enum MAX_SHIFT_LEFT = (1 << 12) + (1 << 7);

    /**
       Allocate global variables for the script in sc
       Note: This is done automatically by execute
     */
    void allocateGlobals(ref ScriptContext sc) const {
        sc.setGlobals(variable_count);
    }

    /**
       This function calls function @func_name and allocate global variables
     */
    const(ScriptElement) execute(string func_name, ScriptContext sc) {
        sc.setGlobals(variable_count);
        return call(func_name, sc);
    }

    /**
       This function calls the function and allocate global variables
       This is primally used for flat-functions
     */
    const(ScriptElement) execute(const(ScriptFunc) caller, ScriptContext sc) {
        sc.setGlobals(variable_count);
        return caller(this, sc);
    }

    /**
       Call a function @func_name with out allocation global variables
     */
    const(ScriptElement) call(string func_name, ScriptContext sc) const {
        const caller = functions.get(func_name.toUpper, null);
        if (caller) {
            return caller(this, sc);
        }
        return new ScriptError(message("Function %s does not exist", func_name), null);
    }

    @trusted package const(ScriptElement) run(const ScriptElement start, ScriptContext sc) const {
        ScriptElement current = cast(ScriptElement) start;
        while (sc.proceed(current)) {
            if (sc.trace) {
                writefln("%s%s", sc.indent, current.toText);
            }
            current = cast(ScriptElement) current(this, sc);
        }
        return current;
    }

    bool is_turing_complete() pure nothrow const {
        return (runlevel > 1);
    }
}

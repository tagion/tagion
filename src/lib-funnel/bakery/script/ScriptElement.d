
@safe
class Value {
    immutable(ulong[]) data;
    this(const(ulong)[] x) {
        data=cast(immutable(ulong[]))x.idup;
    }
    bool isTrue() pure nothrow const {
        foreach(d;data) {
            if ( d ) {
                return true;
            }
        }
        return false;
    }
}

@safe
class ScriptContext {
    private const(Value)[] stack;
    private uint stack_index;
    this(uint stack_size) {
        stack=new Value[stack_size];
    }
    void push(const(Value) v) {
        if ( stack_index < stack_size) {
            stack[stack_index++]=v;
        }
        else {
            throw new ScriptException("Stack overflow");
        }
    }
    const(Value) pop() {
        if ( stack_index > 0 ) {
            stack_index--;
        }
        else {
            throw new ScriptException("Stack empty");
        }
        return stack[stack_index];

    }
}


class ScriptElement {
    private const ScriptElement next;
    this(const ScriptElement next) {
        this.next=next;
    }
    ScriptElement doit(const ScriptContext) {
        throw new ScriptException("Undefined script element");
        return next;
    }
}

class ScriptConditial : ScriptElement {
    private ScriptElement jump;
    override ScriptElement doit(const ScriptContext sc) {
        if ( sc.pop.isTrue ) {
            return next;
        }
        else {
            return jump;
        }
    }
}

class ScriptJump : ScriptElement {
    private bool turing complete;
    override ScriptElement doit(const ScriptContext sc) {
        if ( turing_complete ) {
            throw new ScriptException("Illigal ");
        }
        return next; // Points to the jump position
    }
}

class ScriptJump : ScriptElement {
    override ScriptElement doit(const ScriptContext sc) {
        if ( tu
        return next; // Points to the jump position
    }
}



class ScriptConditial : ScriptElement {
    private ScriptElement jump;
    override ScriptElement doit(const ScriptContext sc) {
        if ( sc.pop.isTrue ) {
            return next;
        }
        else {
            return jump;
        }
    }
}



class ScriptAdd : ScriptElement {
    ScriptElemet
}

class PushLiteral : ScriptElement {

}

class Script {
    private const ScriptElement root;
    this(const ScriptElement root) {

    }
    void append(const
}

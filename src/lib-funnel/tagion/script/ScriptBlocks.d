module tagion.script.ScriptBlocks;

import std.stdio;
import tagion.script.ScriptParser : Lexer, ScriptKeyword;
import tagion.script.Script;
import tagion.script.ScriptParser : Token;
import tagion.basic.Message : message;
import tagion.script.ScriptBase : Value, FunnelType, check;

alias Variable = Script.Variable;

@safe
abstract class Block {
    protected Block _parent;
    Block parent() nothrow {
        return _parent;
    }

    enum BlockCategory {
        NONE,
        GLOBAL,
        FUNCTION,
        FLAT,
        BRANCH,
        LOOP,
    }

    immutable BlockCategory category;
    //immutable(string) func_name;
    //immutable bool function_scope;
    enum reservedVar {
        I = "I",
        TO = "TO",
    }

    static string getLoopVarName(string name, const uint loop_level) pure {
        import std.format;

        return (loop_level is 0) ? "" : format("%s%d", name, loop_level);
    }

    this(Block parent, immutable BlockCategory category) {
        this._parent = parent;
        this.category = category;
    }

    final string Iname() pure const {
        return getLoopVarName(reservedVar.I, loopLevel);
    }

    final string TOname() pure const {
        return getLoopVarName(reservedVar.TO, loopLevel);
    }

    final inout(Block) getBlock(const BlockCategory find) inout pure nothrow {
        @safe inout(Block) search(inout(Block) current) pure nothrow {
            if ((current !is null) && (current.category !is find)) {
                return search(current._parent);
            }
            return current;
        }

        return search(this);
    }

    uint loopLevel() pure const nothrow {
        const current = getBlock(BlockCategory.LOOP);
        if (current) {
            return current.loopLevel;
        }
        return 0;
    }

    @trusted
    final FunctionBlock funcBlock() const pure nothrow {
        return cast(FunctionBlock)(getBlock(BlockCategory.FUNCTION));
    }

    string funcName() pure const nothrow {
        return funcBlock.funcName;
    }

    const(Variable[string]) localVariables() pure const nothrow;
    bool end(ScriptKeyword type) const pure nothrow;
    bool valid(ScriptKeyword type) const pure nothrow;
    void defineVar(ref Variable var);
    const(Variable) getVar(string var_name) const;
    bool existVar(string var_name) const pure nothrow;
}

@safe
class GlobalBlock : Block {
    protected Script script;
    immutable string func_name;
    this(Script script) {
        func_name = "::global";
        this.script = script;
        super(null, BlockCategory.GLOBAL);
    }

    override string funcName() const pure nothrow {
        return func_name;
    }

    override const(Variable[string]) localVariables() pure const nothrow {
        import std.format;

        assert(0, format("%s not supported for %s", __FUNCTION__, GlobalBlock.stringof));
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        return false;
    }

    override bool valid(ScriptKeyword type) const pure nothrow {
        return Lexer.isDeclaration(type) || (type is ScriptKeyword.FUNC) || (
                type is ScriptKeyword.COMMENT);
    }

    override void defineVar(ref Variable var) {
        script.defineVar(var);
    }

    override const(Variable) getVar(string var_name) const {
        return script.getVar(var_name);
    }

    override bool existVar(string var_name) const pure nothrow {
        return script.existVar(var_name);
    }
}

@safe
class FlatBlock : FunctionBlock {
    this(string func_name) {
        super(null, func_name, BlockCategory.FLAT);
    }

    override bool valid(ScriptKeyword type) const pure nothrow {
        return type !is ScriptKeyword.FUNC || (type is ScriptKeyword.COMMENT);
    }
}

@safe
class FunctionBlock : Block {
    immutable string func_name;
    protected uint _local_size;
    protected Variable[string] _local_variables;
    //    @trusted
    this(Block block, string func_name) {
        this.func_name = func_name;
        super(block, BlockCategory.FUNCTION);
    }

    private this(Block block, string func_name, BlockCategory category) {
        this.func_name = func_name;
        super(block, category);
    }

    override const(Variable[string]) localVariables() pure const nothrow {
        return _local_variables;
    }
    //  const(GlobalBlock) global;
    uint local_size() const pure nothrow {
        return _local_size;
    }

    override string funcName() const pure nothrow {
        return func_name;
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        return type is ScriptKeyword.ENDFUNC;
    }

    override bool valid(ScriptKeyword type) const pure nothrow {
        return type !is ScriptKeyword.FUNC;
    }

    override void defineVar(ref Variable var) {
        const global = getBlock(BlockCategory.GLOBAL);
        assert(global);

        

        .check(Lexer.is_name_valid(var.name),
                message("Variable name '%s' is not valid", var.name));

        

        .check(!global.existVar(var.name),
                message("Variable %s is already defined as global variable", var.name));

        

        .check((var.name in _local_variables) is null,
                message("Variable %s is redeclared", var.name));
        var.index = local_size;
        _local_variables[var.name] = var;
        _local_size++;
    }

    override const(Variable) getVar(string var_name) const {
        const global = getBlock(BlockCategory.GLOBAL);
        //immutable local_name=getLocalName(func_name, var_name);
        const local_var = _local_variables.get(var_name, null);
        if (local_var) {
            return local_var;
        }
        const var = global.getVar(var_name);

        

        .check(var !is null, message("Variable or function %s not found", var_name));
        return var;
    }

    override bool existVar(string var_name) const pure nothrow {
        const global = getBlock(BlockCategory.GLOBAL);
        return ((var_name in _local_variables) !is null) ||
            global.existVar(var_name);
    }
}

@safe
class SubBlock : Block {
    package ScriptJump[] jumps;
    //    FunctionBlock func_block;
    this(Block block, const BlockCategory category) {
        super(block, category);
    }

    override const(Variable[string]) localVariables() pure const nothrow {
        return funcBlock.localVariables;
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        assert(0, "Dont use the block");
    }

    override bool valid(ScriptKeyword type) const pure nothrow {
        return (type !is ScriptKeyword.FUNC) &&
            !Lexer.isDeclaration(type);
    }

    override void defineVar(ref Variable var) {
        funcBlock.defineVar(var);
    }

    override const(Variable) getVar(string var_name) const {
        return funcBlock.getVar(var_name);
    }

    override bool existVar(string var_name) const pure nothrow {
        return funcBlock.existVar(var_name);
    }
}

@safe
class IfBlock : SubBlock {
    //        immutable(string) func_name;
    this(Block block) {
        super(block, BlockCategory.BRANCH);
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        return ((type is ScriptKeyword.ELSE) || (type is ScriptKeyword.THEN));
    }
}

@safe
class ElseBlock : SubBlock {
    this(Block block) {
        super(block, BlockCategory.BRANCH);
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        return (type is ScriptKeyword.THEN);
    }
}

@safe
class DoLoopBlock : SubBlock {
    const Variable I;
    const Variable TO;
    immutable uint loop_level;
    this(Block block) {
        import std.stdio;

        loop_level = block.loopLevel + 1;
        const(Variable) setVar(string var_name) {
            if (!block.existVar(var_name)) {
                // Declare loop I variable as I# (# is the loop_level)
                immutable(Token) Itoken = {name: var_name};
                Variable var = new Variable(var_name, FunnelType.NUMBER);
                block.defineVar(var);
                return var;
            }
            return block.getVar(var_name);
        }

        //        wrietfln(
        //        writefln("local_size=%d", local_size);
        //        writefln("exiests=%s", block.existVar(reservedVar.I));
        I = setVar(getLoopVarName(reservedVar.I, loop_level));
        TO = setVar(getLoopVarName(reservedVar.TO, loop_level));
        //        writefln("local_size=%d", local_size);
        //        writefln("exiests=%s", block.existVar(reservedVar.I));
        super(block, BlockCategory.LOOP);
    }

    override uint loopLevel() pure const nothrow {
        return loop_level;
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        return (type is ScriptKeyword.LOOP) || (type is ScriptKeyword.ADDLOOP);
    }
}

@safe
class BeginLoopBlock : SubBlock {
    immutable uint loop_level;
    this(Block block) {
        loop_level = block.loopLevel + 1;
        super(block, BlockCategory.LOOP);
    }

    override uint loopLevel() pure const nothrow {
        return loop_level;
    }

    override bool end(ScriptKeyword type) const pure nothrow {
        return (type is ScriptKeyword.UNTIL) || (type is ScriptKeyword.REPEAT);
    }
}

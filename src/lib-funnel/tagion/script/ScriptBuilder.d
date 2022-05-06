module tagion.script.ScriptBuilder;

import std.conv;

import tagion.script.ScriptParser;
import tagion.basic.TagionExceptions : Check;
import tagion.script.ScriptBase : ScriptException, FunnelType;

import tagion.script.Script;
import tagion.script.ScriptBlocks;
import tagion.basic.Message : message;

//import std.format;
import std.string : join;

//import std.stdio;
import std.traits : hasMember, EnumMembers;
import std.uni : toUpper;
import std.range.primitives : isInputRange;
import std.regex;

@safe
class ScriptBuilderException : ScriptException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

alias check = Check!ScriptBuilderException;

ScriptBuilderT!(Range) ScriptBuilder(Range)(Range range) if (isInputRange!Range) {
    return ScriptBuilderT!(Range)(range);
}

immutable(Token) token(Range)(const Range range) {
    static if (hasMember!(Range, "line")) {
        immutable(Token) token = {name: range.front, line: range.line, pos: range.pos};
        return token;
    }
    else {
        immutable(Token) token = {name: range.front};
        return token;
    }
}

@safe
class ScriptTokenError : ScriptError {
    this(immutable(Token) token, string error, const(ScriptElement) next) {
        super(token, error);
    }

    override ScriptElement opCall(const Script s, ScriptContext sc) const {
        super.opCall(s, sc);
        throw new ScriptBuilderException(msg ~ token.toText);
        return null;
    }

    override string toText() const {
        return message("%s: Token %s", msg, token.name);
    }
}

@safe
struct ScriptBuilderT(Range) {
    static assert(isInputRange!Range, message("Range must be a InputRange not %s", Range.stringof));
    protected GlobalBlock global;
    protected Script script;

    protected Range range;
    enum HasLineInfo = hasMember!(Range, "line");

    this(Range range) {
        this.range = range;
    }

    alias BoundVariable = Script.BoundVariable;

    const(ScriptElement) build(ref Script script) {
        if (script is null) {
            script = new Script;
        }
        this.script = script;
        global = new GlobalBlock(script);
        auto global_parse = range;

        const error = collect(global_parse);
        if (error) {
            return error;
        }
        while (!range.empty) {
            const keycode = Lexer.get(range.front.toUpper);
            with (ScriptKeyword) {
                switch (keycode) {
                case FUNC:
                    funcParser(range, global);
                    break;
                case VAR:
                    range.popFront;
                    const word_code = Lexer.get(range.front.toUpper);
                    range.popFront;
                    assert(word_code is WORD, "This should be a word token");
                    break;
                case COMMENT:
                    range.popFront;
                    break;
                default:
                    import std.format;

                    assert(0, format("This token %s should not end up here",
                            range.front));
                }
            }
        }
        return null;
    }

    const(ScriptFunc) flatBuild(ref Script script, Range flat_range)
    in {
        assert(script !is null, "Flat script must have a script defined");
    }
    do {
        immutable flat_name = "::flat";
        auto flat_block = new FlatBlock(flat_name);
        immutable(Token) flat_token = {name: flat_name};
        auto flat_func = new ScriptFunc(flat_token);
        flat_func.define(funcParser(range, flat_block), flat_block);
        return flat_func;
    }

    const(ScriptElement) getVariable(
            ref Range range,
            const(Token) var_type_token,
            Block block, ref Variable var) {
        range.popFront;
        const var_token = range.token;
        immutable var_name = var_token.name.toUpper;
        if (!Lexer.is_name_valid(var_name)) {
            range.popFront;
            return new ScriptTokenError(var_token,
                    message("Invalid name '%s' for variable", var_name), collect(range));
        }
        immutable var_type = var_type_token.name.toUpper;
        with (ScriptType) {
            final switch (Lexer.getScriptType(var_type)) {
            case NONE:
                assert(0);
            case NUM:
                auto bound = var_type.match(Lexer.regex_bound);
                if (!bound.empty && bound.front[2].length !is 0) {
                    import tagion.script.ScriptBase : Number;

                    const min = Number(bound.front[2]);
                    const max = Number(bound.front[3]);
                    if (min < max) {
                        var = new BoundVariable!void(var_name, min, max);
                    }
                    else {
                        range.popFront;
                        return new ScriptTokenError(var_type_token,
                                message("Boundary violation in declaration %s", var_type), funcParser(range, block));
                    }
                }
                else {
                    var = new Variable(var_name, FunnelType.NUMBER);
                }
                break;
            case I32:
                var = new BoundVariable!int(var_name);
                break;
            case I64:
                var = new BoundVariable!long(var_name);
                break;
            case U32:
                var = new BoundVariable!uint(var_name);
                break;
            case U64:
                var = new BoundVariable!ulong(var_name);
                break;
            case STRING:
                var = new Variable(var_name, FunnelType.TEXT);
                break;
            case DOC:
                var = new Variable(var_name, FunnelType.DOCUMENT);
                break;
            case HIBON:
                var = new Variable(var_name, FunnelType.HIBON);
                break;
            }
        }
        return null;
    }

    protected const(ScriptElement) funcParser(ref Range range, Block global_block) {
        @safe
        const(ScriptElement) parse(Block block) {
            if (!range.empty) {
                immutable word = range.front.toUpper;
                immutable word_token = range.token;
                with (ScriptKeyword) {
                    immutable keycode = Lexer.get(word);
                    if (!block.valid(keycode)) {
                        range.popFront;
                        return new ScriptTokenError(word_token,
                                message("Unexpected %s in this scope", word), parse(block));
                    }
                    final switch (keycode) {
                    case NONE:
                        range.popFront;
                        return new ScriptTokenError(word_token, message("Unknown word '%s'", word), parse(
                                block));
                    case FUNC:
                        range.popFront;
                        immutable func_token = range.token;
                        range.popFront;
                        immutable func_name = func_token.name.toUpper;
                        if (!Lexer.is_name_valid(func_name)) {
                            range.popFront;
                            return new ScriptTokenError(func_token,
                                    message("Invalid function name %s", func_name), parse(block));
                        }
                        FunctionBlock func_block = new FunctionBlock(block, func_name);
                        //block=func_block;
                        const func = parse(func_block); //=blockParser(range, sub_block);
                        script.setFunc(func_name, func, func_block);
                        //                            block=block.parent;
                        return null;
                    case ENDFUNC:
                        range.popFront;
                        if (block.end(ENDFUNC)) {
                            return null;
                        }
                        return new ScriptTokenError(word_token,
                                message("End of function ';' not expected %s", word), parse(block));
                    case EXIT:
                        return null;
                    case COMMENT:
                        range.popFront;
                        return parse(block);
                    case IF:
                        range.popFront;
                        //auto parent=block;
                        auto if_block = new IfBlock(block);
                        const if_element = parse(if_block); //blockParser(range, sub_block);
                        @safe
                        const(ScriptElement) get_else() {
                            if (Lexer.get(range.front.toUpper) is ELSE) {
                                range.popFront;
                                auto else_block = new ElseBlock(block);
                                return parse(else_block); //blockParser(range, else_sub_block);
                            }
                            return null;
                        }

                        const else_element = get_else();
                        range.popFront;
                        //                            const script_NOP=new ScriptNOP(blockParser(range, block));
                        // block=parent;
                        const next = parse(block);
                        return new ScriptConditional(word_token, if_element, else_element, next);
                    case ELSE:
                        if (block.end(ELSE)) {
                            return null;
                        }
                        range.popFront;
                        return new ScriptTokenError(word_token, message("%s not extected", word), parse(
                                block));
                    case ENDIF, THEN:
                        if (block.end(THEN)) {
                            return null;
                        }
                        range.popFront;
                        return new ScriptTokenError(word_token, message("%s not extected", word), parse(
                                block));
                    case DO:
                        range.popFront;
                        auto do_block = new DoLoopBlock(block);
                        const loop_body = parse(do_block);
                        //                            immutable end_loop=range.front.toUpper;
                        immutable end_loop = range.token;
                        range.popFront;
                        const after_loop = parse(block);
                        return new ScriptDo(word_token, loop_body, after_loop, end_loop, do_block);
                    case LOOP, ADDLOOP:
                        if (block.end(keycode)) {
                            return null;
                        }
                        range.popFront;
                        return new ScriptTokenError(
                                word_token,
                                message("%s not extected missing DO to match %s", word, keycode),
                                parse(block));
                    case I:
                        if (block.loopLevel > 0) {
                            immutable(Token) Itoken = {name: block.Iname};
                            auto var = new Variable(block.Iname, FunnelType.NUMBER);
                            return new ScriptGetVar(Itoken, parse(block), var, true);
                        }
                        return new ScriptTokenError(
                                word_token,
                                message("%s can only be used inside a loop", word),
                                parse(block));
                    case BEGIN:
                        range.popFront;
                        auto begin_block = new BeginLoopBlock(block);
                        const loop_body = parse(begin_block);
                        immutable until = range.token;
                        range.popFront;
                        const after_until = parse(block);
                        return new ScriptBegin(word_token,
                                loop_body, after_until, until, begin_block);
                    case UNTIL, REPEAT:
                        if (block.end(keycode)) {
                            return null;
                        }
                        range.popFront;
                        return new ScriptTokenError(
                                word_token,
                                message("%s not extected missing begin to match %s", word, UNTIL),
                                parse(block));
                    case WHILE:
                        range.popFront;
                        if (Block category_block = block.getBlock(Block.BlockCategory.LOOP)) {
                            return new ScriptWhile(word_token, parse(block), category_block);
                        }
                        return new ScriptTokenError(
                                word_token,
                                message("%s not extected, %s must be inside a loop", word, WHILE),
                                parse(block));
                    case AGAIN:
                        range.popFront;
                        if (Block category_block = block.getBlock(Block.BlockCategory.LOOP)) {
                            return new ScriptAgain(word_token, parse(block), category_block);
                        }
                        return new ScriptTokenError(
                                word_token,
                                message("%s not extected, %s must be inside a loop", word, keycode),
                                parse(block));
                    case LEAVE:
                        range.popFront;
                        if (block.category is Block.BlockCategory.LOOP) {
                            return new ScriptLeave(word_token, parse(block), block);
                        }
                        return new ScriptTokenError(
                                word_token,
                                message("%s not extected, %s must be inside a loop", word, keycode),
                                parse(block));
                    case GET, PUT:
                        range.popFront;
                        return new ScriptTokenError(word_token,
                                message("Unexpected variable operator '%s'", word), parse(block));
                    case VAR:
                        if (block.category is Block.BlockCategory.FUNCTION) {
                            Variable var;
                            const error = getVariable(range, word_token, block, var);
                            if (error) {
                                return error;
                            }
                            if (var.name.match(Lexer.regex_reserved_var)) {
                                return new ScriptTokenError(range.token,
                                        message("Variable name %s is reserved and can not be declared", var
                                        .name),
                                        parse(block));
                            }
                            block.defineVar(var);
                            range.popFront;
                            return parse(block);
                        }
                        else {
                            return new ScriptTokenError(word_token,
                                    message("Variable declaration %s is only allowed in a global or function scope", word),
                                    parse(block));
                        }
                        break;
                    case NUMBER, HEX:
                        range.popFront;
                        return new ScriptNumber(word_token, parse(block));
                    case TEXT:
                        range.popFront;
                        return new ScriptText(word_token, parse(block));
                    case WORD:
                        range.popFront;
                        if (const(ScriptElement) element = Script.createElement(word, word_token, parse(
                                block))) {
                            return element;
                        }
                        else if (const(ScriptFunc) script_func = script.getFunc(word)) {
                            return new ScriptCall(word_token, script_func, parse(block));
                        }
                        else if (word[0] is '.') { // Dot commands
                            static foreach (dotCode; EnumMembers!Dot) {
                                if (word == dotCode) {
                                    return new ScriptDebugPrint!dotCode(word_token,
                                            parse(block), block);
                                }
                            }
                            return new ScriptTokenError(word_token,
                                    message("Invalid . command %s", word),
                                    parse(block));
                        }
                        else {
                            const(ScriptElement) varOp(const Token var_op_token, const(Variable) var, const bool local) {
                                immutable var_op_code = Lexer.get(var_op_token.name);
                                switch (var_op_code) {
                                case GET:
                                    return new ScriptGetVar(var_op_token, parse(block), var, local);
                                case PUT:
                                    switch (var_op_token.name) {
                                        static foreach (OP; ScriptPutVar.operators) {
                                    case OP:
                                            return new ScriptOpPutVar!OP(var_op_token, parse(block), var, local);
                                        }
                                    case "!":
                                        return new ScriptPutVar(var_op_token, parse(block), var, local);
                                    default:
                                        return new ScriptTokenError(var_op_token,
                                                message("Invalid put operator %s", var_op_token
                                                .name), parse(block));
                                    }
                                    break;
                                default:
                                    return new ScriptTokenError(var_op_token,
                                            message("Illegal operator %s for variable %s", var_op_token.name, word),
                                            parse(block));

                                }
                            }

                            immutable var_op_token = range.token;
                            range.popFront;
                            if (const Variable global_var = script.getVar(word)) {
                                return varOp(var_op_token, global_var, false);
                            }
                            else if (const Variable local_var = block.getVar(word)) {
                                return varOp(var_op_token, local_var, true);
                            }
                            else {
                                return new ScriptTokenError(word_token,
                                        message("Variable %s not defined", word), parse(block));
                            }
                        }
                        assert(0);
                    }
                    assert(0, message("This line should never be executed: Bad token %s ", word));
                }

            }
            return null;
        }

        //         while(!range.empty) {
        //             const
        //         }
        //         void subBlock(const ScriptElement current) {
        //             if (current) {
        //                 const next=parse;
        //                 subBlock(next);
        //                 current.__force_last(next);

        //                 //              return next;
        //             }
        // //            return null;
        //         }
        return parse(global_block);
    }

    // Collect the global variables and function declarations
    protected const(ScriptElement) collect(ref Range range) {
        while (!range.empty) {
            immutable word = range.front.toUpper;
            immutable keycode = Lexer.get(word);
            with (ScriptKeyword) {
                switch (keycode) {
                case FUNC:
                    range.popFront;
                    const func_token = range.token;
                    immutable func_name = func_token.name.toUpper;
                    if (!Lexer.is_name_valid(func_name)) {
                        range.popFront;
                        return new ScriptTokenError(func_token,
                                message("Invalid name '%s' for function", func_name), collect(range));
                    }
                    auto script_func = new ScriptFunc(func_token);
                    script.defineFunc(func_name, script_func);
                    while (!range.empty && (Lexer.get(range.front.toUpper) !is ENDFUNC)) {
                        range.popFront;
                        //writefln(">> %s", range.front);
                    }
                    if (range.empty) {
                        return new ScriptTokenError(func_token,
                                message("Function end missing for %s", func_name), null);
                    }
                    break;
                case VAR:
                    const var_type_token = range.token;
                    Variable var;
                    const error = getVariable(range, var_type_token, global, var);
                    if (error) {
                        return error;
                    }
                    global.defineVar(var);
                    break;
                case COMMENT:
                    // Ignore
                    break;
                default:
                    const illegal_token = range.token;
                    range.popFront;
                    return new ScriptTokenError(illegal_token,
                            message("Unexpected %s in global scope", illegal_token.name), collect(
                            range));
                }
            }
            range.popFront;
        }
        return null;
    }
}

version (unittest) {
    import tagion.script.ScriptBase : Number;
}

//version(none) {
unittest {
    string source = "";
    {
        auto src = ScriptParser(source);
        Script script;
        auto builder = ScriptBuilder(src[]);
        builder.build(script);
        auto sc = new ScriptContext(10, 10, 10, 100);
        auto result = script.call("undefined", sc);
        assert(result);
    }
}

unittest { // Simple function test
    string source = [
        ": test",
        "  * - ",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);

    auto sc = new ScriptContext(10, 10, 10, 100);
    sc.push(3);
    sc.push(2);
    sc.push(5);
    // sc.trace=true;

    script.call("test", sc);
    assert(sc.pop.by!(FunnelType.NUMBER) == -7);
}

unittest { // Simple function test
    string source = [
        ": test",
        "  + -",
        ";\n"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);

    {
        auto sc = new ScriptContext(10, 10, 10, 100);
        sc.push(3);
        sc.push(2);
        sc.push(5);
        //sc.trace=true;

        script.call("test", sc);

    }
}

unittest { // Simple compare operator test
    import tagion.basic.Types : Buffer;

    string source = [
        ": test",
        "  == ",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);

    {
        auto sc = new ScriptContext(10, 10, 10, 100);
        sc.push(4);
        sc.push(4);

        //sc.trace=false;
        script.call("test", sc);
        assert(sc.pop.get!bool);

        sc.push(5);
        sc.push(4);

        // sc.trace=true;
        script.call("test", sc);
        assert(!sc.pop.get!bool);
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);
        Buffer a = [1, 2, 3];
        Buffer b = [1, 2, 3];

        sc.push(a);
        sc.push(b);
        //sc.trace=false;

        script.call("test", sc);

        assert(sc.pop.get!bool);
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);
        string a = "hugo";
        string b = "borge";

        sc.push(a);
        sc.push(b);
        // sc.trace=true;

        script.call("test", sc);
        assert(!sc.pop.get!bool);
    }
}

unittest { // Number test
    string source = [
        ": test",
        "  42  ",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);
    script.call("test", sc);
    assert(sc.pop.get!Number == 42);
}

unittest { // Number test
    string source = [
        ": test",
        "  0x42  ",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);
    script.call("test", sc);
    assert(sc.pop.get!Number == 0x42);
}

unittest { // Text test
    string source = [
        ": test",
        `  "Hugo"  `,
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);
    script.call("test", sc);

    assert(sc.pop.get!string == "Hugo");
}
//}

//version(none)
unittest { // Simple if test
    string source = [
        ": test",
        "  if  ",
        "  111  ",
        "  then",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);

    {
        auto sc = new ScriptContext(10, 10, 10, 100);
        sc.push(10);
        sc.push(0); // 0 means false
        //sc.trace=true;

        script.call("test", sc);

        assert(sc.pop.get!Number == 10);

        sc.push(10);
        script.call("test", sc);

        assert(sc.pop.get!Number == 111);
    }
}
//}

//version(none)
unittest { // Simple if else test
    string source = [
        ": test_if_else",
        "  if  ",
        "    -1  ",
        "  else  ",
        "    1  ",
        "  then  ",
        `  "END" `,
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (top != 0)
        sc.push(10);
        script.call("test_if_else", sc);
        // writefln("sc.pop=%s", sc.pop);
        assert(sc.pop.get!string == "END");
        assert(sc.pop.get!Number == -1);

        // Test 'IF ELSE' false (top == 0)
        sc.push(0);
        script.call("test_if_else", sc);
        // writefln("sc.pop=%s", sc.pop);
        assert(sc.pop.get!string == "END");
        assert(sc.pop.get!Number == 1);
    }
}

unittest { // Simple if else test inside if else
    string source = [
        ": test_if_if_else",
        "  if  ",
        "    if ",
        `      "A"  `,
        "    else ",
        `      "B"  `,
        "    then",
        "  else  ",
        "    if ",
        `      "C"  `,
        "    else ",
        `      "D"  `,
        "    then",
        "  then  ",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);

    builder.build(script);

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (1 1 -- "A" "END")
        sc.push(1);
        sc.push(1);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        // assert(sc.pop.get!string == "END");
        // assert(sc.pop.get!string == "betweenAB");
        assert(sc.pop.get!string == "A");
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (0 1 -- "B" "END")
        sc.push(0);
        sc.push(1);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        // assert(sc.pop.get!string == "END");
        // assert(sc.pop.get!string == "betweenAB");
        assert(sc.pop.get!string == "B");
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (1 0 -- "C" "END")
        sc.push(1);
        sc.push(0);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        // assert(sc.pop.get!string == "END");
        // assert(sc.pop.get!string == "betweenCD");
        assert(sc.pop.get!string == "C");
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (0 0 -- "D" "END")
        sc.push(0);
        sc.push(0);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        // assert(sc.pop.get!string == "END");
        // assert(sc.pop.get!string == "betweenCD");
        assert(sc.pop.get!string == "D");
    }
}

unittest { // Simple if else test inside if else with in bewteens
    string source = [
        ": test_if_if_else",
        "  if  ",
        "    if ",
        `      "A"  `,
        "    else ",
        `      "B"  `,
        "    then",
        `   "betweenAB" `,
        "  else  ",
        "    if ",
        `      "C"  `,
        "    else ",
        `      "D"  `,
        "    then",
        `   "betweenCD" `,
        "  then  ",
        `  "END" `,
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);

    builder.build(script);

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (1 1 -- "A" "END")
        sc.push(1);
        sc.push(1);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        assert(sc.pop.get!string == "END");
        assert(sc.pop.get!string == "betweenAB");
        assert(sc.pop.get!string == "A");
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (0 1 -- "B" "END")
        sc.push(0);
        sc.push(1);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        assert(sc.pop.get!string == "END");
        assert(sc.pop.get!string == "betweenAB");
        assert(sc.pop.get!string == "B");
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (1 0 -- "C" "END")
        sc.push(1);
        sc.push(0);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        assert(sc.pop.get!string == "END");
        assert(sc.pop.get!string == "betweenCD");
        assert(sc.pop.get!string == "C");
    }

    {
        auto sc = new ScriptContext(10, 10, 10, 100);

        // Test IF ELSE true (0 0 -- "D" "END")
        sc.push(0);
        sc.push(0);
        //sc.trace=true;

        script.call("test_if_if_else", sc);

        assert(sc.pop.get!string == "END");
        assert(sc.pop.get!string == "betweenCD");
        assert(sc.pop.get!string == "D");
    }
}

//}
//version(none) {
unittest { // Global Variable ! (put)
    string source = [
        "  num Y",
        "  num X",
        ": test_put",
        "    X !", //        "    .v",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);

    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    //sc.trace=true;
    sc.push(10);
    auto error = script.execute("test_put", sc);
    assert(!error);
    // if ( error ) {
    //     writeln(error.toInfo);
    // }
    auto var = sc[script("X")];

    assert(var.get!Number == 10);
}

unittest { // Global Variable @ (get)
    string source = [
        "num X",
        ": test",
        "    X @",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    script.allocateGlobals(sc);
    sc[script("X")] = 42;

    script.call("test", sc);
    assert(sc.pop.get!Number == 42);
}

unittest { // Local Variable ! (PUT) and @ test
    string source = [
        ": test",
        "    num X",
        "    X !",
        `    "dummy" `,
        "    X @",
        "    2 * ",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    sc.push(11);
    // sc.trace=false;
    script.call("test", sc);
    assert(sc.pop.get!Number == 22);
}

unittest { // Get and put multiple global variables
    string source = [
        "  num X",
        "  num Y",
        ": test",
        "  17 X !",
        "  13 Y !",
        `  "dummy" `,
        "  X @ Y @",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    script.execute("test", sc);
    // Check Y value
    assert(sc.pop.get!Number == 13);
    assert(sc[script("Y")].get!Number == 13);

    // Check X value
    assert(sc.pop.get!Number == 17);
    assert(sc[script("X")].get!Number == 17);
}

unittest { // Get and put multiple local variables
    string source = [
        ": test",
        "  num X",
        "  num Y",
        "  13 Y !",
        "  17 X !",
        `  "dummy" `,
        "  Y @ X @",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    // sc.trace=false;
    script.call("test", sc);

    // Check X value
    assert(sc.stack_pointer is 3);
    assert(sc.pop.get!Number == 17);
    // Check Y value
    assert(sc.stack_pointer is 2);
    assert(sc.pop.get!Number == 13);
}

unittest { // None standard put operator in variables
    string source = [
        ": test",
        " num X",
        " 7 X !",
        " 3 X -!",
        " X @",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    script.call("test", sc);

    assert(sc.pop.get!Number == 4);

}

unittest { // None standard put operator where the result is pushed after
    string source = [
        ": test",
        " num X",
        " 7 X !",
        " 3 X -!@", //        " X @",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    script.call("test", sc);

    assert(sc.pop.get!Number == 4);

}

//version(none)
unittest {
    string source = [
        ": test",
        " num X",
        " num Y",
        " 7 ",
        "X ! X @ Y ! Y @",
        "X ! X @ Y ! Y @", //        " .l ",
        //        " 3 X -!@",
        //        " X @",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);
    script.call("test", sc);
    assert(sc.pop.get!Number == 7);
    //       assert(sc.pop.get!Number == 7);
    //        writefln("sc.pop=%s", sc.pop);

    //        writefln(""
}

unittest { // Call one function from another function including local variable
    string source = [
        "num G1",
        "num G2",

        ": testA",
        "  num Z",
        "  3 Z ! ", // ".l",
        "  3 ",
        "  2 ",
        "  Z @ ", //  " .s ",
        "  testB ",
        "  Z @", //   " .s .l ",
        ";",

        ": testG",
        " G1 !",
        " G2 !", // " .v",
        " testA ",
        ";",

        ": testB",
        "  num X",
        "  num Y",
        " Y !",
        " X !",
        "  X +!@",
        " Y @",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    // Put and Get variable X and Y
    // sc.trace=true;
    sc.push(3);
    sc.push(2); // X=2+3
    sc.push(3); // Y=3

    script.execute("testB", sc);
    assert(sc.pop.get!Number == 3);
    assert(sc.pop.get!Number == 5);

    script.execute("testA", sc);
    assert(sc.pop.get!Number == 3); // Z
    assert(sc.pop.get!Number == 3); // Y
    assert(sc.pop.get!Number == 5); // X

    sc.push(42); // G2
    sc.push(13); // G1
    script.execute("testG", sc);
    assert(sc[script("G1")].get!Number == 13);
    assert(sc[script("G2")].get!Number == 42);
}
//}

unittest { // DO LOOP
    string source = [
        //  "variable X",
        ": test_do_loop",
        "   num X", //        " .l .s",
        "   do ",
        "     X @ 1+ X ! ", //        " .l .s ",
        " loop ",
        " I1 @",
        " X @",

        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);
    // sc.trace=true;
    // Put and Get variable X and Y

    sc.push(10);
    sc.push(0);

    script.execute("test_do_loop", sc);
    assert(sc.pop.get!Number == 10); // X = 10
    assert(sc.pop.get!Number == 10); // I1 = 10
}

unittest { // DO +LOOP
    string source = [
        //  "variable X",
        ": test_do_+loop",
        "   num X", //        " .l ",
        "   do ",
        "     X @ 1+ X ! ", //        " .l .s ",
        " 2 ",
        " +loop ",
        " I1 @",
        " X @",
        ";"
    ].join("\n");

    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);
    //sc.trace=true;
    // Put and Get variable X and Y

    sc.push(10);
    sc.push(0);
    script.execute("test_do_+loop", sc);

    assert(sc.pop.get!Number == 5); // X = 5
    assert(sc.pop.get!Number == 10); // I1 = 10
}

unittest { // begin until
    string source = [
        //        " variable X ",
        ": test_begin_until",
        "  num X",
        "  begin",
        "    X @ 1 + X !",
        "    X @ 10 ==",
        "  until",
        "  X @",
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    script.execute("test_begin_until", sc);
    assert(sc.pop.get!Number == 10);
}

unittest { // begin while repeat
    string source = [
        ": test_begin_while_repeat",
        "  begin",
        "    dup 3 > ",
        "  while",
        "    1-", //        " .s",
        " repeat",
        ` "end" `,
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    sc.push(10);
    script.call("test_begin_while_repeat", sc);

    assert(sc.pop.get!string == "end");
    assert(sc.pop.get!Number == 3);
}

unittest { // begin if again else leave repeat
    string source = [
        ": test_begin_again_leave_repeat",
        "  10 ",
        "  begin", //    " .s",
        "    1- dup 3 ", //   " .s",
        " > ", // " .s",
        "  if ", //   "    .s",
        "    again",
        `    "Not seen" `,
        "  then",
        `  "OK" `, //    " .s ",
        "  leave ",
        `  "NotOK" `,
        " repeat",
        `  "End" `,
        ";"
    ].join("\n");
    auto src = ScriptParser(source);
    Script script;
    auto builder = ScriptBuilder(src[]);
    builder.build(script);
    auto sc = new ScriptContext(10, 10, 10, 100);

    sc.push(10);
    script.call("test_begin_again_leave_repeat", sc);

    assert(sc.pop.get!string == "End");
    assert(sc.pop.get!string == "OK");
    assert(sc.pop.get!Number == 3);
}

unittest {
    // Checks the super_script;
    string super_source = [
        "string super_global",
        ": super_test",
        `  "SUPER" `,
        "  dup super_global ! ",
        ";"
    ].join("\n");

    string source = [
        "num global",
        ": test",
        "    42 global !",
        "    super_test ",
        ";"
    ].join("\n");

    Script super_script;
    {
        auto src = ScriptParser(super_source);
        auto builder = ScriptBuilder(src[]);
        builder.build(super_script);
    }

    Script script = new Script(super_script);
    {
        auto src = ScriptParser(source);
        auto builder = ScriptBuilder(src[]);
        builder.build(script);
    }
    auto sc = new ScriptContext(10, 10, 10, 100);
    script.execute("test", sc);

    import std.stdio;

    assert(sc.pop.get!string == "SUPER");

    assert(script.num_of_globals == 2);
    assert(super_script.num_of_globals == 1);

    auto global = sc[script("global")];
    auto super_global = sc[script("super_global")];

    assert(global.get!Number == 42);
    assert(super_global.get!string == "SUPER");
}

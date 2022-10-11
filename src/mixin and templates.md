# mixin vs mixin template

## string mixin

mixin() takes a string, parses it into a AST node _(compiler's internal data structure for representing code, it stands for "abstract syntax tree")_ basically objects representing each part of the code).

```
mixin("int x = 10;");
```

Then it pastes that parsed AST node into the same slot where the mixin word appeared.

> Code in the string must be correct
> 
> The string must represent a complete element

```
int a = bmixin(c); // error
```

Once it pastes in that AST node though, the compiler treats it as if the code was all written there originally.

Any names referenced will be looked up in the pasted context.

## examples from our code

### Example 

Logger.d:321
```
mixin template Log(alias name)
{
    mixin(format(q{const bool %1$s_logger = log.env("%1$s", %1$s);}, __traits(identifier, name))); // const bool var_logger = log.env("var", var);
}
```


### Example 
HiRPC.d:248
```
...
static foreach (name; __traits(allMembers, T))
{
    ...
    enum code = format(q{alias MemberA=T.%s;}, name);
    mixin(code);
    static if (hasUDA!(MemberA, HiRPCMethod))
    {
    ...
```
Result
```
// For some primitive struct
struct Dummy
{
    int x;
    void foo();
    @HiRPCMethod void myHiPRCMethod();
}

// Something like

alias MemberA=T.x;
alias MemberA=T.foo;
alias MemberA=T.myHiRPCMethod;
```

### Example 
TaskWrapper.d:145

```
... // in loop
enum code = format!(q{alias Type=Func.%s;})(method); // alias Type=Func.methodName;
mixin(code);

static if (isCallable!Type && hasUDA!(Type, TaskMethod))
{
    enum method_code = format!q{
        alias FuncParams_%1$s=AliasSeq!%2$s;
        void %1$s(FuncParams_%1$s args) {
            send(_tid, args);
                }}(method, Parameters!(Type).stringof);
    result ~= method_code;
}
...
mixin(result);
```
Result
```
...
    alias FuncParams_receiveLogs=AliasSeq!(immutable(LogFilter), immutable(Document));
    void receiveLogs(FuncParams_receiveLogs args) {
        send(_tid, args);
            }

    alias FuncParams_receiveFilters=AliasSeq!(LogFilterArray, LogFiltersAction);
    void receiveFilters(FuncParams_receiveFilters args) {
        send(_tid, args);
            }
...
```

## template mixin

Template mixin has a container element in the AST, which is used for name lookups.

It actually works similarly to a struct or class inside the compiler - they all have a list of child declarations that remain together as a unit.

> Template mixin's contents are automatically accessible from the parent context... usually.
> 
> It follows rules similar to class inheritance, where `class B : A` and B can see A's members as if they are its own, but they still remain separate.
> 
> You can still do like super.method(); and call it independently of the child's overrides.

The "usually" comes in because of overloading and hijacking rules.

```
mixin template B(T) {
   void foo(T t) {}
}
class A {
   mixin B!int;    // works fine
   mixin B!string; // works fine
}
```

```
mixin template B(T) {
   void foo(T t) {}
}
class A {
   mixin B!int;
   mixin B!string; // when called "Error: function A.foo(float t) is not callable using argument types (string)"

   void foo(float t) {}
}
```

Compiler still treats them as a unit, not just a pasted set of declarations. Any name present on the outer object - here, our class A - will be used instead of looking inside the template mixin.

The solution is to add an alias line to the top-level to tell the compiler to specifically look inside. First, we need to give the mixin a name, then forward the name explicitly:

```
mixin template B(T) {
   void foo(T t) {}
}
class A {
   mixin B!int bint; // added a name here
   mixin B!string bstring; // and here

   alias foo = bint.foo; // forward foo to the template mixin
   alias foo = bstring.foo; // and this one too

   void foo(float t) {}
}
```

Rules of overloading:

> By default functions can only overload against other functions in the same module
> 
> If a name is found in more than one scope, in order to use it, it must be fully qualified
> 
> In order to overload functions from multiple modules together, an alias statement is used to merge the overloads

## examples from our code

### Example 

Logger.d:321
```
mixin template Log(alias name)
{
    mixin(format(q{const bool %1$s_logger = log.env("%1$s", %1$s);}, __traits(identifier, name))); // const bool var_logger = log.env("var", var);
}
```
Usage
```
const test_variable = S(10);
mixin Log!test_variable;
```

### Example 

TaskWrapper.d:223
```
@safe mixin template TaskBasic()
{
    bool stop;

    void onSTOP()
    {
        stop = true;
    }

    void onLIVE()
    {
    }

    void onEND()
    {
    }

    @TaskMethod void control(immutable(Control) control)
    {
        with (Control)
        {
            final switch (control)
            {
            case STOP:
                onSTOP;
                break;
            case LIVE:
                onLIVE;
                break;
            case END:
                onEND;
                break;
            }
        }
    }
}
```
Usage
LoggerService.d
```
@safe struct LoggerTask
{
    mixin TaskBasic;
    ...

    void onSTOP()
    {
        stop = true;
        file.writefln("%s stopped ", options.logger.task_name);

        if (abort)
        {
            log.silent = true;
        }
    }
    ...
```

### Example 

```
mixin template HiBONRecord(string CTOR = "")
{
    ...
}
```
Usage
```
@safe struct LogFilter
{
    @Label("task") string task_name;
    @Label("level") LogLevel level;
    @Label("symbol") string symbol_name;

    mixin HiBONRecord!(q{
        this(string task_name, LogLevel level) nothrow {
            this.task_name = task_name;
            this.level = level;
            this.symbol_name = "";
        }

        this(string task_name, string symbol_name) nothrow {
            this.task_name = task_name;
            this.level = LogLevel.ALL;
            this.symbol_name = symbol_name;
        }
    });
```
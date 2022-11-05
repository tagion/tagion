module tagion.tools.Basic;

mixin template Main(alias _main, string name = null) {
    import std.traits : fullyQualifiedName;

    version (ONETOOL) {
        enum alternative_name = name;
        enum main_name = fullyQualifiedName!_main;
    }
    else {
        int main(string[] args) {
            return _main(args);
        }
    }
}

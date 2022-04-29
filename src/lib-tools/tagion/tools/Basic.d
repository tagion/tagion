module tagion.tools.Basic;

mixin template Main(alias _main,string name=null) {
    version(TAGION_TOOLS) {
    }
    else {
        enum alternative=name;
        int main(string[] args) {
            return _main(args);
        }
    }
}

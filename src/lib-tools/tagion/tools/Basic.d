module tagion.tools.Basic;

mixin template Main(alias _main,string name=null) {
    version(TAGION_TOOLS) {
        enum alternative_name=name;
    }
    else {
        int main(string[] args) {
            return _main(args);
        }
    }
}

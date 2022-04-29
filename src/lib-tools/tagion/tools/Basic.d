module tagion.tools.Basic;

mixin template Main(alias _main) {
    version(TAGION_TOOLS) {
    }
    else {
        int main(string[] args) {
            return _main(args);
        }
    }
}

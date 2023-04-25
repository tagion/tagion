import std.stdio;
import tagion.dart.DARTFile;
import tagion.dart.DARTFakeNet;

void main() {
    auto net = new DARTFakeNet;
    const filename_A = "tmp.drt";
    DARTFile.create(filename_A);
    auto dart_A = new DARTFile(net, filename_A);
}

module tagion.dart.bill_test;

import std.range;
import std.random : MinstdRand0, randomSample;
import tagion.script.TagionCurrency;
import tagion.crypto.SecureNet: StdSecureNet;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.Recorder;
import tagion.basic.basic;
import std.stdio;
import tagion.dart.DARTFile;
import std.algorithm;
import tagion.utils.Miscellaneous : toHex = toHexString;
import tagion.script.common : TagionBill;
import tagion.crypto.Types : Pubkey;
import tagion.basic.Types : Buffer;
import tagion.hibon.Document;

unittest {
    immutable filename_A = fileId!DARTFile("randomA").fullpath;
    filename_A.forceRemove;


    HashNet net = new StdHashNet;
    DARTFile.create(filename_A, net);
    auto dart_A = new DARTFile(net, filename_A);
    scope(exit) {
        dart_A.close;
    }
    
    auto factory = RecordFactory(net);
    // create lots of bills
    
    TagionBill createBill() {
        // writeln("CREATING BILL");
        import tagion.crypto.random.random;
        import tagion.utils.StdTime;
        auto nonce = new ubyte[4];
        getRandom(nonce);
        return TagionBill(100.TGN, currentTime(), Pubkey([1,2,3,4]), nonce.idup); 
    }
    
    auto rnd = MinstdRand0(42);

    // start by adding 1000 bills
    TagionBill[] bills = iota(0,100).map!(n => createBill()).array;
    writeln("before insert to recorder");
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    dart_A.modify(recorder);

    writeln("AFTER INSERT");
    foreach(i; 0..100) {
        // remove 5 random bills already in the dart.
        // take 5 new random bills and add them to the existiing array.

        auto _recorder = factory.recorder;

        auto bills_to_remove = bills.randomSample(5, rnd).array;
        auto bills_to_add = iota(0,10).map!(n => createBill).array;
        // add the bills to add to the bills array
        bills ~= bills_to_add;

        // add them to the recorder
        _recorder.insert(bills_to_add, Archive.Type.ADD);
        _recorder.insert(bills_to_remove, Archive.Type.REMOVE);

        // modify the dart
        auto bullseye = dart_A.modify(_recorder);
        // writeln(bullseye.toHex);
    }
}
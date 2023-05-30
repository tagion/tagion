module models.benefitShare;

import tagion.hibon.HiBONRecord;

@recordType("BenefitShare")
struct BenefitShare {
    string benefitShareUUID; // System UUID - "df51e3a0-d48a-41a7-8960-8534e154e5e6"
    int benefitShareId; // Public ID - 1
    string benefitUUID; // System UUID - "dd02c019-1050-421a-955f-afa28c6423f8"
    int benefitShareNumber; // 1
    string benefitShareLocationSizeUnit; // "Hectar"
    int benefitShareLocationSizeUnitCount; // 1
    string benefitSharePriceCurrency; // "DKK"
    int benefitSharePrice; // 1

    mixin HiBONRecord;
}

version (unittest) struct TestStruct {
    import tagion.hibon.HiBONRecord;

    string name;
    mixin HiBONRecord!(q{
        this(const(string) _name) {
            name = _name;
        }
    });
}

unittest {
    import tagion.dart.DARTFile;
    import tagion.dart.DARTFakeNet;
    import tagion.dart.Recorder;
    import tagion.hibon.HiBON;
    import tagion.hibon.HiBONRecord;

    auto net = new DARTFakeNet;
    RecordFactory.Recorder recorder;

    const filename = "/tmp/dartA.drt";
    DARTFile.create(filename);
    auto dart_A = new DARTFile(net, filename);
    recorder = dart_A.recorder();

    auto test_archive = TestStruct("somestring");
    recorder.add(test_archive);
    auto bullseye = dart_A.modify(recorder);

    assert(bullseye == net.calcHash(test_archive.toDoc));
}

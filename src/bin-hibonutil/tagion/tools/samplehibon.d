module tagion.tools.samplehibon;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON;
import tagion.utils.StdTime;


static Document sampleHiBON(const bool hibon_array = false, sdt_t timestamp = currentTime) pure {
    import std.datetime;
    import std.typecons;
    import tagion.hibon.BigNumber;

    auto list = tuple!(
            "BIGINT",
            "BOOLEAN",
            "FLOAT32",
            "FLOAT64",
            "INT32",
            "INT64",
            "UINT32",
            "UINT64")(
            BigNumber("-1234_1234_4678_4678_9876_8438_2345_1111"),
            true,
            float(0x1.3ae148p+0),
            double(0x1.9b5d96fe285c6p+664),
            int(-42),
            long(-1234_1234_4678_4678),
            uint(42),
            ulong(1234_1234_4678_4678),
    );

    auto h = new HiBON;
    foreach (i, value; list) {
        if (hibon_array) {
            h[i] = value;
        }
        else {
            h[list.fieldNames[i]] = value;
        }
    }
    immutable(ubyte)[] buf = [1, 2, 3, 4];
    auto sub_list = tuple!(
            "BINARY",
            "STRING",
            "TIME")(
            buf,
            "Text",
            timestamp
    );
    auto sub_hibon = new HiBON;
    foreach (i, value; sub_list) {
        if (hibon_array) {
            sub_hibon[i] = value;
        }
        else {
            sub_hibon[sub_list.fieldNames[i]] = value;
        }
    }
    if (hibon_array) {
        h[list.length] = sub_hibon;
    }
    else {
        h["sub_hibon"] = sub_hibon;
    }

    return Document(h.serialize);

}


unittest {
    import tagion.hibon.HiBONFile;
    import tagion.basic.testbasic;

    static immutable filename = unitfile("samplehibon.hibon");

    const read_doc = fread(filename);

    const gen_doc = sampleHiBON(false, sdt_t(1123));

    fwrite(filename, gen_doc);
    assert(read_doc == gen_doc, "Document generation changed!");

}

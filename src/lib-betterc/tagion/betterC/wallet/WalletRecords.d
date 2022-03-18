module tagion.betterC.wallet.WalletRecords;

// import tagion.betterC.hibon.HiBONRecord;
import tagion.betterC.hibon.HiBON : HiBONT;
import tagion.betterC.hibon.Document : Document;
import tagion.betterC.wallet.KeyRecover : KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey;

// import tagion.script.TagionCurrency;
// import tagion.script.StandardRecords : StandardBill;

struct RecordType {
    string name;
    string code; // This is is mixed after the Document constructor
}

struct Label {
    string name; /// Name of the HiBON member
    bool optional; /// This flag is set to true if this paramer is optional
}

@trusted {
    import std.algorithm;
    import std.array;

    @RecordType("Quiz")
    struct Quiz {
        @Label("$Q") string[] questions;
        this(Document doc) {
            auto mydata = doc["$Q"].get!Document;
            // questions = mydata[]
            //     .map!(a => a.get!string)
            //     .array.dup;
        }
    }
    /++

+/
    @RecordType("PIN")
    struct DevicePIN {
        Buffer Y;
        Buffer check;

        // mixin HiBONRecord;
    }

    @RecordType("Wallet")
    struct RecoverGenerator {
        Buffer[] Y; /// Recorvery seed
        Buffer S; /// Check value S=H(H(R))
        @Label("N") uint confidence;
        import tagion.betterC.hibon.HiBON;

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            // hibon["Y"] = Y;
            hibon["S"] = S;
            hibon["N"] = confidence;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            auto doc = Document(toHiBON.serialize);
            return cast(const) doc;
        }

        this(Document doc) {
            auto Y_data = doc["Y"].get!Document;
            // Y = Y_data[]
            //     .map!(a => a.get!Buffer)
            //     .array.dup;
            S = doc["S"].get!Buffer;
            confidence = doc["N"].get!uint;
        }
        // mixin HiBONRecord;
    }

}

module tagion.betterC.wallet.WalletRecords;

import tagion.basic.Types : Buffer;
import tagion.basic.basic : basename;
import tagion.betterC.hibon.Document : Document;
import tagion.betterC.hibon.HiBON;
import tagion.betterC.utils.BinBuffer;
import tagion.betterC.utils.Memory;
import tagion.betterC.wallet.KeyRecover : KeyRecover;
import tagion.crypto.Types : Pubkey, Signature;

// import std.format;
import core.stdc.string : memcpy;
import std.conv : emplace;
import std.range.primitives : isInputRange;
import std.traits : ForeachType, ReturnType, Unqual, hasMember, isArray, isAssociativeArray, isIntegral, isUnsigned;
import std.typecons : Tuple, TypedefType;
import tagion.betterC.funnel.TagionCurrency;

// import tagion.script.StandardRecords : StandardBill;

template isSpecialKeyType(T) {
    import std.traits : KeyType, isAssociativeArray, isUnsigned;

    static if (isAssociativeArray!T) {
        alias KeyT = KeyType!T;
        enum isSpecialKeyType = !(isUnsigned!KeyT) && !is(KeyT : string);
    }
    else {
        enum isSpecialKeyType = false;
    }
}

static R toList(R)(const Document doc) {
    alias MemberU = ForeachType!(R);
    alias BaseU = TypedefType!MemberU;
    static if (isArray!R) {
        alias UnqualU = Unqual!MemberU;
        UnqualU[] result;
        result.length = doc.length;
        enum do_foreach = true;
    }
    else static if (isSpecialKeyType!R) {
        R result;
        enum do_foreach = true;
    }
    else static if (isAssociativeArray!R) {
        R result;
        enum do_foreach = true;
    }
    else {
        return R(doc);
        enum do_foreach = false;
    }
    static if (do_foreach) {
        foreach (elm; doc[]) {
            static if (isSpecialKeyType!R) {
                const value_doc = elm.get!Document;
                alias KeyT = KeyType!R;
                alias BaseKeyT = TypedefType!KeyT;
                static if (Document.Value.hasType!BaseKeyT || is(BaseKeyT == enum)) {
                    const key = KeyT(value_doc[0].get!BaseKeyT);
                }
                else {
                    auto key = KeyT(value_doc[0].get!BaseKeyT);
                }
                const e = value_doc[1];
            }
            else {
                const e = elm;
            }
            static if (Document.Value.hasType!MemberU || is(BaseU == enum)) {
                auto value = e.get!BaseU;
            }
            else static if (Document.Value.hasType!BaseU) {
                // Special case for Typedef
                auto value = MemberU(e.get!BaseU);
            }
            else {
                const sub_doc = e.get!Document;
                static if (is(BaseU == struct)) {
                    auto value = BaseU(sub_doc);
                }
                else {
                    auto value = toList!BaseU(sub_doc);
                }
                // else {
                //     static assert(0,
                //             format("Can not convert %s to Document", R.stringof));
                // }
            }
            static if (isAssociativeArray!R) {
                static if (isSpecialKeyType!R) {
                    result[key] = value;
                }
                else {
                    result[e.key] = value;
                }
            }
            else {
                result[e.index] = value;
            }
        }
    }
    return cast(immutable) result;
}

struct RecordType {
    string name;
    string code; // This is is mixed after the Document constructor
}

struct Label {
    string name; /// Name of the HiBON member
    bool optional; /// This flag is set to true if this parameter is optional
}

enum VOID = "*";

template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;

    static if (hasUDA!(member, Label)) {
        enum label = getUDAs!(member, Label)[0];
        static if (label.name == VOID) {
            enum GetLabel = Label(basename!(member), label.optional);
        }
        else {
            enum GetLabel = label;
        }
    }
    else {
        enum GetLabel = Label(basename!(member));
    }
}

@trusted {
    import std.algorithm;
    import std.array;

    @RecordType("Quiz")
    struct Quiz {
        @Label("$Q") string[] questions;
        this(Document doc) {
            auto received_questions = doc["$Q"].get!Document;
            questions.create(received_questions.length);
            foreach (element; received_questions[]) {
                questions[element.index] = element.get!string;
            }
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            auto tmp_arr = HiBON();
            foreach (i, question; questions) {
                tmp_arr[i] = question;
            }
            // GetLabel
            hibon["$Q"] = tmp_arr;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    @RecordType("PIN")
    struct DevicePIN {
        Buffer D; /// Device number
        Buffer U; /// Device random
        Buffer S; /// Check sum value
        void recover(ref scope ubyte[] R, scope const(ubyte[]) P) const {
            import tagion.betterC.utils.Miscellaneous : xor;

            xor(R, D, P);
        }

        this(Document doc) {
            enum number_name = GetLabel!(D).name;
            enum random_name = GetLabel!(U).name;
            enum sum_name = GetLabel!(S).name;

            D = doc[number_name].get!Buffer;
            U = doc[random_name].get!Buffer;
            S = doc[sum_name].get!Buffer;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            enum number_name = GetLabel!(D).name;
            enum random_name = GetLabel!(U).name;
            enum sum_name = GetLabel!(S).name;

            hibon[number_name] = D;
            hibon[random_name] = U;
            hibon[sum_name] = S;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    @RecordType("Wallet")
    struct RecoverGenerator {
        Buffer[] Y; /// Recorvery seed
        Buffer S; /// Check value S=H(H(R))
        @Label("N") uint confidence;
        import tagion.betterC.hibon.HiBON;

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            auto tmp_arr = HiBON();
            foreach (i, y; Y) {
                tmp_arr[i] = y;
            }
            tmp_arr["S"] = S;
            tmp_arr["N"] = confidence;
            hibon = tmp_arr;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }

        this(Document doc) {
            auto Y_data = doc["Y"].get!Document;
            Y.create(Y_data.length);
            foreach (element; Y_data[]) {
                Y[element.index] = element.get!Buffer;
            }
            S = doc["S"].get!Buffer;
            confidence = doc["N"].get!uint;
        }
    }

    struct AccountDetails {
        // @Label("$derives") Buffer[Pubkey] derives;
        @Label("$derives") Document derives;
        @Label("$bills") StandardBill[] bills;
        @Label("$state") Buffer derive_state;
        // boll[Pubkey]
        @Label("$active") Document activated; /// Activated bills
        import std.algorithm : any, each, filter, map, sum;

        this(Document doc) {
            enum derives_name = GetLabel!(derives).name;
            enum bills_name = GetLabel!(bills).name;
            enum ds_name = GetLabel!(derive_state).name;
            enum active_name = GetLabel!(activated).name;

            auto received_der = doc[derives_name].get!Document;
            // auto list = toList!Buffer[Pubkey](received_der);
            auto received_bills = doc[bills_name].get!Document;
            bills.create(received_bills.length);
            foreach (element; received_bills[]) {
                enum value_name = GetLabel!(StandardBill.value).name;
                bills[element.index].value = TagionCurrency(
                        received_bills[value_name].get!Document);
                bills[element.index].epoch = element.get!uint;
                // bills[element.index].owner = element;
                bills[element.index].gene = element.get!Buffer;
            }
            derive_state = doc[ds_name].get!Buffer;
            activated = doc[active_name].get!Document;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            enum derives_name = GetLabel!(derives).name;
            enum bills_name = GetLabel!(bills).name;
            enum ds_name = GetLabel!(derive_state).name;
            enum active_name = GetLabel!(activated).name;

            hibon[derives_name] = derives;
            // auto tmp_hibon = HiBON();
            // foreach(i, bill; bills) {
            //     tmp_hibon[i] = bill;
            // }
            // hibon[bills_name] = tmp_hibon;
            hibon[ds_name] = derive_state;
            hibon[active_name] = activated;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }

        bool remove_bill(Pubkey pk) {
            import std.algorithm : countUntil, remove;

            const index = countUntil!"a.owner == b"(bills, pk);
            if (index > 0) {
                bills = bills.remove(index);
                return true;
            }
            return false;
        }

        void add_bill(StandardBill bill) {
            bills.resize(bills.length + 1);
            bills[$ - 1] = bill;
        }

        /++
         Clear up the Account
         Remove used bills
         +/
        void clearup() pure {
            // bills
            //     .filter!(b => b.owner in derives)
            //     .each!(b => derives.remove(b.owner));
            // bills
            //     .filter!(b => b.owner in activated)
            //     .each!(b => activated.remove(b.owner));
        }

        const {
            /++
         Returns:
         true if the all transaction has been registered as processed
         +/
            bool processed() {
                bool res = false;
                foreach (bill; bills) {
                    foreach (active; activated[]) {
                        const active_data = active.get!Document;
                        if (active_data[0].get!Buffer == bill.owner) {

                        }
                        // const key = tmp[0].get!Buffer;
                        // const value = tmp[1].get!bool;
                    }
                    // auto tmp = toList(activated)
                    // if (bill.owner in activated) {
                    //     res = true;
                    // }
                }
                return res;
            }
            /++
         Returns:
         The available balance
         +/
            TagionCurrency available() {
                long result;
                foreach (bill; bills) {
                    foreach (active; activated[]) {
                        const active_data = active.get!Document;
                        if (active_data[0].get!Buffer == bill.owner) {
                            result += active_data[1].get!uint;
                        }
                    }
                }
                return TagionCurrency(result);
            }
            /++
        //  Returns:
        //  The total active amount
        //  +/
            TagionCurrency active() {
                long result;
                foreach (bill; bills) {
                    foreach (active; activated[]) {
                        const active_data = active.get!Document;
                        if (active_data[0].get!Buffer == bill.owner) {
                            result += active_data[1].get!uint;
                        }
                    }
                }
                return TagionCurrency(result);
            }
            //     /++
            //  Returns:
            //  The total balance including the active bills
            //  +/
            // TagionCurrency total() {
            //     return bills
            //         .map!(b => b.value)
            //         .sum;
            // }
        }
    }

    @RecordType("BIL") struct StandardBill {
        @Label("$V") TagionCurrency value; // Bill type
        @Label("$k") uint epoch; // Epoch number
        //        @Label("$T", true) string bill_type; // Bill type
        @Label("$Y") Pubkey owner; // Double hashed owner key
        @Label("$G") Buffer gene; // Bill gene
        this(Document doc) {
            // value = doc["Y"].get!Document;
            epoch = doc["k"].get!uint;
            Buffer tmp_buf = doc["Y"].get!Buffer;
            Pubkey pkey;
            pkey = tmp_buf;
            // memcpy_wrapper(owner, pkey);
            gene = doc["G"].get!Buffer;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            // hibon["V"] = value;
            hibon["k"] = epoch;
            // hibon["Y"] = owner;
            hibon["G"] = gene;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    @RecordType("Invoice") struct Invoice {
        string name;
        TagionCurrency amount;
        Pubkey pkey;
        @Label("*", true) Document info;
        this(Document doc) {
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    @RecordType("SMC") struct Contract {
        @Label("$in") Buffer[] input; /// Hash pointer to input (DART)
        @Label("$read", true) Buffer[] read; /// Hash pointer to read-only input (DART)
        @Label("$out") Document[Pubkey] output; // pubkey of the output
        @Label("$run") Script script; // TVM-links / Wasm binary
        bool verify() {
            return (input.length > 0);
        }
    }

    @RecordType("SSC") struct SignedContract {
        @Label("$signs") immutable(ubyte)[] signs; /// Signature of all inputs
        @Label("$contract") Contract contract; /// The contract must signed by all inputs
        @Label("$in", true) Document input; /// The actual inputs
        this(Document doc) {
            enum sign_name = GetLabel!(signs).name;
            // enum contract_name = GetLabel!(contract).name;
            enum input_name = GetLabel!(input).name;

            auto received_sign = doc[sign_name].get!Buffer;
            signs.create(received_sign.length);
            signs = received_sign;

            // contract = doc[contract_name].get!Contract;
            input = doc[input_name].get!Document;

        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }

    struct Script {
        @Label("$name") string name;
        @Label("$env", true) Buffer link; // Hash pointer to smart contract object;
        // mixin HiBONRecord!(
        //         q{
        //         this(string name, Buffer link=null) {
        //             this.name = name;
        //             this.link = link;
        //         }
        //     });
        // bool verify() {
        //     return (wasm.length is 0) ^ (link.empty);
        // }

    }
}

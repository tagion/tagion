module tagion.script.ScriptingObjects;

import tagion.utils.BSON;
import tagion.Base : basename;
import tagion.hashgraph.Net : StdSecureNet;
import tagion.hashgraph.GossipNet : RequestNet, SecureNet;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.Hash : toHexString;
import std.exception;

alias uint EpochNumber;
alias long TimeStamp;

@safe
class ObjectsException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias enforce!ObjectsException objEnforce;

/*
    The document contains data structurs, serialization and de-serialization for objects used for transactions.
    The ScriptingEngineObject is an internal data structure, which is sent to the sscripting engine. It is a TransactionObject with the fetched Bills included.
    Data structure for Transaction Object:
    TransactionObject {
        TransactionScriptingObject {
            Payer[] {
                BillNumber,
                PublicKey
            },

            Payee[] {
                Hash(OwnerPublicKey)
            },
            Parameter[] {

            },

            Script {

            }

        },

        Signatures[] {
            Signatur of TransactionObject
        }
    }

    ScriptingEngineObject {
        TransactionObject,
        Bills[] {
            BillBody {
                BillNumber,
                Value,
                Owner,
                EpochTimeStamp,
                EpochNumber,
                BillType,
            }
        }
    }

*/

enum BillType {
    Non_Usable,
    Tagions,
    Contracts
}


/*
    Required fields shuld be listed from the top and down.
    Enum indicating how many of the fields are required per default.
    Other rules can well be implemented, e.g. if Contracts type, then contractId is required as well.
*/
enum bill_body_required_fields_count = 5;

@safe
struct BillBody {

    immutable uint value=-1;
    immutable(ubyte[]) owner_key; //Hash of pub. key
    immutable EpochNumber epoch_number=-1;
    immutable TimeStamp epoch_time_stamp;
    immutable BillType bill_type;
    immutable(ubyte[]) contract_id; //Hash of the contract

    this(immutable uint value,
        immutable ubyte[] owner_key,
        immutable EpochNumber epoch_number,
        immutable TimeStamp epoch_time_stamp,
        immutable BillType bill_type ) inout {
        this.value = value;
        this.owner_key = owner_key;
        this.epoch_number = epoch_number;
        this.epoch_time_stamp = epoch_time_stamp;
        this.bill_type = bill_type;

        validateData();
    }

    this(immutable(ubyte[]) data) inout {
        auto doc=Document(data);
        this(doc);
    }

    this(Document doc) inout {
        foreach(i, ref m; this.tupleof) {
            alias type=typeof(m);
            enum name=basename!(this.tupleof[i]);
            if ( doc.hasElement(name) ) {
                static if ( is(type : immutable(ubyte[])) ) {
                    this.tupleof[i]=(doc[name].get!type).idup;
                }
                else static if (is(type == enum)) {
                    this.tupleof[i]=cast(type)doc[name].get!uint;
                }
                else {
                    this.tupleof[i]=doc[name].get!type;
                }
            }
            else if(i < bill_body_required_fields_count) {
                throw new ObjectsException("Required field \""~name~"\" not in document");
            }
        }
        validateData();
    }

    void validateData() inout {
        objEnforce(this.value>=0, "value cannot be less then zero");
        objEnforce(this.owner_key !is null && owner_key.length == 32, "owner_key not in right format.");
        objEnforce(this.epoch_number>=0, "Epoch number needs to be larger than zero");
        objEnforce(this.epoch_time_stamp != 0, "Epoch timestamp cannot be zero");
        objEnforce(this.bill_type != BillType.Non_Usable, "bill_type not correct");
        if(this.bill_type == BillType.Contracts) {
            objEnforce(this.contract_id !is null && contract_id.length == 32, "contract_id not in right format.");
        }
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                  bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    bson[name]=m;
                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}

struct Bill {
    immutable BillBody bill_body;
    immutable ubyte[] bill_number;


    this(immutable BillBody bill_body, RequestNet net) inout {
        this.bill_body = bill_body;
        this.bill_number = net.calcHash(bill_body.serialize);
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    bson[name]=m;

                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }

}

struct Payer {
    immutable(ubyte[]) bill_number;
    immutable(ubyte[]) pubkey; //without underscore to align with keywords

    this(immutable(ubyte[]) bill_number, immutable(ubyte[]) pub_key) inout {
        this.bill_number = bill_number;
        this.pubkey = pub_key;
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    bson[name]=m;

                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}

struct Payee {
    immutable(ubyte[]) owner_key;

    this(immutable(ubyte[]) owner_key) inout {
        this.owner_key = owner_key;
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    bson[name]=m;

                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}


struct TransactionScriptingObject {
    immutable(Payer[]) payers;
    immutable(Payee[]) payees;

    this(ref immutable(Payer[]) payers, ref immutable(Payee[]) payee) inout {
        this.payers = payers;
        this.payees = payees;
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            alias type = typeof(m);
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    static if( is(type : const Payer[]) || is(type : const Payee[])) {
                        HBSON[] res;
                        foreach(elm; m) {
                            res~=elm.toBSON;
                        }
                        bson[name]=res;
                    }
                    else {
                        bson[name]=m;

                    }
                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}

struct Signatur {
    immutable(ubyte[]) signatur;

    this(immutable(ubyte[]) signatur) inout {
        this.signatur = signatur;
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                        bson[name]=m;

                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}
import std.stdio : writeln;
struct TransactionObject {
    immutable TransactionScriptingObject transaction_scripting_obj;
    immutable(Signatur[]) signatures;

    this(ref immutable(Signatur[]) signatures, ref immutable(TransactionScriptingObject) transaction_scripting_obj) inout {
        this.transaction_scripting_obj = transaction_scripting_obj;
        this.signatures = signatures;
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            alias type = typeof(m);
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    static if( is(type : const Signatur[])) {
                        HBSON[] res;
                        foreach(elm; m) {
                            res~=elm.toBSON;
                        }
                        bson[name]=res;
                    }
                    else {
                        bson[name]=m;

                    }
                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}

//Internal use

struct ScriptingEngineObject {
    //We need an BSON asign operator for Document[], therefore BSON[] instead of Document[]
    immutable(HBSON[]) bills;
    immutable Document transaction_obj;

    this (immutable(HBSON[]) bills, immutable(ubyte[]) transaction_obj) immutable {
        this.bills = bills;
        this.transaction_obj = Document(transaction_obj);
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            alias type = typeof(m);
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                     static if( is(type : const HBSON[])) {
                        HBSON[] res;
                        foreach(elm; m) {
                            res~=cast(HBSON)elm;
                        }
                        bson[name]=res;
                    }
                    else {
                        bson[name]=m;
                    }


                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize() const {
        return toBSON().serialize;
    }
}


@safe
class TestNet : StdSecureNet {
    import tagion.hashgraph.HashGraph;
    override void request(HashGraph hashgraph, immutable(ubyte[]) fingerprint) {
        assert(0, "Not implement for this test");
    }
    this(NativeSecp256k1 crypt) {
        super(crypt);
    }
}

unittest {
    auto test_net = new TestNet(new NativeSecp256k1);
    auto bill_body = immutable BillBody (
        10,
        test_net.calcHash([1,2,3,4]),
        110,
        15050505050,
        BillType.Tagions
    );

    assert(bill_body.value == 10, "Value not correct");
    assert(bill_body.owner_key.toHexString == "9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a", "owner_key not correct");
    assert(bill_body.epoch_number == 110, "Epoch number not correct");
    assert(bill_body.epoch_time_stamp == 15050505050, "time_stamp not correct");
    assert(bill_body.bill_type == BillType.Tagions, "bill_type not correct");

    immutable b_bill_body_bin = bill_body.serialize;
    auto b_body_doc = Document(b_bill_body_bin);

    assert(b_body_doc["value"].get!uint == 10, "value not correct in bill body doc");
    assert(b_body_doc["owner_key"].get!(immutable(ubyte[])).toHexString == "9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a", "owner_key not correct in bill body doc");
    assert(b_body_doc["epoch_number"].get!uint == 110, "epoch_number not correct in bill body doc");
    assert(b_body_doc["epoch_time_stamp"].get!long == 15050505050, "epoch_time_stamp not correct in bill body doc");
    assert(b_body_doc["bill_type"].get!int == BillType.Tagions, "bill_type not correct in bill body doc");

    auto bill = immutable Bill(bill_body, test_net);

    assert(bill.bill_body == bill_body, "Body not pointing to same object.");
    assert(bill.bill_number.toHexString == "3978a5c70529be532477ad89802c4530a1d24d02c9dbc4bb56619b8c0a40bfff", "bill_number not correct for bill");

    //Test des. data has integrity as objects
    auto des_bill_body_data = immutable BillBody(b_bill_body_bin);
    auto des_bill_body_doc = immutable BillBody(b_body_doc);

    assert(bill.bill_number == test_net.calcHash(des_bill_body_data.serialize), "des. data does not the same as serialized data.");
    assert(bill.bill_number == test_net.calcHash(des_bill_body_doc.serialize), "des. doc does not the same as serialized data.");

    auto bill_doc_bin = bill.serialize;
    auto bill_doc = Document(bill_doc_bin);
    assert(bill_doc["bill_number"].get!(immutable(ubyte[])).toHexString == "3978a5c70529be532477ad89802c4530a1d24d02c9dbc4bb56619b8c0a40bfff" , "bill_number not correct for bson bill" );
    assert(bill_doc.hasElement("bill_body"), "bill_body not in the bill");
    assert(bill_doc["bill_body"].isDocument, "bill_body is not bson document");
    auto bill_doc_body_doc = bill_doc["bill_body"].get!Document;

    assert(bill_doc_body_doc["value"].get!uint == 10, "value not correct in bill doc body doc");
    assert(bill_doc_body_doc["owner_key"].get!(immutable(ubyte[])).toHexString == "9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a", "owner_key not correct in bill doc body doc");
    assert(bill_doc_body_doc["epoch_number"].get!uint == 110, "epoch_number not correct in bill doc body doc");
    assert(bill_doc_body_doc["epoch_time_stamp"].get!long == 15050505050, "epoch_time_stamp not correct in bill doc body doc");
    assert(bill_doc_body_doc["bill_type"].get!int == BillType.Tagions, "bill_type not correct in bill doc body doc");

}
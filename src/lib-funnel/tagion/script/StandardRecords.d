module tagion.script.StandardRecords;

import std.meta : AliasSeq;

import tagion.basic.Types : Buffer, Pubkey, Signature;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONType;
import tagion.hibon.HiBONException;
import std.range : empty;
import tagion.script.TagionCurrency;
import tagion.script.ScriptException : check;

enum OwnerKey = "$Y";

@safe {
    @recordType("BIL") struct StandardBill {
        @label("$V") TagionCurrency value; // Bill type
        @label("$k") uint epoch; // Epoch number
        @label(OwnerKey) Pubkey owner; // Double hashed owner key
        @label("$G") Buffer gene; // Bill gene
        version (OLD_TRANSACTION) {
            mixin HiBONType!(
                    q{
                this(TagionCurrency value, const uint epoch, Pubkey owner, Buffer gene) {
                    this.value = value;
                    this.epoch = epoch;
                    this.owner = owner;
                    this.gene = gene;
                }
            });
        }
        else {
            mixin HiBONType;
        }
    }

    @recordType("NNC") struct NetworkNameCard {
        @label("#name") string name; /// Tagion domain name
        @label(OwnerKey) Pubkey pubkey; /// NNC pubkey
        @label("$lang") string lang; /// Language used for the #name
        @label("$time") ulong time; /// Time-stamp of
        @label("$record") Buffer record; /// Hash pointer to NRC
        mixin HiBONType;

        import tagion.crypto.SecureInterfaceNet : HashNet;

        static Buffer dartHash(const(HashNet) net, string name) {
            NetworkNameCard nnc;
            nnc.name = name;
            return net.hashOf(nnc);
        }
    }

    @recordType("NRC") struct NetworkNameRecord {
        @label("$name") Buffer name; /// Hash of the NNC.name
        @label("$prev") Buffer previous; /// Hash pointer to the previuos NRC
        @label("$index") uint index; /// Current index previous.index+1
        @label("$node") Buffer node; /// Hash pointer to NNR
        @label("$payload", true) Document payload; /// Hash pointer to payload
        mixin HiBONType;
    }

    @recordType("HL") struct HashLock {
        import tagion.crypto.SecureInterfaceNet;

        @label("$lock") Buffer lock; /// Of the NNC with the pubkey
        mixin HiBONType!(q{
                @disable this();
                import tagion.crypto.SecureInterfaceNet : HashNet;
                import tagion.script.ScriptException : check;
                import tagion.hibon.HiBONType : isHiBONType, hasHashKey;
                this(const(HashNet) net, const(Document) doc) {
                    check(doc.hasHashKey, "Document should have a hash key");
                    lock = net.rawCalcHash(doc.serialize);
                }
                this(T)(const(HashNet) net, ref const(T) h) if (isHiBONType!T) {
                    this(net, h.toDoc);
                }
            });

        bool verify(const(HashNet) net, const(Document) doc) const {
            return lock == net.rawCalcHash(doc.serialize);
        }

        bool verify(T)(const(HashNet) net, ref T h) const if (isHiBONType!T) {
            return verify(net, h.toDoc);
        }

    }

    unittest {
        import tagion.crypto.SecureNet : StdHashNet;
        import tagion.script.ScriptException : ScriptException;
        import std.exception : assertThrown, assertNotThrown;
        import std.string : representation;

        const net = new StdHashNet;
        NetworkNameCard nnc;
        {
            import tagion.crypto.SecureNet : StdSecureNet;

            auto good_net = new StdSecureNet;
            good_net.generateKeyPair("very secret correct password");
            nnc.name = "some_name";
            nnc.pubkey = good_net.pubkey;
        }
        NetworkNameCard bad_nnc;
        bad_nnc.name = "some_other_name";
        static struct NoHash {
            string name;
            mixin HiBONType!(q{
                    this(string name) {
                        this.name = name;
                    }
                });
        }
        // Invalid HR
        const nohash = NoHash("no hash");
        //        const x=HashLock(net, nohash);
        assertThrown(HashLock(net, nohash));
        // Correct HR
        const hr = assertNotThrown(HashLock(net, nnc));

        { // Verify that the NNC has been signed correctly
            // Bad NNC
            assert(!hr.verify(net, bad_nnc));
            // Good NNC
            assert(hr.verify(net, nnc));
        }

    }

    version (none) @recordType("NNR") struct NetworkNodeRecord {
        enum State {
            PROSPECT,
            STANDBY,
            ACTIVE,
            STERILE
        }

        //        @label("#node") Buffer node; /// Hash point of the public key
        @label("$name") Buffer name; /// Hash pointer to the
        @label("$time") ulong time;
        @label("$sign") uint sign; /// Signature of
        @label("$state") State state;
        @label("$gene") Buffer gene;
        @label("$addr") string address;
        mixin HiBONType;
    }

    @recordType("active0") struct ActiveNode {
        @label("$node") Buffer node; /// Pointer to the NNC
        @label("$drive") Buffer drive; /// The tweak of the used key
        @label("$sign") Buffer signed; /// Signed bulleye of the DART
        mixin HiBONType;

    }

    @recordType("$epoch0") struct EpochBlock {
        @label("$epoch") int epoch; /// Epoch number
        @label("$prev") Buffer previous; /// Hashpoint to the previous epoch block
        @label("$recorder") Buffer recoder; /// Fingerprint of the recorder
        @label("$global") Buffer global; /// Gloal nerwork paremeters
        @label("$actives") ActiveNode[] actives; /// List of active nodes Sorted by the $node
        mixin HiBONType;
    }

    enum EPOCH_TOP_NAME = "tagion";

    @recordType("top") struct LastEpochRecord {
        @label("#name") string name;
        @label("$top") Buffer top;
        mixin HiBONType!(q{
                @disable this();
                import tagion.crypto.SecureInterfaceNet : HashNet;
                this(const(HashNet) net, ref const(EpochBlock) block) {
                    name = EPOCH_TOP_NAME;
                    top = net.hashOf(block);
                }
            });

        static Buffer dartHash(const(HashNet) net) {
            EpochBlock b;
            auto record = LastEpochRecord(net, b);
            return net.hashOf(record);
        }
    }

    struct Globals {
        @label("$fee") TagionCurrency fixed_fees; /// Fixed fees per Transcation
        @label("$mem") TagionCurrency storage_fee; /// Fees per byte
        TagionCurrency fees() pure const {
            return fixed_fees;
        }

        mixin HiBONType;
    }

    @recordType("$master0") struct MasterGlobals {
        //    @label("$total") Number total;    /// Total tagions in the network
        @label("$rewards") ulong rewards; /// Epoch rewards
        mixin HiBONType;
    }

    @recordType("SMC") struct Contract {
        @label("$in") Buffer[] inputs; /// Hash pointer to input (DART)
        @label("$read", true) Buffer[] reads; /// Hash pointer to read-only input (DART)
        version (OLD_TRANSACTION) {
            @label("$out") Document[Pubkey] output; // pubkey of the output
            @label("$run") Script script; // TVM-links / Wasm binary
        }
        else {
            @label("$out") Pubkey[] output; // pubkey of the output

        }
        mixin HiBONType;
        bool verify() {
            return (inputs.length > 0);
        }
    }

    @recordType("PAY") struct PayContract {
        @label("$bills", true) StandardBill[] bills; /// The actual inputs
        mixin HiBONType;
    }

    @recordType("SSC") struct SignedContract {
        @label("$signs") Signature[] signs; /// Signature of all inputs
        @label("$contract") Contract contract; /// The contract must signed by all inputs
        version (OLD_TRANSACTION) {
            pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);
            @label("$in", true) StandardBill[] inputs; /// The actual inputs
        }
        mixin HiBONType;
    }

    /**
     * \struct HealthcheckParams
     * Struct store paramentrs for healthcheck request
     */
    @recordType("Healthcheck") struct HealthcheckParams {
        /** amount of hashgraph rounds */
        @label("$hashgraph_rounds") ulong rounds;
        /**last epoch timestamp */
        @label("epoch_timestamp") long epoch_timestamp;
        /** amount of transactions in last epoch */
        @label("$transactions_amount") uint transactions_amount;
        /** number of current epoch */
        @label("$epoch_number") uint epoch_num;
        /** check we not in last round */
        @label("$in_graph") bool in_graph;
        mixin HiBONType!(
                q{
                this(ulong rounds, long epoch_timestamp, uint transactions_amount, uint epoch_num, bool in_graph) {
                    this.rounds = rounds;
                    this.epoch_timestamp = epoch_timestamp;
                    this.transactions_amount = transactions_amount;
                    this.epoch_num = epoch_num;
                    this.in_graph = in_graph;
                }
            });
    }

    version (OLD_TRANSACTION) {
        struct Script {
            @label("$name", true) string name;
            @label("$env", true) Buffer link; // Hash pointer to smart contract object;
            mixin HiBONType!(
                    q{
                this(string name, Buffer link=null) {
                    this.name = name;
                    this.link = link;
                }
            });
            bool verify() {
                return (name.empty) ^ (link.empty);
            }

        }
    }

    alias ListOfRecords = AliasSeq!(
            StandardBill,
            NetworkNameCard,
            NetworkNameRecord, // NetworkNodeRecord,
            Contract,
            SignedContract
    );

    @recordType("Invoice") struct Invoice {
        string name;
        TagionCurrency amount;
        @label(OwnerKey) Pubkey pkey;
        @label("*", true) Document info;
        mixin HiBONType;
    }

    struct AccountDetails {
        @label("$derives") Buffer[Pubkey] derives;
        @label("$bills") StandardBill[] bills;
        @label("$state") Buffer derive_state;
        @label("$active") bool[Pubkey] activated; /// Actived bills
        import std.algorithm : map, sum, filter, any, each;

        bool remove_bill(Pubkey pk) {
            import std.algorithm : remove, countUntil;

            const index = countUntil!"a.owner == b"(bills, pk);
            if (index > 0) {
                bills = bills.remove(index);
                return true;
            }
            return false;
        }

        void add_bill(StandardBill bill) {
            bills ~= bill;
        }

        /++
         Clear up the Account
         Remove used bills
         +/
        void clearup() pure {
            bills
                .filter!(b => b.owner in derives)
                .each!(b => derives.remove(b.owner));
            bills
                .filter!(b => b.owner in activated)
                .each!(b => activated.remove(b.owner));
        }

        const pure {
            /++
         Returns:
         true if the all transaction has been registered as processed
         +/
            bool processed() nothrow {
                return bills
                    .any!(b => (b.owner in activated));
            }
            /++
         Returns:
         The available balance
         +/
            TagionCurrency available() {
                return bills
                    .filter!(b => !(b.owner in activated))
                    .map!(b => b.value)
                    .sum;
            }
            /++
         Returns:
         The total active amount
         +/
            TagionCurrency active() {
                return bills
                    .filter!(b => b.owner in activated)
                    .map!(b => b.value)
                    .sum;
            }
            /++
         Returns:
         The total balance including the active bills
         +/
            TagionCurrency total() {
                return bills
                    .map!(b => b.value)
                    .sum;
            }
        }
        mixin HiBONType;
    }
}

static Globals globals;

static this() {
    globals.fixed_fees = 1.TGN / 10; // Fixed fee
    globals.storage_fee = 1.TGN / 200; // Fee per stored byte
}

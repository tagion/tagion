module tagion.script.StandardRecords;

import std.meta : AliasSeq;

import tagion.basic.Types : Buffer, Pubkey, Signature;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONException;

//import tagion.script.ScriptBase : Number;
import tagion.script.TagionCurrency;
import tagion.script.ScriptException : check;

enum OwnerKey = "$Y";

@safe
{
    @RecordType("BIL") struct StandardBill
    {
        @Label("$V") TagionCurrency value; // Bill type
        @Label("$k") uint epoch; // Epoch number
        //        @Label("$T", true) string bill_type; // Bill type
        @Label(OwnerKey) Pubkey owner; // Double hashed owner key
        @Label("$G") Buffer gene; // Bill gene
        mixin HiBONRecord!(
            q{
                this(TagionCurrency value, const uint epoch, Pubkey owner, Buffer gene) {
                    this.value = value;
                    this.epoch = epoch;
                    this.owner = owner;
                    this.gene = gene;
                }
            });
    }

    @RecordType("NNC") struct NetworkNameCard
    {
        @Label("#name") string name; /// Tagion domain name
        @Label(OwnerKey) Pubkey pubkey; /// NNC pubkey
        @Label("$lang") string lang; /// Language used for the #name
        @Label("$time") ulong time; /// Time-stamp of
        // @Label("$sign") Buffer sign;    ///
        @Label("$record") Buffer record; /// Hash pointer to NRC
        mixin HiBONRecord;

        import tagion.crypto.SecureInterfaceNet : HashNet;

        static Buffer dartHash(const(HashNet) net, string name)
        {
            NetworkNameCard nnc;
            nnc.name = name;
            return net.hashOf(nnc);
        }
    }

    @RecordType("NRC") struct NetworkNameRecord
    {
        @Label("$name") Buffer name; /// Hash of the NNC.name
        @Label("$prev") Buffer previous; /// Hash pointer to the previuos NRC
        @Label("$index") uint index; /// Current index previous.index+1
        @Label("$node") Buffer node; /// Hash pointer to NNR
        @Label("$payload", true) Document payload; /// Hash pointer to payload
        mixin HiBONRecord;
    }

    @RecordType("HL") struct HashLock
    {
        import tagion.crypto.SecureInterfaceNet;

        @Label("$lock") Buffer lock; /// Of the NNC with the pubkey
        mixin HiBONRecord!(q{
                @disable this();
                import tagion.crypto.SecureInterfaceNet : HashNet;
                import tagion.script.ScriptException : check;
                import tagion.hibon.HiBONRecord : isHiBONRecord, hasHashKey;
                this(const(HashNet) net, const(Document) doc) {
                    check(doc.hasHashKey, "Document should have a hash key");
                    lock = net.rawCalcHash(doc.serialize);
                }
                this(T)(const(HashNet) net, ref const(T) h) if (isHiBONRecord!T) {
                    this(net, h.toDoc);
                }
            });

        bool verify(const(HashNet) net, const(Document) doc) const
        {
            return lock == net.rawCalcHash(doc.serialize);
        }

        bool verify(T)(const(HashNet) net, ref T h) const if (isHiBONRecord!T)
        {
            return verify(net, h.toDoc);
        }

    }

    unittest
    {
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
        static struct NoHash
        {
            string name;
            mixin HiBONRecord!(q{
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

    version (none) @RecordType("NNR") struct NetworkNodeRecord
    {
        enum State
        {
            PROSPECT,
            STANDBY,
            ACTIVE,
            STERILE
        }

        //        @Label("#node") Buffer node; /// Hash point of the public key
        @Label("$name") Buffer name; /// Hash pointer to the
        @Label("$time") ulong time;
        @Label("$sign") uint sign; /// Signature of
        @Label("$state") State state;
        @Label("$gene") Buffer gene;
        @Label("$addr") string address;
        mixin HiBONRecord;
    }

    @RecordType("active0") struct ActiveNode
    {
        @Label("$node") Buffer node; /// Pointer to the NNC
        @Label("$drive") Buffer drive; /// The tweak of the used key
        @Label("$sign") Buffer signed; /// Signed bulleye of the DART
        mixin HiBONRecord;

    }

    @RecordType("$epoch0") struct EpochBlock
    {
        @Label("$epoch") int epoch; /// Epoch number
        @Label("$prev") Buffer previous; /// Hashpoint to the previous epoch block
        @Label("$recorder") Buffer recoder; /// Fingerprint of the recorder
        @Label("$global") Buffer global; /// Gloal nerwork paremeters
        @Label("$actives") ActiveNode[] actives; /// List of active nodes Sorted by the $node
        mixin HiBONRecord;
    }

    enum EPOCH_TOP_NAME = "tagion";

    @RecordType("top") struct LastEpochRecord
    {
        @Label("#name") string name;
        @Label("$top") Buffer top;
        mixin HiBONRecord!(q{
                @disable this();
                import tagion.crypto.SecureInterfaceNet : HashNet;
                this(const(HashNet) net, ref const(EpochBlock) block) {
                    name = EPOCH_TOP_NAME;
                    top = net.hashOf(block);
                }
            });

        static Buffer dartHash(const(HashNet) net)
        {
            EpochBlock b;
            auto record = LastEpochRecord(net, b);
            return net.hashOf(record);
        }
    }

    struct Globals
    {
        @Label("$fee") TagionCurrency fixed_fees; /// Fixed fees per Transcation
        @Label("$mem") TagionCurrency storage_fee; /// Fees per byte
        TagionCurrency fees(const TagionCurrency topay, const size_t size) pure const
        {
            return fixed_fees + size * storage_fee;
        }

        mixin HiBONRecord;
    }

    @RecordType("$master0") struct MasterGlobals
    {
        //    @Label("$total") Number total;    /// Total tagions in the network
        @Label("$rewards") ulong rewards; /// Epoch rewards
        mixin HiBONRecord;
    }

    @RecordType("SMC") struct Contract
    {
        @Label("$in") Buffer[] inputs; /// Hash pointer to input (DART)
        @Label("$read", true) Buffer[] reads; /// Hash pointer to read-only input (DART)
        @Label("$out") Document[Pubkey] output; // pubkey of the output
        @Label("$run") Script script; // TVM-links / Wasm binary
        mixin HiBONRecord;
        bool verify()
        {
            return (inputs.length > 0) &&
                (output.length > 0);
        }
    }

    @RecordType("PAY") struct PayContract
    {
        @Label("$bills", true) StandardBill[] bills; /// The actual inputs
        mixin HiBONRecord;
    }

    @RecordType("SSC") struct SignedContract
    {
        @Label("$signs") Signature[] signs; /// Signature of all inputs
        @Label("$contract") Contract contract; /// The contract must signed by all inputs
        version (OLD_TRANSACTION)
        {
            pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);
            @Label("$in", true) Document inputs; /// The actual inputs
        }
        mixin HiBONRecord;
    }

    /**
     * \struct HealthParams
     * Struct store paramentrs for healthcheck request
     */
    @RecordType("HEALTH") struct HealthParams
    {
        /** amount of hashgraph rounds */
        @Label("$hashgraph_rounds") ulong rounds;
        /** time since the beginning of the epoch */
        @Label("$epoch_timestamp") ulong epoch_timestamp;
        /** amount of transactions in this epoch */
        @Label("$transactions_amount") uint transactions_amount;
        /** number of current epoch */
        @Label("$epoch_number") uint epoch_num;
        /** check we not in last round */
        @Label("$in_graph") bool in_graph;
        mixin HiBONRecord!(
            q{
                this(ulong rounds, ulong epoch_timestamp, uint transactions_amount, uint epoch_num, bool in_graph) {
                    this.rounds = rounds;
                    this.epoch_timestamp = epoch_timestamp;
                    this.transactions_amount = transactions_amount;
                    this.epoch_num = epoch_num;
                    this.in_graph = in_graph;
                }
            });
    }

    struct Script
    {
        @Label("$name") string name;
        @Label("$env", true) Buffer link; // Hash pointer to smart contract object;
        mixin HiBONRecord!(
            q{
                this(string name, Buffer link=null) {
                    this.name = name;
                    this.link = link;
                }
            });
        // bool verify() {
        //     return (wasm.length is 0) ^ (link.empty);
        // }

    }

    alias ListOfRecords = AliasSeq!(
        StandardBill,
        NetworkNameCard,
        NetworkNameRecord, // NetworkNodeRecord,
        Contract,
        SignedContract
    );

    @RecordType("Invoice") struct Invoice
    {
        string name;
        TagionCurrency amount;
        @Label(OwnerKey) Pubkey pkey;
        @Label("*", true) Document info;
        mixin HiBONRecord;
    }

    struct AccountDetails
    {
        @Label("$derives") Buffer[Pubkey] derives;
        @Label("$bills") StandardBill[] bills;
        @Label("$state") Buffer derive_state;
        @Label("$active") bool[Pubkey] activated; /// Actived bills
        import std.algorithm : map, sum, filter, any, each;

        bool remove_bill(Pubkey pk)
        {
            import std.algorithm : remove, countUntil;

            const index = countUntil!"a.owner == b"(bills, pk);
            if (index > 0)
            {
                bills = bills.remove(index);
                return true;
            }
            return false;
        }

        void add_bill(StandardBill bill)
        {
            bills ~= bill;
        }

        /++
         Clear up the Account
         Remove used bills
         +/
        void clearup() pure
        {
            bills
                .filter!(b => b.owner in derives)
                .each!(b => derives.remove(b.owner));
            bills
                .filter!(b => b.owner in activated)
                .each!(b => activated.remove(b.owner));
        }

        const pure
        {
            /++
         Returns:
         true if the all transaction has been registered as processed
         +/
            bool processed() nothrow
            {
                return bills
                    .any!(b => (b.owner in activated));
            }
            /++
         Returns:
         The available balance
         +/
            TagionCurrency available()
            {
                return bills
                    .filter!(b => !(b.owner in activated))
                    .map!(b => b.value)
                    .sum;
            }
            /++
         Returns:
         The total active amount
         +/
            TagionCurrency active()
            {
                return bills
                    .filter!(b => b.owner in activated)
                    .map!(b => b.value)
                    .sum;
            }
            /++
         Returns:
         The total balance including the active bills
         +/
            TagionCurrency total()
            {
                return bills
                    .map!(b => b.value)
                    .sum;
            }
        }
        mixin HiBONRecord;
    }
}

static Globals globals;

static this()
{
    globals.fixed_fees = 50.TGN; // Fixed fee
    globals.storage_fee = 1.TGN / 200; // Fee per stored byte
}

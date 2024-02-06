module tagion.replicator.RecorderBlock;

import std.array;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.Types : Fingerprint;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.HiBONRecord : GetLabel, HiBONRecord, exclude, label, recordType;

@recordType("RCB")
@safe struct RecorderBlock {
    /** Fingerprint of this block */
    @exclude Fingerprint fingerprint;
    /** Bullseye of DART database */
    @label("eye") Fingerprint bullseye;
    /** Epoch number */
    @label("epoch_number") long epoch_number;
    /** Fingerprint of the previous block */
    @label("previous") Fingerprint previous;
    /** Recorder with database changes of this block */
    @label("recorder") Document recorder_doc;

    /** Ctor creates block from recorder, previous hash and bullseye.
     *      @param recorder_doc - Document with recorder for block
     *      @param previous - fingerprint of the previous block
     *      @param bullseye - bullseye of database
     *      @param net - hash net
     */
    mixin HiBONRecord!(
            q{
        this(
            Document recorder_doc,
            Fingerprint previous,
            Fingerprint bullseye,
            long epoch_number,
            const(HashNet) net) 
        {
            this.recorder_doc = recorder_doc;
            this.previous = previous;
            this.bullseye = bullseye;
            this.epoch_number = epoch_number;

            this.fingerprint = net.calcHash(toDoc);
        }

        this(
            const(Document) doc,
            const(HashNet) net) 
        {
            this(doc);
            this.fingerprint = net.calcHash(toDoc);
        }
    });
}

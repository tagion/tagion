module tagion.script.common;

import tagion.script.TagionCurrency;
import tagion.utils.StdTime;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.hibon.HiBONRecord;

enum OwnerKey = "$Y";

@safe
@recordType("TGN") struct TagionBill {
    @label("$V") TagionCurrency value; // Bill type
    @label("$t") sdt_t time; // Epoch number
    @label(OwnerKey) Pubkey owner; // Double hashed owner key
    mixin HiBONRecord!(
            q{
                this(TagionCurrency value, const sdt_t time, Pubkey owner, Buffer gene) {
                    this.value = value;
                    this.time = time;
                    this.owner = owner;
                }
            });
}

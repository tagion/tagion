module source.models.unicef;

import tagion.hibon.HiBONRecord;
import tagion.crypto.Types;
import tagion.basic.Types;
import tagion.script.prior.StandardRecords;
import tagion.utils.StdTime;
import tagion.script.TagionCurrency;

@recordType("DeliveryOrder")
struct DeliveryOrder {
    string vaccineType; // Vaccine Type - "Measels"
    string packageID; // Package id - "1234ABC"
    int numberOfVaccines; // Number of vaccines - 20
    string destination; // Final destination - "Livingstone"
    string pickuppoint; // Pickup point location - "copenhagen"
    TagionCurrency payment; // Payment - "20usd"

    sdt_t startTime; // standard time
    sdt_t endTime; // end time - should be delivered before this point    
    sdt_t timeStamp; // When the delivery order was created
     
    @label(OwnerKey) Pubkey originalOwner; // the owner of the delivery order
    Pubkey receiver; // The receiver of the vaccines
    mixin HiBONRecord;
}

@recordType("SignedDeliveryOrder")
struct SignedDeliveryOrder {
    Signature deliveryOrderChain; // signature ex. from unicef
    Buffer deliveryOrder;
    sdt_t timeStamp;
    @label(OwnerKey) Pubkey tokenOwner; // owner of the vaccines
    
    mixin HiBONRecord;
}


// @recordType("ShippingNote")
// struct ShippingNote {
//     @label(OwnerKey) Pubkey owner; // Supplier public key
//     PubKey receiverPubKey; // Receivers public key
//     int timeStamp; // When the note was created
//     string refDeliveryOrder; // hash referencing to the delivery order
    
//     mixin HiBONRecord;
// }

// @recordType("SignedShippingNote")
// struct SignedShippingNote {
//     Signature shippingNoteSupplierSig; // signature of the receiver
//     Signature 
//     ShippingNote shippingNote;

//     mixin HiBONRecord;
// }

// @recordType("DeliveryReceipt")
// struct DeliveryReceipt {
//     PubKey receiverPubKey; // Receivers public key
//     int timeStamp; // When the note was created
//     string refDeliveryOrder; // hash referencing to the delivery order
//     string refShippingNote; // hash referencing to the shipping note

//     Signature receiverSig; // Supplier signature
//     mixin HiBONRecord;
// }
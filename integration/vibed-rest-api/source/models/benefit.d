module source.models.benefit;

import tagion.hibon.HiBONRecord;

@recordType("Benefit")
struct Benefit {
    string benefitUuid; // System UUID - "dd02c019-1050-421a-955f-afa28c6423f8"
    string projectUuid; // System UUID - "e98fc703-9334-46d1-93c9-5675656c050f"
    int benefitId; // Public ID - 1
    string benefitType; // "Reforestation" / "Afforestation"
    string benefitDescription; // "Reforestation of 1"
    string benefitLocationSizeUnit; // "Hectar"
    int benefitLocationSizeUnitCount; // 10
    int benefitPrice; // 125
    string benefitPriceCurrency; // "DKK"
    int benefitSharesTotalAmount; // 15
    mixin HiBONRecord;
}

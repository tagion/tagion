module source.models.benefitShareCredit;

import tagion.hibon.HiBONRecord;

@recordType("BenefitShareCredit")
struct BenefitShareCredit {
    string benefitShareCreditUUID; // System UUID - "0de6c792-f3ca-49a3-89a7-892117383956"
    int benefitShareCreditId; // Public ID - 1
    string benefitShareUUID; // System UUID - "df51e3a0-d48a-41a7-8960-8534e154e5e6"
    string benefitShareCreditType; // "CarbonCredit"
    string benefitShareCreditUnit; // "Hectar"
    int benefitShareCreditUnitProductionCount; // 2
    int benefitShareCreditUnitProductionYear; // 2023

    mixin HiBONRecord;
}

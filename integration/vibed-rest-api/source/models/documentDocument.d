module source.models.documentDocument;
import tagion.hibon.HiBONRecord;

@recordType("DocumentDocument")
struct DocumentDocument {
    string documentUUID; // System UUID - "1aa84542-c1b5-4fd6-8354-7dbcfe3d16d0"
    int documentId; // License public ID - 1
    string documentFileType; // "doc" / "pdf"
    string documentBinary; // "aswsftrs123casd=="
    string documentTitle; // "Test.doc"
    int documentSizeKb; // 123456
    string documentUploadTime; // "29-03-2023 16:51:42"
    string documentUploadAdminUserUUID; // "ca5a0c33-febe-49ca-84d9-e27fbf2f3d16"
    string supplierUUID; // "24afdb9f-49c5-4784-b2f2-2b4f135f5d5f"
    string projectUUID; // "e98fc703-9334-46d1-93c9-5675656c050f"
    string investorUUID; // "16f0654e-f18d-48cd-bfc0-55e5979f3d00"

    mixin HiBONRecord;
}

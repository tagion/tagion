module source.models.projectDocument;
import tagion.hibon.HiBONRecord;

@recordType("ProjectDocument")
struct ProjectDocument {
    string projectDocumentUUID; // "e5ba99a7-f0ed-444f-ac43-07064aa1df80"
    string documentUUID; // "1aa84542-c1b5-4fd6-8354-7dbcfe3d16d0"
    string projectDocumentType; // "Information" / "Contract"
    string projectDocumentAuthor; // "Rambøl"
    string projectUUID; // "e98fc703-9334-46d1-93c9-5675656c050f"

    mixin HiBONRecord;
}

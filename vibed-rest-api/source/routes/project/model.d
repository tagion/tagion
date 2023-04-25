module routes.project.model;

struct Project {
    string projectUUID; // SystemId UUID - "e98fc703-9334-46d1-93c9-5675656c050f"
    int projectId; // Public ID - 1
    string supplierUUID; // SystemId UUID - "cffe947a-0add-41a5-a59e-4f35fe18cb3b"
    string projectTitle; // "Title 1"
    string projectDescription; // "Title 1 Description of project"
    string[] projectTags; // ["CO2", "H2O"]
    string projectGeolocation; // Coordinates - "123.3256.212 321.2445.256"
    string projectUnitType; // "Hectar" / "square km"
    int projectUnitCount; // 117,8
    string projectState; // "Draft" / "Pending" / "Active" / "Inactive"
    string projectStartDate; // "01-01-2023"
    string projectStartTime; // Time CET - "12:25:53"
    string projectEndDate; // "24-12-2024" || null
    string projectEndTime; // Time CET - "17:25:43" || null
}

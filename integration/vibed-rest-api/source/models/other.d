module models.other;

import vibe.data.json;

struct ResponseModel {
    bool isSucceeded;
    Json data;
}

struct ErrorResponse {
    int errorCode;
    string errorDescription;
}

enum ErrorCode {
    dataIdnotValid = 11,
    dataNotFound = 12,
    dataNotCorrectType = 13,
    dataBodyNoMatch = 21,
    dataFingerprintNotAdded = 22,
    dataFingerprintNotFound = 31,
}

enum ErrorDescription {
    dataIdnotValid = "Provided fingerprint is not valid",
    dataNotFound = "Archive with fingerprint not found in database",
    dataNotCorrectType = "Wrong document type",
    dataBodyNoMatch = "Request body does not match",
    dataFingerprintNotAdded = "Entity with fingerprint not added to DART",
    dataFingerprintNotFound = "Entity with fingerprint not found",
}

enum Route {
    project = "project",
    benefit_share_credit = "benefit-share-credit",
    benefit_share = "benefit-share",
    project_document = "project-document",
    document = "document",
    benefit = "benefit",
    delivery_order = "delivery_order",
    signed_delivery_order = "signed_delivery_order",
}

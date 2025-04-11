Feature ReplicatorService

Scenario produced recorders are sent for replication and writen to files.
Given a list of generated recorders.
When each generated recorder is sent using the SendRecorder method.
Then they are received and each is written to a new replicator file.

Scenario we receive a recorder from file by a specified epoch number.
Given the recorder stored in a file.
Given a EpochParam struct with an epoch number.
When we send the document with the epoch number.
Then we receive a recorder related to this epoch number.
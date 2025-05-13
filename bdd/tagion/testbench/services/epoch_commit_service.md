Feature Epoch Commit Service

Check that the epoch commit service forwards all the correct request from the transcript

Scenario send mock data to epoch commit

Given an epoch commit service a mock trt, dart and replicator

When #we Send mock transcript data to the epoch_commit service

Then the mock trt, transcript and dart should receive the mock data

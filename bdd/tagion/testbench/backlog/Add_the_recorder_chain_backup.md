Feature: Recorder chain backup
Provide ability to backup database, using chain of recorders

Scenario: backup empty database with recorder chain
Case, when initial database in empty

Given: empty database

Given: expected database bullseye

Given: valid recorder chain

When: perform backup functionality

Then: restored database bullseye is same as expected bullseye


Scenario: backup database with recorder chain
Case, when provided database is not empty

Given: expected database bullseye

Given: valid recorder chain

Given: database epoch number

When: perform backup functionality

Then: restored database bullseye is same as bullseye of last recorderder in chain
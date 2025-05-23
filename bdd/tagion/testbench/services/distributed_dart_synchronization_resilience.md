Feature: check if distributed dart synchronization is resilient.
Scenario is to pass broken adresses to the distributed dart synchronization process.
Given an empty local database.
Given multiple remote nodes with broken addresses mixed up with correct ones.
When we run the synchronization.
Then we check that local database is synchronized.
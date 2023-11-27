Feature: TRT Service test
Scenario: send a inoice using the TRT
Given i have a running network with a trt
When i create and send a invoice
When i update my wallet using the pubkey lookup 
Then the transaction should go through

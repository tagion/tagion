## Feature: Connection remote to the logger service.
Takes care of the communication between the logger client and the logger service.


### Scenario: Connecting the logger client to logger service

​    *Given* the logger client is started
​      *And* the client is connected to the logger service

​    *When* the client is connected success fully.

​    *Then* send credential request to the logger.

​      *And* then check that the credential has been verified.


### Scenario: Rejection of the logger client.

  *Given* the logger client is started(2)
      *And* the client is connected to the logger service(2)

​    *When* the client is connected success fully(2)

​    *Then* send bad credential request to the logger.(2)

​      *And* then check that the credential has been rejected.(2)
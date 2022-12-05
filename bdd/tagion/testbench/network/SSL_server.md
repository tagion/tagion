Feature: SSL server

This test setup an multi-client SSL server


Scenario: creates a SSL certificate 

Given the domain information of a SSL certificate  

When the certificate has been created 

Then check that the SSL certificate is valid


Scenario SSL service using a specified certificate

Given certificate are available open a server

When the server has respond to a number of request 
The server must listen to a number of clients and respond back to the client

Then close the server







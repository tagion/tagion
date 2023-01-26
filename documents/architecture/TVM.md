# TVM (Tagion Virtual Machine)

The TVM is a service that is reponsible for ensuring complaint contracts in the network by executing the instructions and ensuring they follow the consensus rules. It produces output archieves for the database. 

Input: 

    - A Signed Contract with Input Data, DART archives.
    - Sender: Collector Service.

Output:

    - A Signed Consensus Contract that is compliant with Consensus Rules.
    - Receiver: Consensus Service.

    - The input and output DART archives.
    - Receiver: Transcript Service.

The service does the following:

    - Loads the Consensus Rules (only Tagion to start with).
    - Loads the input data.
    - Execute the instruction(s).
        - Ensures the intructions are valid.
        - Ensures the intructions follow the Consensus Rules.
    - Send the Signed Consensus Contract to the network without data.
    - Send output data and input data to Transcript Service.
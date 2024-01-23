# Public hirpc methods

These are the hirpc methods exposed by the tagion kernel.

## Write hirpcs

### submit

*HiRPC Method for submitting a contract, eg. making a transaction*

method.name = "submit"  
method.params = Contract(SMC)  

## Read methods (DART(ro) + friends)

### search (will be deprecated)

*This method takes a list of Public keys and returns the associated archives*
This will be removed in the future in favour of a similar method which returns the list of associated DARTIndices instead
and it will be the clients reponsibillity to ask for the needed archives.
See [TIP1](/documents/TIPs/cache_proposal_23_jan)

method.name = "search"  
method.params = Pubkey[]  

### dartCheckRead

*This method takes a list of DART Indices and responds with all of the indices which were not in the DART*

method.name = "dartCheckRead"  
method.params = DARTIndex[]  

### dartRead

*This method takes a list of DART Indices and responds with a Recorder of all the archives which were in the DART*

method.name = "dartRead"  
method.params = DARTIndex[]  

### dartRim

*This method takes a rimpath a return a Recorder with all of the branches in that rim*

method.name = "dartRim"  
method.params = Rims  

### dartBullseye

*This method return the bullseye of the database*

method.name = "dartBullseye"  

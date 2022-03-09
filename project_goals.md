# Project goals for Tagion core-team in 2022.

## Workflow and QA

It is the aim to move the core develop in direction of CD/CI(Continues delivery/integration), which is a continued goal from 2021.

To archive this core team will work on the following

1. Build flow environment

   1. Should be able to run unittest.
   2. Should be able to build all programs in a simple manner.
   3. Should be able to enable debugging in an easy manner.
   4. Should be able to execute regression tests on system level.
   5. Should be able enable and disable part of the regression. 
   6. The develop should be able get easy readable feedback on the test results.
   
2. Qualification methodical.

   1. On the module level. The development strategic should adopt TDD (Test driver development).

      1. The test should be written in unittest in source file and should primarily include the function in the source code of concern.
      2. An unittest should be written such that it can be used as an example in the  documentation.
   2. For system level test BDD (Behavior driven development) should be used.
      1. The specification in the BDD should include a text to explain the function of a test
      2. The BDD should follow the (Should, Given, And, When, Then) methodical.
   3. The develop should merge with the daily branch everyday. 
   4. If the code passes the TDD and BDD the code should be merge in to the daily branch
   5. If the part of the code is work in progress the develop can disable this with a version flag and if it code passes the code can be push.
   6. A pull-request should be done each day from the daily to the current. 
   7. The team leads should comment on the daily pull-request and can decide if the code should be merged with the current version. 

3. Development progression reporting

   1. To enable easier overview of the work progress, each feature/functions should be divided to tasks.

   2. Each task should be listed in a task-pool list.

   3. Each task is given a score complex score and completion score.

   4. If a task is too complex the task should be broken down into smaller tasks.

      The goal is that a task should only take a five days or maximum a week

4. Regression server

   1. The daily should be execute TDD and BDD at least one over night.
   2. The daily report should be available for the developer or other interpreted parties.
   3. It should be possible for a develop to enable version flags for and the nightly regression should be execute on this.
   
4. Documentation
	
   1. The source should be document in common accessible format.
   
   2. The API should be documented.
   
   3. The different tools should be documented.
   
6. External engagement

   1. The source should be have external code reviews.
   

![Alt text](figs/BDD_TDD.png?raw=true)

## The Business Goal for the core project for 2022

The business goal for the core-team is to give better visibility of what is worked on at the moment and the progress. It is also the goal to move towards CI which will give continues feed back and should also improve the support for the Playnet and the rest of the origination.

   

   ​     


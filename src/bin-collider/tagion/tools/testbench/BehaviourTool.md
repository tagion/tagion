## Feature: This tool should generate initial D code from a BDD.md file

`tagion.tools.testbench.BehaviourFeature`

### Scenario: Create a list of all the <bdd>.md files

`Create_a_list_of_BDD`
    *Given* a list of file directories to be searched

`search_paths`
      *And* generated a list of all the <name>.md files in the directory list

`create_list`
    *When* the BDD has been parsed

`parsed`
      *And* check that the D source <name>.d file exits

`file_exists`

​      *And* if the D source file exits then change the **<name>.d** to **<name>**.tmp.d

`change_name`

​    *Then* write all the D source files to selected name.

`write_files`


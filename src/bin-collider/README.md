# Collider tool
>The Collider tool handles Behaviour Driven test flow
- Creates skeletens from the BDD Cucumber syntax.
- Run the BDD test 

## Options
```
Usage:
collider [<option>...]
# Sub-tools
collider reporter [<options>...]

<option>:
     --version display the version
-I             Include directory
-O             Write configure file 'collider.json'
-R --regex_inc Include regex Default:"/testbench/"
-X --regex_exc Exclude regex Default:""
-i    --import Set include file Default:""
-p   --package Generates D package to the source files
-c     --check Check the bdd reports in give list of directories
-C             Same as check but the program will return a nozero exit-code if the check fails
-s  --schedule Execution schedule Default: 'collider_schedule.json'
-r       --run Runs the test in the schedule
-S             Rewrite the schedule file
-j      --jobs Sets number jobs to run simultaneously (0 == max) Default: 0
-b       --bin Testbench program Default: 'testbench'
-P     --proto Writes sample schedule file
-f     --force Force a symbolic link to be created
-v   --verbose Enable verbose print-out
-h      --help This help information.
```

## Configuration file
Some of the options can added to a configure file.
The configuer file can with via `-O` switch.

Sample of a config file
```
{
    "bdd_ext": ".md",  /// bdd markdown extension
    "bdd_gen_ext": "gen.md", /// Generated markdown
    "d_ext": "gen.d",   /// Regenrated D-source extension
    "dfmt": "\/home\/carsten\/bin\/dfmt\n", /// D-source formater
    "dfmt_flags": [
        "-i"
    ],
    "enable_package": false,  /// Enables generation of package.d (switch '-p')
    "iconv": "\/usr\/bin\/iconv\n", /// Program used to correct illegal utf char in the markdown files
    "iconv_flags": [
        "-t",
        "utf-8",
        "-f",
        "utf-8",
        "-c"
    ],
    "importfile": "", /// Include file (switch '-i')
    "paths": [],      /// List of source paths (switch '-I')
    "regex_exc": "",  /// Regex to exclude file from source paths
    "regex_inc": "\/testbench\/",  /// Regex to include files in the source paths
    "schedule_file": "collider_schedule.json",  /// Collider run schedule filename (swirch '-P')
    "test_stage_env": "TEST_STAGE" /// 
}
```

## Generating skeletens from the BDD md

The switch `-i<include-file>` set the include files which is added to all the skeletens source files and 
`-I<dir>` sets the import path and 
`-p` enables the generation of the `package.d` for all the generated package inside the `<dir>`.

```
Example:
collider -p -itagion/bdd/bdd_import.di -Itagion/bdd -v
```


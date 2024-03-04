# collider [testing tool]
>The Collider tool handles Behaviour Driven test flow
- Creates skeletens from the BDD Cucumber syntax.
- Run the BDD test 

## Options
```
Usage:
./build/x86_64-linux/bin/collider [<option>...]
# Sub-tools
./build/x86_64-linux/bin/collider reporter [<options>...]

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
-n       --dry Shows the parameter for a schedule run
-h      --help This help information.collider [<option>...]
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
    "regex_exc": "",  /// Regex to exclude file from source paths (switch '-X')
    "regex_inc": "\/testbench\/",  /// Regex to include files in the source paths (switch '-R')
    "schedule_file": "collider_schedule.json",  /// Collider run schedule filename (switch '-P')
    "collider_root": ""  /// The root of the log files (if $COLLIDER_ROOT is set then this is used instead)
}
```
The root directory of the log path is set with the `"collider_root"` configure,
this path can be overruled with the `$COLLIDER_ROOT` environment.


## Generating skeletens from the BDD md

The switch `-i<include-file>` set the include files which is added to all the skeletens source files and 
`-I<dir>` sets the import path and 
`-p` enables the generation of the `package.d` for all the generated package inside the `<dir>`.

*Example:*
```
collider -p -itagion/bdd/bdd_import.di -Itagion/bdd -v
```
[Example of BDD](docs/misc/behaviour/BDD_Process.md)

## Executing BDD 
The collider tool can execute a list of BDD defined in the `collider_schedule.json`


### Generate proto schedule file.
*Example:*
```
collider -P -s default_schedule.json
```
Will generated a default schedule file named `default_schedule.json`.
```
{
    "units": {
        "collider_test": { /// Name of test program 
            "args": ["-x", "-oxxx.txt"],    /// Argument applied to the program
            "envs": {
                "MY_ENV" : "Some value"
            },                              /// Addtinal environment 
            "stages": [
                "commit"                    /// This of stage flags
            ],
            "timeout": 0.0                  /// Timeout in ms
        }
    }
}
```

### Run the tests listed in the schedule file
To run the all the testprograms in stage .

*Example:*
```
# Make sure to set the environment before running the collider
# The following will run all tests with the "commit" stage using 4 core.
collider -r commit -j 4  -b build/x86_64-linux/bin/testbench
```

* Note: More than one `-r` can execute if needed.  


## Check the result of BDD run

Prints the accumulated result. 

*Example:*
```
collider -cv logs/x86_64-linux/bdd/commit/results/
```

## Inspecting the setup of the schedule run.

The setting of a specific run can be inspect by adding the `--dry` switch.

```
export COLLIDER_ROOT=/tmp
collider -r example --dry
```
With a schedule like this.
```
{
    "units": {
        "collider_test": {
            "args": [
                "-f$WORKDIR"
            ],
            "envs": {
                "WORKDIR": "$(HOME)\/work"
            },
            "stages": [
                "example"
            ],
            "timeout": 0.0
        }
    }
}⏎   
```
Should produce a dry-run output as below.

```
################################################################################
0] testbench test_example -f/home/carsten/work
Log file /tmp/example/results/test_example.log
Unit = {
    "args": [
        "-f$WORKDIR"
    ],
    "envs": {
        "WORKDIR": "$(HOME)\/work"
    },
    "stages": [
        "example"
    ],
    "timeout": 0.0
}
Collider environment:
COLLIDER_ROOT = /tmp/
BDD_LOG = /tmp/example
BDD_RESULTS = /tmp/example/results
TEST_STAGE = example
WORKDIR = /home/carsten/work
```

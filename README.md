# Search-Based Fuzzing For RESTful APIs With NoSQL Databases

In this package, we provide necessary info for replicating experiment in the paper.

- [wb-mongo](wb-mongo) is a folder where contain a runnable file (i.e., `jar`) and source code of our proposed approach.
- [scripts/jvm-suts](scripts/jvm-suts) is a folder where contains bash script for each case study. The bash script allows JaCoCo to collect code coverage of the SUT when the SUT is tested with any testing technique.
- [scripts/bb-exp.py](scripts/bb-exp.py) is a python script we developed to conduct black-box testing experiment. It can generate bash scripts for running  experiments of all of the six techinques we selected on the SUTs. 
- [scripts/wb-exp.py](scripts/wb-exp.py) is a python script we developed to conduct white-box testing experiment. It can generate bash scripts for running white-box tools on the SUTs.
- [scripts/schedule.py](scripts/schedule.py) is a bash script which could be used to schedule executions of bash scripts generated by `wb-exp.py` and `bb-exp.py`.
- [scripts/tools](scripts/tools)  and [scripts/util](scripts/util) are folders where contains necessary utilities to conduct the experiment.
- [EMB](EMB) refers to an existing benchmark for web/enterprise applications. In this study, we opted all REST APIs which use MongoDB, i.e., _bibliothek_, _genome-nexus_, _gestaohospitial-rest_, _ocvn-rest_, _reservations-api_, and _session-service_.

## Environment Setup

This study employs various tools and multiple case studies.
In order to conduct experiments with them, Java 8, Java 11, Java 17, Python 3 and Docker are required.

## Case Studies Setup

In this study, experiments were conducted with 6 JVM REST APIs from [EMB](https://github.com/WebFuzzing/EMB).

**Step 1** Java environment variable setup

The case studies are implemented with various Java versions, i.e., Java 8, Java 11 and Java 17.
In order to build them, there is a need to configure environment variables to know where could find the required version, i.e., `JAVA_HOME_8`, `JAVA_HOME_11`, and `JAVA_HOME_17`.

For instance, `JAVA_HOME_8` is configured in Windows OS with __Advanced system settings__.

**Step 2** build case studies

Go to `EMB`, then run
> `python scripts/dist.py`

After the builds finishes, you could be able to access a folder named `dist` under `EMB`.

**Step 3** setup environment variable (`EMB_DIR`) referring to where the case studies locate at (i.e., `dist` folder).

For Mac, with terminal, run
> `export EMB_DIR=/foo/EMB/dist`

For windows, configure environment with __Advanced system settings__.

## Black-Box Testing Experiments

**Step 1** Tool Setup

Tools could be accessed as follows (accessed date:Aug-06-2024) 
- [EvoMaster](https://github.com/EMResearch/EvoMaster): release [v3.0.0](  https://github.com/WebFuzzing/EvoMaster/releases/download/v3.0.0/evomaster.jar).
- [Restler](https://github.com/microsoft/restler-fuzzer): tag [v9.2.4](https://github.com/microsoft/restler-fuzzer/releases/tag/v9.2.4)
- [Schemathesis](https://github.com/schemathesis/schemathesis): release 3.33.3
- [ARAT-RL](https://github.com/codingsoo/ARAT-RL): commit [04e22bb](https://github.com/codingsoo/ARAT-RL/tree/04e22bb07ea8217617f1eae1b8fb7fdc84cfc277)

Please follow the guideline in the webpage of each tool to install it.


**Step 2** Tool path configuration

In order to run the experiment with the script, there is a need to configure a path where the tools locate at.
How to configure the path could be conducted with the doc in the `bb-exp.py`. 
For instance, to configure Restler, add env variable `RESTLER_DIR_V924` referring to where you install Restler, i.e., `restler_bin`.

**Step 3** Generate bash scripts for the experiments

With the `bb-exp.py`, we provide parameters as `<basePort> <dir> <minSeed> <maxSeed> <maxTimeSeconds>`. Below shows a setting we used in the paper,
> `python bb-exp.py 12345 bb-exp-dir 1 10 3600`

With the command, `bb-exp-dir` folder should be created as the following structure
```
bb-exp-dir/
├─ logs/
├─ scripts/
│  ├─ ARAT-RL_bibliothek_16230.sh
│  ├─ ...
├─ tests/
│  ├─ bibliothek_ARAT-RL__S1_16230
│  ├─ ...
├─ tmps
├─ exec (this folder will be created after the experiment starts)
```

**Step 4** Start the experiment with the generated scripts using `schedule.py` which is configured with `<N> <FOLDER>`, e.g., for scripts in `bb-exp-dir`, run 10 of them in parallel,
> `python schedule.py 10 bb-exp-dir`

After the experiment is done, `exec` folder contains code coverage report (`.exec` format) and `tests` folder contains results produced by each technique on each case study.

## White-Box Testing Experiments (Base and Mongo)

**Step 1** Build tool with source code

Go to `wb-mongo/EvoMaster-mongo`, then run
> `mvn clean install -DskipTests`

You will get `evomaster.jar` under `wb-mongo/EvoMaster/core/target`.

Note that you can also find our tool under [wb-mongo/evomaster.jar](wb-mongo/evomaster.jar).

**Step 2** Tool path configuration

The path of `evomaster.jar` needs to be configured using the environment variable `EVOMASTER_DIR` or you can also directly modify the variable `EVOMASTER_DIR` in `wb-exp.py`.

**Step 3** Generate bash scripts for the experiment

With the `wb-exp.py`, we provide parameters as `<dir> <minSeed> <maxSeed> <budget>`. Below shows a setting we used in the paper,
> `python wb-exp.py wb-exp-dir 1 30 1h`

With the command, `we-exp-dir` folder should be created as the following structure

```
wb-exp-dir/
├─ logs/
├─ reports/
├─ scripts/
│  ├─ evomaster_wbBase_23466_bibliothek.sh
│  ├─ ...
├─ tests/
├─ bibliothek-evomaster-runner.jar
├─ ...
```

**Step 4** Start the experiment with the generated scripts using `schedule.py` which is configured with `<N> <FOLDER>` as black-box testing experiment.

After the experiment is done, `reports` folder contains statistics results outtputed by white-box EvoMaster (`.csv` format) and `tests` folder contains tests generated by white-box EvoMaster on each case study.

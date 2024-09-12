#!/usr/bin/env python
import math
import random
import sys
import os
import shutil
import stat
import pathlib
from pathlib import PureWindowsPath, PurePosixPath
import platform
import io
## use to write configuration file for RestTestGenV2
import json

if len(sys.argv) < 6 or len(sys.argv) > 8:
    print("Usage:\n<nameOfScript>.py <basePort> <dir> <minSeed> <maxSeed> <maxTimeSeconds> <sutFilter?> <toolFilter?>")
    exit(1)


# TCP port bindings will be based on such port.
# If running new experiments while some previous are still running, to avoid TCP port
# conflict, can use an higher base port. Each run reserves 10 ports. So, if you run
# 500 jobs with starting port 10000, you will end up using ports up to 15000
BASE_PORT= int(sys.argv[1])

# When creating a new set of experiments, all needed files will be saved in a folder
BASE_DIR = os.path.abspath(sys.argv[2])

# Experiments are repeated a certain number of times, with different seed for the
# random generator. This specify the starting seed.
MIN_SEED = int(sys.argv[3])

# Max seed, included. For example, if running min=10 and max=39, each experiment is
# going to be repeated 30 times, starting from seed 10 to seed 39 (both included).
MAX_SEED = int(sys.argv[4])

# By default, experiments on BB are run with time as stopping criterion
MAX_TIME_SECONDS  = int(sys.argv[5])

#
# An optional string to filter SUTs to be included based on their names
# A string could refer to multiple SUTs separated by a `,` like a,b
# not; represents what have been specified should be excluded
# Note that
# None or `all` represents all SUTs should be included
# and only consider unique ones, eg, create one experiment setting for a,a
# Default is None
SUTFILTER = None
if len(sys.argv) > 6:
    SUTFILTER = str(sys.argv[6])

# An optional string to filter bb tools to be included based on their names
# A string could refer to multiple tools separated by a `,` like a,b
# Note that
# None or `all` represents all tools should be included
# and only consider unique ones, eg, create one experiment setting for a,a
# Default is None
TOOLFILTER = None
if len(sys.argv) > 7:
    TOOLFILTER = str(sys.argv[7])

## Default setting: Configure whether to enable auth configuration
ENABLE_AUTH_CONFIG = True

## Default setting: Configure whether to enable run cmd for globally handling timeout for each tool
ENABLE_TIMEOUT_RUM_CMD = True
ENABLE_TIMEOUT_RUM_CMD_VAR = "i"

## Default setting: Configure whether to fix basic issue in schema in order to apply the tool
FIX_BASIC_SCHEMA_ISSUE = True

## configure auth file
AUTH_DIR = os.path.abspath("authconfig")

class AuthInfo:
    def __init__(self, key, value):
        self.key = key
        self.value = value

class PlatformSetup:
    def __init__(self, platform, dir):
            self.platform = platform
            self.dir = dir

# a prefix for indicating local schema
LOCAL_SCHEMA_PREFIX="local:"


JVM = "JVM"
JDK_8 = "JDK_8"
JDK_11 = "JDK_11"
JDK_17 = "JDK_17"
JS = "JS"
DOTNET_3 = "DOTNET_3"


class Sut:
    def __init__(self, name, endpointPath, openapiName, baseURL, authInfo, runtime, platform):
           self.name = name
           self.endpointPath = endpointPath
           ## baseline techniques need the schema which is on the local
           self.openapiName = openapiName
           ## base URL to process path in the schema
           self.baseURL = baseURL
           ## auth configuration in header
           self.authInfo = authInfo
           ## eg either JVM or NODEJS
           self.runtime = runtime
           self.platform = platform

def isJava(sut):
    return sut.platform == JDK_8 or sut.platform == JDK_11 or sut.platform == JDK_17


SUTS = [
    # REST JVM
    Sut("reservations-api", "/v3/api-docs","openapi.json", "",None, JVM, JDK_11),
    Sut("bibliothek", "/openapi","openapi.json", "",None, JVM, JDK_17),
    Sut("ocvn-rest", "/v2/api-docs?group=1ocDashboardsApi", "openapi.json", "",None, JVM, JDK_8),
    Sut("gestaohospital-rest","/v2/api-docs", "openapi.json", "", None, JVM, JDK_8),
    Sut("genome-nexus", "/v2/api-docs","openapi.json", "",None, JVM, JDK_8),
    Sut("session-service","/v2/api-docs","openapi.json", "",None, JVM, JDK_8)
]

if SUTFILTER is not None and SUTFILTER.lower() != "all":
    filteredsut = []
    unfound = []

    filterFalse = SUTFILTER.startswith("not;")
    SUTFILTER = SUTFILTER.replace('not;', '')
    specified = list(set(SUTFILTER.split(",")))



    # validate specified SUT info
    for s in specified:
        found = list(filter(lambda x: x.name.lower() == s.lower(), SUTS))
        if len(found) == 0:
            print("ERROR: cannot find the specified sut "+s)
            exit(1)

    for s in list(SUTS):
        foundInSpecified = list(filter(lambda x: s.name.lower() == x.lower(), specified))
        if len(foundInSpecified) == 0 and filterFalse:
            filteredsut.append(s)
        elif len(foundInSpecified) == 1 and (not filterFalse):
            filteredsut.append(s)
    SUTS = filteredsut

# where the script for sut setup could be found based on platforms
SUTS_SETUP = [
    PlatformSetup(JVM, "jvm-suts"),
#     PlatformSetup(NODEJS, "js-suts")
]

# input parameter validation
if MIN_SEED > MAX_SEED:
    print("ERROR: min seed is greater than max seed")
    exit(1)

if not os.path.isdir(BASE_DIR):
    print("creating folder: " + BASE_DIR)
    os.makedirs(BASE_DIR)
else:
    print("ERROR: target folder already exists")
    exit(1)


TMP=BASE_DIR+"/tmp"
SCRIPT_DIR=BASE_DIR+"/scripts"
LOGS=BASE_DIR+"/logs"
TESTS=BASE_DIR+"/tests"

IS_WINDOWS = platform.system() == 'Windows'

### configure python
PYTHON_COMMAND = "python3"


## As tried, ARAT_RL does not work with python 3.12, and works fine with 3.8. then provide specific setting here as a temporal solution
PYTHON_COMMAND_FOR_ARAT_RL = "python3.8"

if IS_WINDOWS:
    PYTHON_COMMAND = "python"
    PYTHON_COMMAND_FOR_ARAT_RL = "python"

### Java
JAVA_HOME_8 = os.environ.get("JAVA_HOME_8", "")
if JAVA_HOME_8 == "":
    print("ERROR: cannot find JAVA_HOME_8")
    exit(1)
JAVA_8_COMMAND = "\"" + JAVA_HOME_8 + "\"/bin/java"

JAVA_HOME_11 = os.environ.get("JAVA_HOME_11", "")
if JAVA_HOME_11 == "":
    print("ERROR: cannot find JAVA_HOME_11, and it is needed for RestTestGen")
    exit(1)
JAVA_11_COMMAND = "\"" + JAVA_HOME_11 + "\"/bin/java"

############################################################################
### evomaster blackBox v3
###     see https://github.com/EMResearch/EvoMaster
############################################################################
BB_EVOMASTER = "evomaster_bb_v3"

############################################################################
### Restler v9.2.4
###     follow https://github.com/microsoft/restler-fuzzer to install it
###     then configure the bin folder where Restler is (`RESTLER_DIR`)
###     see https://github.com/microsoft/restler-fuzzer/blob/main/docs/user-guide/Telemetry.md
###     Set the RESTLER_TELEMETRY_OPTOUT environment variable to 1 or true.
############################################################################
BB_RESTLER_V924 = "Restler_v9_2_4"
RESTLER_V924_START_SCRIPT_DIR = "tools/restler-quick-start.py"
RESTLER_V924_START_SCRIPT = "restler-quick-start.py"
RESTLER_DIR_V924 = os.environ.get("RESTLER_DIR_V924", "")


############################################################################
### Schemathesis
###     https://github.com/schemathesis/schemathesis
###     install with pip install schemathesis
############################################################################
BB_SCHEMATHESIS = "Schemathesis"
SCHEMATHESIS_CMD = "schemathesis run"


############################################################################
### ARAT-RL v0.1
###     https://github.com/codingsoo/ARAT-RL
###       [Aug-06-2024, release 0.1(tag  v0.1)], the released 0.1 does not specify the time budget
###       [Aug-06-2024, commit 04e22bb]
###       https://github.com/codingsoo/ARAT-RL/tree/04e22bb07ea8217617f1eae1b8fb7fdc84cfc277
###       pip install -r requirements.txt
############################################################################
BB_ARAT_RL = "ARAT-RL"
ARAT_RL_DIR = "tools"
ARAT_RL_SCRIPT = "arat-rl.py"

############################################################################
### in order to apply bb tools
###     there might need a further handling in inputs,
###     eg, set auth, modify the port, add schemes/server, modify the format
###     then we developed such utility which includes
###         - authForResTest <testConfig.yaml path> <key> <value>
###         - jsonToYaml <openapi path>
###         - updateURLAndPort <openapi path> <port>
############################################################################
BB_EXP_UTIL = "$BASE/util/bb-exp-util.jar"
TIMEOUT_RUN_CMD_SCRIPT="util/run_cmd.sh"

BB_TOOLS = [
            BB_EVOMASTER,
            BB_RESTLER_V924,
            BB_SCHEMATHESIS,
            BB_ARAT_RL
            ]


if TOOLFILTER is not None and TOOLFILTER.lower() != "all":
    filteredtools = []
    unfound = []

    for s in list(set(TOOLFILTER.split(","))):
        found = list(filter(lambda x: x.lower() == s.lower(), BB_TOOLS))
        if len(found) == 0:
            print("ERROR: cannot find the specified sut "+s)
            exit(1)
        filteredtools.extend(found)
    BB_TOOLS = filteredtools


def writeScript(code, port, tool, sut):
    script_path = SCRIPT_DIR + "/" + tool  + "_" + sut.name + "_" + str(port) + ".sh"
    script = open(script_path, "w")
    script.write(code)

    st = os.stat(script_path)
    os.chmod(script_path, st.st_mode | stat.S_IEXEC)

    return script

def getScriptHead(port,tool,sut):
    s = ""
    s += "#!/bin/bash \n"

    s += 'SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) \n'
    s += "BASE=$SCRIPT_DIR/../.. \n"
    s += "PORT=" + str(port) + " \n"
    label = sut.name+"__"+tool+"__\"$PORT\""

    if ENABLE_TIMEOUT_RUM_CMD:
        s += "\nsource $BASE/util/run_cmd.sh\n\n"

    sut_dir = findSutScriptDir(sut.runtime)
    command = "bash $BASE/"+sut_dir+"/"+sut.name+".sh"
    redirection = "> \""+LOGS+"/sut__"+sut.name+"__"+tool+"__$PORT.txt\" 2>&1 & \n"

    if sut.runtime == JVM:
        s += "# JaCoCo does not like full paths or exec in Windows/GitBash format... but relative path seems working \n"
        # strange it does not want  ./"+sys.argv[2] before the exec
        inputs =  " $PORT $BASE/tools/jacocoagent.jar  ./exec/"+label+"__jacoco.exec "
    else :
        inputs = " $PORT $SCRIPT_DIR/../c8/"+label
    s += command + inputs + redirection

    if sut.runtime == JVM:
        s += "PID=$! \n"
        s += "# this works on GitBash/Windows... but very brittle \n"
        s += "sleep 120 \n"  # OCVN can be very sloooooow to start, eg 45s on my laptop
        # s += "PGID=$( ps  -p $PID | tail -n +2 | cut -c18-30 | xargs) \n" # this gives too many issues
        s += "CHILD=$( ps | cut -c1-20 | grep $PID | cut -c1-10 | grep -v $PID | xargs) \n"
        s += " \n"
    else:
        s += "sleep 60 \n"

    return s

## find a dir where save sut scripts based on the specified platform
def findSutScriptDir(platform):
    found = list(filter(lambda x: x.platform.lower() == platform.lower(), SUTS_SETUP))
    if len(found) == 0 or len(found) > 1:
        print("ERROR: 0 or multiple (>1) dir are found based on "+platform)
        exit(1)
    return found[0].dir

def getScriptFooter(port,tool,sut):
    s = ""
    s += "\n"
    if sut.runtime == JVM:
        s += "# with default kill signal, JaCoCo not generated. we need a SIGINT (code 2)\n"
        #s += "kill -n 2 -- -$PGID\n" # this kills everything, even other scripts started with schedule.py
        # s += "echo Going to kill child process [$CHILD] of parent [$PID] \n" #logging
        s += "kill -n 2 $CHILD\n"
        #s += "kill -n 2 $PID\n" # might not be necessary
    else :
        # see issue at: https://github.com/bcoe/c8/issues/166
        # added /shutdown endpoint to all SUTs
        s += "curl -X POST http://localhost:$PORT/shutdown\n"
    s += "\n"
    return s

def createScriptForEvoMaster(sut, port, seed):
    tool = BB_EVOMASTER

    evomaster_bb_log = pathlib.PurePath(LOGS + "/tool__" + sut.name + "__" + tool + "__" + str(port) + ".txt").as_posix()

    result_folder = createResultDir(sut.name, seed, port, tool)

    openapi_path = pathlib.PurePath(os.path.join(result_folder, sut.openapiName)).as_posix()

    command = downloadOpenApi(sut.endpointPath, openapi_path, evomaster_bb_log)
    if FIX_BASIC_SCHEMA_ISSUE:
        command = command + updateURLAndPort(openapi_path, port, evomaster_bb_log)

    ## start_tool
    start_tool_command = JAVA_8_COMMAND+" -Xms1G -Xmx4G -jar $BASE/tools/evomaster.jar"
    start_tool_command += " --blackBox true --minimize false"
    start_tool_command += " --maxTime " + str(MAX_TIME_SECONDS) + "s"
    if sut.endpointPath.startswith(LOCAL_SCHEMA_PREFIX):
        prefix = "file://"
        if not openapi_path.startswith("/"):
            prefix += "/"
        start_tool_command += " --bbSwaggerUrl \"" + prefix + openapi_path + "\""
    else:
        start_tool_command += " --bbSwaggerUrl http://localhost:$PORT" + sut.endpointPath
    start_tool_command += " --bbTargetUrl http://localhost:$PORT"
    start_tool_command += " --seed " + str(seed)
    start_tool_command += " --showProgress=false"
    start_tool_command += " --testSuiteSplitType=NONE"

    if ENABLE_TIMEOUT_RUM_CMD:
        start_tool_command += " --outputFilePrefix=EM_BB_R$"+ ENABLE_TIMEOUT_RUM_CMD_VAR

    if sut.runtime == JVM :
        start_tool_command += " --outputFormat JAVA_JUNIT_5"
    else :
        start_tool_command += " --outputFormat JS_JEST"

    if ENABLE_AUTH_CONFIG and sut.authInfo is not None:
        start_tool_command += " --header0 \"" + sut.authInfo.key + ": " + sut.authInfo.value+"\""

    start_tool_command += " --outputFolder \""+result_folder+"\""
    start_tool_command += " >> \""+evomaster_bb_log+"\" 2>&1"
    start_tool_command += "\n"

    if ENABLE_TIMEOUT_RUM_CMD:
        command += runCMDTimeout(tool, port, seed, start_tool_command, MAX_TIME_SECONDS)
    else:
        command += start_tool_command

    code = getScriptHead(port, tool, sut) + command + getScriptFooter(port, tool, sut)
    writeScript(code, port, tool, sut)

######################## baseline tools start ########################################
def createScriptForRestlerV924(sut, port, seed):
    tool = BB_RESTLER_V924

    # copy python script to the exp folder
    shutil.copy(pathlib.PurePath(RESTLER_V924_START_SCRIPT_DIR).as_posix(), BASE_DIR)

    restler_log = pathlib.PurePath(LOGS + "/tool__" + sut.name + "__" + tool + "__" +str(port) + ".txt").as_posix()

    result_folder = createResultDir(sut.name, seed, port, tool)
    # restler employ hour as the unit
    time_budget = math.ceil(MAX_TIME_SECONDS / 36) / 100
    openapi_path = pathlib.PurePath(os.path.join(result_folder, sut.openapiName)).as_posix()

    command = downloadOpenApi(sut.endpointPath, openapi_path, restler_log)

    if FIX_BASIC_SCHEMA_ISSUE:
        command = command + updateURLAndPort(openapi_path, port, restler_log)

    start_tool_command = PYTHON_COMMAND + " " + RESTLER_V924_START_SCRIPT
    start_tool_command +=  " --api_spec_path " + openapi_path
    start_tool_command += " --port " + str(port)
    start_tool_command +=  " --restler_drop_dir " + pathlib.PurePath(RESTLER_DIR_V924).as_posix()
    # start_tool_command +=  " --time_budget " + str(time_budget)
    start_tool_command +=  " --result_dir " + result_folder

#     if ENABLE_AUTH_CONFIG and sut.authInfo is not None:
#         start_tool_command +=  " --token_refresh_cmd \""+PYTHON_COMMAND+" "+str(pathlib.PurePath(os.path.join(AUTH_DIR, tool+"_"+sut.name+".py")).as_posix()) +"\""

    start_tool_command +=  " >> " + restler_log + " 2>&1"

    if ENABLE_TIMEOUT_RUM_CMD:
        command += runCMDTimeout(tool, port, seed, start_tool_command, MAX_TIME_SECONDS)
    else:
        command += start_tool_command

    code = getScriptHead(port, tool, sut) + command + getScriptFooter(port, tool, sut)
    writeScript(code, port, tool, sut)


## based on doc https://schemathesis.readthedocs.io/en/stable/
def createScriptForSchemathesis(sut, port, seed):
    tool = BB_SCHEMATHESIS

    schemathesis_log = pathlib.PurePath(LOGS + "/tool__" + sut.name + "__" + tool + "__" +str(port) + ".txt").as_posix()
    result_folder = createResultDir(sut.name, seed, port, tool)

    openapi_path = pathlib.PurePath(os.path.join(result_folder, sut.openapiName)).as_posix()


    command = downloadOpenApi(sut.endpointPath, openapi_path, schemathesis_log)
    if FIX_BASIC_SCHEMA_ISSUE:
        command = command + updateURLAndPort(openapi_path, port, schemathesis_log)

    start_tool_command = ""
    output_label=""
    if ENABLE_TIMEOUT_RUM_CMD:
        start_tool_command = schemathesisOption() +"\n"
        output_label = "_R\"$"+ENABLE_TIMEOUT_RUM_CMD_VAR+"\""

    start_tool_command += SCHEMATHESIS_CMD
    # Utilize stateful testing capabilities.
    if ENABLE_TIMEOUT_RUM_CMD:
        start_tool_command += " $OPTION"
    else:
        start_tool_command += " --stateful=links"

    # Enable or disable validation of input schema. default is true
    start_tool_command += " --validate-schema=false"
    # Timeout in milliseconds for network requests during the test run. 2s
    start_tool_command += " --request-timeout=2000"

    # Save test results as a VCR-compatible cassette.
    start_tool_command += " --cassette-path=\""+ result_folder + "/cassette" + output_label + ".yaml\""
    # Create junit-xml style report file at given path.
    start_tool_command += " --junit-xml=\"" + result_folder+"/junit" + output_label + ".xml\""
    # command += " --base-url="+openapi_path

    if ENABLE_AUTH_CONFIG and sut.authInfo is not None:
        start_tool_command += " --header \"" + sut.authInfo.key + ": " + sut.authInfo.value+"\""

    start_tool_command += " --base-url=http://localhost:$PORT" + str(sut.baseURL)
    start_tool_command += " \""+openapi_path +"\""

    start_tool_command += " >> " + schemathesis_log + " 2>&1 "

    if ENABLE_TIMEOUT_RUM_CMD:
        command += runCMDTimeout(tool, port, seed, start_tool_command, MAX_TIME_SECONDS)
    else:
        command += start_tool_command

    code = getScriptHead(port, tool, sut) + command + getScriptFooter(port, tool, sut)
    writeScript(code, port, tool, sut)

def createScriptForARATRL(sut, port, seed):
    tool = BB_ARAT_RL

    # copy python script to the exp folder
    shutil.copy(pathlib.PurePath(os.path.join(ARAT_RL_DIR, ARAT_RL_SCRIPT)).as_posix(), BASE_DIR)

    arat_rl_log = pathlib.PurePath(LOGS + "/tool__" + sut.name + "__" + tool + "__" +str(port) + ".txt").as_posix()

    result_folder = createResultDir(sut.name, seed, port, tool)
    # arat rl employ minute as the unit
    time_budget = int(math.ceil(MAX_TIME_SECONDS / 6) / 10)
    openapi_path = pathlib.PurePath(os.path.join(result_folder, sut.openapiName)).as_posix()

    command = downloadOpenApi(sut.endpointPath, openapi_path, arat_rl_log)


    output_label=""
    if FIX_BASIC_SCHEMA_ISSUE:
        command = command + updateURLAndPort(openapi_path, port, arat_rl_log)
        output_label = "_R\"$"+ENABLE_TIMEOUT_RUM_CMD_VAR+"\""


    filename = "tool__" + sut.name + "__" + tool + "__" +str(port) + "_http_500_error_report"+ output_label +".txt"
    report_path = pathlib.PurePath(os.path.join(result_folder, filename)).as_posix()

    start_tool_command = PYTHON_COMMAND_FOR_ARAT_RL + " " + ARAT_RL_SCRIPT
    start_tool_command +=  " " + openapi_path
    start_tool_command +=  " http://localhost:$PORT" #+ str(sut.baseURL)
    start_tool_command +=  " " + str(time_budget)
    start_tool_command +=  " " + report_path


    start_tool_command +=  " >> " + arat_rl_log + " 2>&1"

    if ENABLE_TIMEOUT_RUM_CMD:
        command += runCMDTimeout(tool, port, seed, start_tool_command, MAX_TIME_SECONDS)
    else:
        command += start_tool_command

    code = getScriptHead(port, tool, sut) + command + getScriptFooter(port, tool, sut)
    writeScript(code, port, tool, sut)

###################### utility #############################

def schemathesisOption():
    return """
OPTION="--data-generation-method=negative"
if [ $(( $%s %% 3 )) -eq 1 ]; then
\tOPTION="--stateful=links"
elif [ $(( $%s %% 3 )) -eq 2 ]; then
\tOPTION="--checks=all"
fi

            """% (ENABLE_TIMEOUT_RUM_CMD_VAR, ENABLE_TIMEOUT_RUM_CMD_VAR)

def runCMDTimeout(tool, port, seed, commandsInOneLine, time_budget):
    fun_name = tool + "_" + str(port) + "_" + str(seed)

    commands = ''.join(list(map(lambda x: "\t\t\t"+x, commandsInOneLine.splitlines(True))))

    template = """
function %s {
\ti=0

\twhile true
\t\tdo
\t\t\tlet %s++
\t\t\techo "%s $%s"
%s
\t\t\tsleep 5
\t\tdone
}
run_cmd "%s" %s

    """% (str(fun_name), ENABLE_TIMEOUT_RUM_CMD_VAR, str(fun_name), ENABLE_TIMEOUT_RUM_CMD_VAR, str(commands), str(fun_name), str(int(time_budget) + 5))
    return template


def jsonToYaml(openapi_path, log):
    command = "\necho \"convert json to yaml\"" + " >> " + log + "\n\n"
    command = command + JAVA_8_COMMAND + " -jar " + BB_EXP_UTIL + " jsonToYaml \"" + openapi_path+"\""
    command = command + " >> " + log + " 2>&1 "
    command = command + "\nsleep 2"
    return command + "\n\n"

def updateURLAndPort(openapi_path, port, log, convertToV3=False, format=None):
    command = "\necho \"update url and port\"" + " >> " + log + "\n\n"
    command = command + JAVA_8_COMMAND + " -jar " + BB_EXP_UTIL + " updateURLAndPort \"" + openapi_path + "\" " + str(port)
    if convertToV3:
        command = command + " " + str("true")
    if format is not None:
        command = command + " " + str(format)
    command = command + " >> " + log + " 2>&1 "
    command = command + "\nsleep 2"
    return command + "\n\n"

## download openapi
def downloadOpenApi(endpointPath, openapiName, log):
    command = "\n# save open api to local\n"
    if endpointPath.startswith(LOCAL_SCHEMA_PREFIX):
        local_path = endpointPath.split(LOCAL_SCHEMA_PREFIX)[1]
        command = command + "cp "+str(pathlib.PurePath(local_path).as_posix())+" "+openapiName
    else:
        command = command + "curl http://localhost:$PORT"+endpointPath + " --output "+openapiName
        command = command + " >> " + log + " 2>&1 "

    command = command + "\nsleep 5"
    return command + "\n\n"


## create folder to save the results
def createResultDir(sut_name, seed, port, tool_name, folder=TESTS):
    dir = folder + "/"+resultDir(sut_name, seed, port, tool_name)
    os.makedirs(dir)
    return str(pathlib.PurePath(dir).as_posix())

def resultDir(sut_name, seed, port, tool_name):
    return sut_name + "_"+ tool_name + "_" + "_S" + str(seed) + "_" + str(port)

######################## baseline tools ends ########################################

def createJobs():

    port = BASE_PORT

    for sut in SUTS:
        for seed in range(MIN_SEED, MAX_SEED + 1):

            if BB_EVOMASTER in BB_TOOLS:
                createScriptForEvoMaster(sut, port, seed)
                port = port + 10

            if BB_RESTLER_V924 in BB_TOOLS:
                # Restler v9.2.4
                createScriptForRestlerV924(sut, port, seed)
                port = port + 10

            if BB_SCHEMATHESIS in BB_TOOLS:
                # Schemathesis
                createScriptForSchemathesis(sut, port, seed)
                port = port + 10

            if BB_ARAT_RL in BB_TOOLS:
                # ARAT RL_
                createScriptForARATRL(sut, port, seed)
                port = port + 10



shutil.rmtree(TMP, ignore_errors=True)
os.makedirs(TMP)
os.makedirs(LOGS)
os.makedirs(TESTS)
os.makedirs(SCRIPT_DIR)
createJobs()

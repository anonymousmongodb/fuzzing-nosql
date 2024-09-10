# This uses some code from https://github.com/microsoft/restler-fuzzer/blob/main/restler-quick-start.py
import json
import argparse
import contextlib
import os
import subprocess
from pathlib import Path

#RESTLER_RESULTS_FOLDER = "restler-exp-results"
MERGED_SETTING = "merged_settings"

@contextlib.contextmanager
def usedir(dir):
    """ Helper for 'with' statements that changes the current directory to
    @dir and then changes the directory back to its original once the 'with' ends.

    Can be thought of like pushd with an auto popd after the 'with' scope ends
    """
    curr = os.getcwd()
    os.chdir(dir)
    try:
        yield
    finally:
        os.chdir(curr)

def compile_spec(api_spec_path, restler_dll_path, result_dir):
    """ Compiles a specified api spec

    @param api_spec_path: The absolute path to the Swagger file to compile
    @type  api_spec_path: Str
    @param restler_dll_path: The absolute path to the RESTler driver's dll
    @type  restler_dll_path: Str

    @return: None
    @rtype : None

    """
    folder = f"{result_dir}"
    if not os.path.exists(folder):
        os.makedirs(folder)

    with usedir(folder):
        subprocess.run(f'dotnet {restler_dll_path} compile --api_spec {api_spec_path}', shell=True)

    return folder

def add_custom_setting(org_setting_path, additional_setting_path, custom_folder):
    of = open(org_setting_path)
    ojson = json.load(of)

    af = open(additional_setting_path)
    ajson = json.load(af)

    for key, value in ajson.items():
        ojson[key] = value

    with open(f'{custom_folder}/{MERGED_SETTING}.json', 'w') as json_file:
        json.dump(ojson, json_file)

    of.close()
    af.close()

def fuzz_spec(ip, port, host, use_ssl, time_budget, restler_dll_path, folder, custom_setting, token_refresh_cmd):
    """ Runs RESTler's fuzz mode on a specified Compile directory

    In Fuzz-lean mode, RESTler executes once every endpoint+method in a compiled RESTler grammar
    with a default set of checkers to see if bugs can be found quickly.

    [use] In Fuzz mode, RESTler will fuzz the service under test during a longer period of time with the goal of
    finding more bugs and issues (resource leaks, perf degradation, backend corruptions, etc.).
    Warning: The Fuzz mode is the more aggressive and may create outages in the service under test if the service is poorly implemented.

    """

    with usedir(folder):
        compile_dir = Path(f'Compile')

        command = (
            f"dotnet {restler_dll_path} fuzz --grammar_file {compile_dir.joinpath('grammar.py')} --dictionary_file {compile_dir.joinpath('dict.json')}"
        )
        if custom_setting is not None:
            add_custom_setting(compile_dir.joinpath('engine_settings.json'), custom_setting,
                               compile_dir)
            command = f"{command} --settings {compile_dir.joinpath(f'{MERGED_SETTING}.json')}"
        else:
            command = f"{command} --settings {compile_dir.joinpath('engine_settings.json')}"

        if not use_ssl:
            command = f"{command} --no_ssl"
        if ip is not None:
            command = f"{command} --target_ip {ip}"
        if port is not None:
            command = f"{command} --target_port {port}"
        if host is not None:
            command = f"{command} --host {host}"
        if time_budget is not None:
            command = f"{command} --time_budget {time_budget}"

        if token_refresh_cmd is not None:
            command = f"{command} --token_refresh_command \"{token_refresh_cmd}\""
            command = f"{command} --token_refresh_interval 120"

        subprocess.run(command, shell=True)



if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('--api_spec_path',
                        help='The API Swagger specification to compile and test',
                        type=str, required=True)
    parser.add_argument('--ip',
                        help='The IP of the service to test',
                        type=str, required=False, default=None)
    parser.add_argument('--port',
                        help='The port of the service to test',
                        type=str, required=False, default=None)
    parser.add_argument('--restler_drop_dir',
                        help="The path to the RESTler drop",
                        type=str, required=True)
    parser.add_argument('--use_ssl',
                        help='Set this flag if you want to use SSL validation for the socket',
                        action='store_true')
    parser.add_argument('--host',
                        help='The hostname of the service to test',
                        type=str, required=False, default=None)
    parser.add_argument('--time_budget',
                        help='The time_budget used (hours))',
                        type=float, required=True, default=None)
    parser.add_argument('--result_dir',
                        help='The path to result)',
                        type=str, required=True, default=None)

    # parser.add_argument('--sut_name',
    #                     help='The name of sut)',
    #                     type=str, required=True, default=None)
    # parser.add_argument('--seed',
    #                     help='The seed',
    #                     type=int, required=True, default=None)
    parser.add_argument('--custom_setting',
                        help='The path to additional custom settings',
                        type=str, required=False, default=None)

    parser.add_argument('--token_refresh_cmd',
                        help='The cmd for auth token',
                        type=str, required=False, default=None)

    # parser.add_argument('--max_request_execution_time',
    #                     help='The maximum time for waiting the response',
    #                     type=float, required=False, default=None)



    args = parser.parse_args()

    api_spec_path = os.path.abspath(args.api_spec_path)
    restler_dll_path = Path(os.path.abspath(args.restler_drop_dir)).joinpath('restler', 'Restler.dll')
    compile_spec(api_spec_path, restler_dll_path.absolute(), args.result_dir)
    #test_spec(args.ip, args.port, args.host, args.use_ssl, restler_dll_path.absolute())
    fuzz_spec(args.ip, args.port, args.host, args.use_ssl, args.time_budget, restler_dll_path.absolute(), args.result_dir, args.custom_setting, args.token_refresh_cmd)
    print(f"Test complete.\nSee {os.path.abspath(args.result_dir)} for results.")

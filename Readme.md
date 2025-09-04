# Control Evaluation Engine

## Installation

1. Make sure Docker is installed and running
1. Open terminal or PowerShell at the repo's root directory
1. Build Docker image

    ```shell
    shell> docker build -t <imageName>:<tag> .
    ```

1. Start `julia` inside a container

    ```shell
    shell> docker run -it <imageName>:<tag> julia --project=.
    ```

1. Run tests (optional)

    Type `]` at the `julia>` prompt to enter package manager, then

    ```julia
    (CtrlEvalEngine) pkg> test
    ```


## Local Testing and Debug

### Running an evaluation

```sh
cd app
julia --project=. evaluation_engine.jl debug <input_file.json>
```
# Integration with the control agents

## INSTALLED PYENV:
$ sudo apt-get update && sudo apt-get install make build-essential libssl-dev     zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm     libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

$ curl https://pyenv.run | bash


## ADDED TO .bashrc:

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

## USED PYENV TO BUILD A DYNAMICALLY LINKED PYTHON:

$ PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install 3.10.14
$ pyenv shell 3.10.14
$ pyenv virtualenv pyjuliatesting

## CHECK FOR DYNAMIC LIBRARY:

$ ldd ~/.pyenv/versions/3.10.14/envs/pyjuliatesting/bin/python3.10 | grep libpython
libpython3.10.so.1.0 => /home/volttron/.pyenv/versions/3.10.14/lib/libpython3.10.so.1.0 (0x00007fc3dc826000)

## SET UP DEPENDENCIES:
$ pyenv activate pyjuliatesting
$ pip install ipython pandas julia


## IN JULIA SHELL:

julia> ENV["PYTHON"] = "/home/volttron/.pyenv/versions/3.10.14/envs/pyjuliatesting/bin/python"

## SET UP JULIA FROM PYTHON:
$ ipython
[1] import julia
[2] julia.install()

## IN JULIA SHELL:

pkg> build PyCall

julia> using PyCall

## TEST IT:

julia> PyCall.libpython
"/home/volttron/.pyenv/versions/3.10.14/lib/libpython3.10.so.1.0"

julia> PyCall.conda
false


## SET UP CtrlEvalEngine IN JULIA:
pkg> activate ctrl-eval-engine-app  # THIS IS THE APP DIRECTORY COPIED WITHOUT OUTER DIRECTORY.
julia> using CtrlEvalEngine

## IMPORT FROM PYTHON SIDE:

[1] import julia
[2] from julia.api import LibJulia, JuliaInfo
[3] api = LibJulia.load(julia='/home/volttron/PyJuliaTesting/julia-1.10.4/bin/julia')
[4] api.init_julia(['--project=/home/volttron/PyJuliaTesting/ctrl-eval-engine-app'])
[5] from julia import CtrlEvalEngine

### Visualize the output

```sh
julia --project=test test/visualize_results.jl <output_file.json>
```

An HTML file named `<output_file.json>-time-charts.html` will be created/updated.
Open it in a web browser to see the plots.

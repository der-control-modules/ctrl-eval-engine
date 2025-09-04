# Control Evaluation Engine

The Control Evaluation Engine, written in primarily in Julia, with some Python components,
is the backend component of [Energy Storage (ES) Control](https://es-control.pnnl.gov/),
an online tool for evaluating control algorithms against a simulated energy storage system.

The Control Evaluation Engine may also be installed as a library component for use by other applications.
In particular, the [Realime (RT) Control Agent](https://github.com/der-control-modules/realtime-control-agent)
is designed to be able to actuate the algorithms implemented in the Control Evaluation Engine on real-world hardware.

## Installation
To use the Control Evaluation Engine, it is first necessary to have a Python environment which is capable
of calling bindings to code written in Julia. This requires dynamic linking of the libpython library.
It should be noted that the system python on Debian-based systems (e.g., Ubuntu) statically links libpython,
so it is always necessary on these systems to install a dynamically linked virtual environment. 
The following installation procedure uses pyenv to install a dynamically linked python and a Julia environment
in which to install the Control Evaluation Engine for use within Python applications like the RT Control Agent:


1. Install and setup pyenv:

   ```shell
   $ sudo apt-get update && sudo apt-get install make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev
    libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
   $ curl https://pyenv.run | bash
   ```

1. Finish setup of pyenv by adding the following lines to .bashrc:

   ```shell
   export PYENV_ROOT="$HOME/.pyenv"
   [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH" 
   eval "$(pyenv init -)"
   ```

1. Use pyenv to build a dynamically linked Python virtual environment:

   ```shell
   $ PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install 3.10.14
   $ pyenv shell 3.10.14
   $ pyenv virtualenv pyjuliatesting
   ```

   > [!NOTE]
   > The name "pyjuliatesting" was used for the virtual environment, and will be referenced by this name in later steps,
   > but the user may use a different name so long as the same substitution is made in later steps.

1. Check that a dynamic version of libpython is now installed:

   ```shell
   $ ldd ~/.pyenv/versions/3.10.14/envs/pyjuliatesting/bin/python3.10 | grep libpython
   ```

   This should display a path to a libpython dynamic library (shared object) file:
   
   ```
   libpython3.10.so.1.0 => /home/volttron/.pyenv/versions/3.10.14/lib/libpython3.10.so.1.0 (0x00007fc3dc826000)
   ```

1. Activate the virtual environment and setup python dependencies.

   ```shell
   $ pyenv activate pyjuliatesting
   $ pip install ipython pandas julia
   ```

1. Start an interactive Julia environment (REPL) and define the location of the python environment:

   ```shell
   $ julia
   julia> ENV["PYTHON"] = "/home/volttron/.pyenv/versions/3.10.14/envs/pyjuliatesting/bin/python"
   ```

1. Start an interactive Python environment (python or ipython) and setup pyjulia:

   ```shell
   $ ipython
   [1] import julia
   [2] julia.install()
   ```

1. Returning to the Julia REPL, set up PyCall. The `]` key may be used to reach the "pkg>" prompt. The
   `backspace` key will then return to the "julia>" prompt:

   ```shell
   julia
   pkg> build PyCall
   julia> using PyCall
   ```

1. Test that Pycall can find libpython and is not using conda:

   ```shell
   julia> PyCall.libpython
   "/home/volttron/.pyenv/versions/3.10.14/lib/libpython3.10.so.1.0"
   julia> PyCall.conda
   false
   ```

1. Activate CtrlEvalEngine in Julia:

   ```shell
   pkg> activate ctrl-eval-engine-app  # THIS IS THE APP DIRECTORY COPIED WITHOUT OUTER DIRECTORY.
   julia> using CtrlEvalEngine
   ```

1. Import CtrlEvalEngine from the Python side:

   ```   
   [1] import julia
   [2] from julia.api import LibJulia, JuliaInfo
   [3] api = LibJulia.load(julia='/home/volttron/PyJuliaTesting/julia-1.10.4/bin/julia')
   [4] api.init_julia(['--project=/home/volttron/PyJuliaTesting/ctrl-eval-engine-app'])
   [5] from julia import CtrlEvalEngine
   ```

### Installing in Docker

If integration of the Engine with another application is not required,the Control Evaluation Engine can also be
installed, by itself, in Docker container using the following steps.

> [!NOTE]
> This procedure only installs the CtrlEvalEngine itself. Integration with Python applications would still require
> many of the steps in the previous procedure be performed, but in the context of Docker.

1. Make sure Docker is installed and running
1. Open terminal or PowerShell at the repo's root directory
1. Build Docker image

    ```shell
    $ docker build -t <imageName>:<tag> .
    ```

1. Start `julia` inside a container

    ```shell
    $ docker run -it <imageName>:<tag> julia --project=.
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
### Integration with the control agents


### Visualize the output

```sh
julia --project=test test/visualize_results.jl <output_file.json>
```

An HTML file named `<output_file.json>-time-charts.html` will be created/updated.
Open it in a web browser to see the plots.

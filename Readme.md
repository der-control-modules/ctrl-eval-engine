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

### Visualize the output

```sh
julia --project=test test/visualize_results.jl <output_file.json>
```

An HTML file named `<output_file.json>-time-charts.html` will be created/updated.
Open it in a web browser to see the plots.
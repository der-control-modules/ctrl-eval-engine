# Control Evaluation Engine

## Installation

### Native
1. Start `julia` in the repo's root directory
    ```shell
    julia --project=app
    ```
1. Install packages
    ```julia
    julia> ]
    (CtrlEvalEngine) pkg> instantiate
    ```
1. Run tests (optional)
    ```julia
    (CtrlEvalEngine) pkg> test
    ```

Now the repo should be ready to use.

### Docker
1. Open terminal or PowerShell at the repo's root directory
1. Build Docker image
    ```shell
    docker build -t <imageName>:<tag> .
    ```
1. Start `julia` inside a container
    ```shell
    docker run -it <imageName>:<tag> julia --project=.
    ```
1. Run tests (optional, similar to [Native](#Native))

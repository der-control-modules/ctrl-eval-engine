# Control Evaluation Engine

## Installation

### Native
1. Start `julia` in the repo's root directory
    ```shell
    shell> julia --project=app
    ```
1. Install packages

    Type `]` at the prompt to enter package management mode, then
    ```julia
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
    shell> docker build -t <imageName>:<tag> .
    ```
1. Start `julia` inside a container
    ```shell
    shell> docker run -it <imageName>:<tag> julia --project=.
    ```
1. Run tests (optional, similar to [Native](#Native))

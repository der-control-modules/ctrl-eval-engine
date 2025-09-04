FROM public.ecr.aws/docker/library/julia:1.9

ADD pnnl_web_proxy.pem /usr/local/share/ca-certificates/pnnl_web_proxy.crt
RUN update-ca-certificates
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /tmp
RUN apt-get update -y && apt-get install -y wget
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py39_23.1.0-1-Linux-x86_64.sh
RUN bash Miniconda3-py39_23.1.0-1-Linux-x86_64.sh -b -p /root/miniconda
RUN /root/miniconda/bin/conda create -n conda_jl python conda pandas
ENV CONDA_JL_HOME=/root/miniconda/envs/conda_jl

WORKDIR /app
COPY app/Project.toml app/Manifest.toml /app/
RUN julia --project=. -e "using Pkg; Pkg.Registry.update(); Pkg.instantiate()"

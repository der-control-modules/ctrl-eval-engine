FROM julia:1.8

ADD pnnl_web_proxy.pem /usr/local/share/ca-certificates/pnnl_web_proxy.crt
RUN update-ca-certificates

WORKDIR /app
COPY app/Project.toml app/Manifest.toml /app/
RUN julia --project=. -e "using Pkg; Pkg.instantiate()"

COPY .aws/config /root/.aws/config

ADD app /app

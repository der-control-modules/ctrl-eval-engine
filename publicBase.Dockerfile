FROM public.ecr.aws/docker/library/julia:1.9

ADD pnnl_web_proxy.pem /usr/local/share/ca-certificates/pnnl_web_proxy.crt
RUN update-ca-certificates
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /app
COPY app/Project.toml app/Manifest.toml /app/
RUN julia --project=. -e "using Pkg; Pkg.Registry.update(); Pkg.instantiate()"

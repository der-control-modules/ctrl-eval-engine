FROM public.ecr.aws/y1q8u1k0/base:latest

WORKDIR /app
COPY app/Project.toml app/Manifest.toml /app/
RUN julia --project=. -e "using Pkg; Pkg.instantiate()"

COPY .aws/config /root/.aws/config

ADD app /app

FROM public.ecr.aws/y1q8u1k0/base:latest

COPY .aws/config /root/.aws/config

ADD app /app
RUN julia --project=. -e "using Pkg; Pkg.precompile()"

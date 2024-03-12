FROM public.ecr.aws/y1q8u1k0/base:sep

COPY .aws/config /root/.aws/config

COPY app /app
RUN julia --project=. -e "using Pkg; Pkg.precompile();"

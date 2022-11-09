FROM python:3.11-slim

ADD pnnl_web_proxy.pem /etc/ssl/certs/pnnl_web_proxy.pem
RUN pip --cert /etc/ssl/certs/pnnl_web_proxy.pem install --upgrade pip

COPY requirements.txt /app/
WORKDIR /app
RUN pip --cert /etc/ssl/certs/pnnl_web_proxy.pem install --no-cache-dir -r requirements.txt
RUN cat /etc/ssl/certs/pnnl_web_proxy.pem >> /usr/local/lib/python3.11/site-packages/certifi/cacert.pem

COPY .aws/config /root/.aws/config

COPY app/* /app/

FROM python:slim

WORKDIR /config
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY config config
COPY scripts scripts
COPY entrypoint.sh .

COPY pki/ pki/

CMD [ "/bin/bash", "./entrypoint.sh" ]
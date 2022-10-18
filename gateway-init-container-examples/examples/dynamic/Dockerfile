FROM python:slim

WORKDIR /config
COPY config config
COPY scripts scripts
COPY entrypoint.sh .

COPY pki/ pki/

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

CMD [ "/bin/bash", "./entrypoint.sh" ]
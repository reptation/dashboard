FROM ubuntu:18.04 as build
EXPOSE 5001
COPY . /
WORKDIR /src
RUN apt-get update; apt-get install -y libpq-dev python3.6 python3-pip ; apt-get build-dep python-psycopg2; python3.6 -m pip install --upgrade pip; python3.6 -m pip install -r requirements.txt

CMD python3 hardware.py


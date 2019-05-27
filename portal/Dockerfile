FROM ubuntu:18.04
RUN apt-get update; apt-get install -y python3-pip 

COPY . /
WORKDIR /src
RUN pip3 install -r requirements.txt
CMD python3 portal.py


from flask import Flask, request
import requests
import redis
application = Flask(__name__)
r = redis.Redis(host='redis', port=6379, db=0)

@application.route('/')
def dashboard():
    #result = requests.get('http://dash-back:5001/hardware/').json()
    statuses = r.get('statuses')
    result = statuses.json()
    hardware = [
        '{} - {}: {}'.format(r['provider'], r['name'], r['availability'])
        for r in result
    ]
    # TODO: celery task here to signal dash-back update
    return '<br>'.join(hardware)


if __name__ == "__main__":
    application.run(host='0.0.0.0', port=5000)


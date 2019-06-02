from flask import Flask, request, jsonify
from flask_caching import Cache
import psycopg2
import time
import random
import os
application = Flask(__name__)

# Check Configuring Flask-Cache section for more details
cache = Cache(application,config={'CACHE_TYPE': 'simple'})

#db_name="dashboard"
#db_user="postgres"
db_name=os.getenv("AWS_DB_NAME")
db_user=os.getenv("AWS_DB_USER")
# docker secrets makes tmpfs file with cred
db_password_file=os.getenv("AWS_DB_PASS_FILE")
with open(db_password_file, "r") as myfile:
    theline=myfile.readlines()
#os.environ['AWS_DB_PASS'] = data[0]
#db_password=os.getenv("AWS_DB_PASS")
db_password=theline[0]

db_host=os.getenv("AWS_DB_HOST")
db_port=5432

def slow_process_to_calculate_availability(provider, name):
    time.sleep(5)
    return random.choice(['HIGH', 'MEDIUM', 'LOW'])

@cache.cached(timeout=50)
@application.route('/hardware/')
def hardware():
    con = psycopg2.connect(dbname=db_name, user=db_user, password=db_password, host=db_host, port=db_port)
    c = con.cursor()
    c.execute('SELECT * from hardware')
    # may be problematic if db is large
    row = c.fetchall()

    statuses = [
        {
            # primary key is index 0 in each row
            'provider': row[0][1:],
            'name': row[1][1:],
            'availability': slow_process_to_calculate_availability(
                row[0],
                row[1]
            ),
        }
# psycopg2 returns None
# for row in c.execute('SELECT * from hardware')

    ]

    con.close()

    return jsonify(statuses)


if __name__ == "__main__":
    application.run(host='0.0.0.0', port=5001)


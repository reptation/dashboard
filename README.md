
# Initial Setup
This example deploys a Flask app using Docker Swarm with PostgeSQL database on AWS infrastructure. The app infrastructure is in a VPC under a ALB load balancer. The example uses Terraform, Packer, and Bash scripting.  

The app is composed on two microservices, dash-front and dash-back. dash-front communicates to dash-back by DNS name:
```
    result = requests.get('http://dash-back:5001/hardware/').json()
```
There is a run.sh script that combines the packer and terraform initialization steps, though terraform requires yes to be entered in order to run 'terraform apply'. 

## Machine Image Creation
Packer is used to create an Amazon machine image (AMI). The AMI setup routine installs docker, pulls the app code and builds the dash-front and dash-back images which are subsequently pushed to dockerhub as build artifacts. The dash-back backend service uses a docker secret to handle database authentication. The backend hardware.py reads the docker secret at /var/run/aws_db

Before packer is run, the following variables must be present in the environment:

- AWS_DB_PASS
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_DEFAULT_REGION
- DOCKERHUB_USER (Dockerhub creds are only needed to push builds to the repo)
- DOCKERHUB_PASS


One way to accomplish this is to place the credentials into a secured store such as the cli tool "Pass", which depends on gpg encryption for its security. (Pass setup not covered here: https://www.passwordstore.org/) The variables can then be loaded into the environment by sourcing a script:
```
$ . ./infra/scripts/get-creds.sh
$ cat ./get-creds.sh
#!/bin/sh
export AWS_DB_PASS=$(pass aws/vpc/aws_db_pass)
... # other vars to be sourced

$ echo "${AWS_DB_PASS}"
@w3s0m3p@ssw0rd  # not really the password
```

The AWS_DB_PASS environment variable is converted into a packer user variable and then turned back into an environment variable which is passed to "docker secret create" at build time. This is added as a 'sensitive' variable and therefore Packer doesn't display it. For debug purposes, however, set -x can be added to the script and the variable's value will still be displayed in the printf statement that is fed to docker secrets. 

The Packer configuration uses the Shell provisioner, executing app-server-config.sh on a temporary remote instance. 

To create the AMI, cd to infrastucture/packer and run packer:
```
$ packer build webworker-dashboard.json
```

Packer does not overwrite machine images of the same name. To speed up AMI development, a convenience script is provided, ./infra/scripts/replace-packer-ami.sh, which uses the aws cli to get the AMI id matching the given name and deregistering it before calling packer:
```
$ ./replace-packer-ami.sh
De-registering AMI with name rescale-dashboard-ami-prod, if one exists
rescale-dashboard-ami-prod id is ami-0c026a148af4ecb35
Image deregistered
~/apps/rescale/src/devops-homework/infra/packer ~/apps/rescale/src/devops-homework/infra
amazon-ebs output will be in this color.

==> amazon-ebs: Prevalidating AMI Name: rescale-dashboard-ami-prod
... # more packer output
```

## Networking Infrastructure
The Terraform configuration creates a VPC, internet gateway, 3 subnets, route table association, autoscaling group and launch configuration. The AMI created by packer is fetched in a data source that filters by image name.

Like Packer, the Terraform configuration depends on the following environment variables being present:
- AWS_DB_PASS
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

run the deployment process:
```
$ cd infra/terraform
$ terraform init
$ terraform plan
$ terraform apply
```

## Database Setup
To setup the database, first create a db.t2.micro RDS instance and place it in the dashboard vpc. The db should not be accessible outside of the VPC (select no for public access). In this exercise the postgres superuser account was used to perform operations; in a production scenario the usage of this account would be more restricted. 

Next, create an EC2 instance in the VPC. In absence of a VPN gateway or some other way to access the private IP address configure this temporary instance as publicly accessible but per best practices configure the security group to allow ssh port 22 to be accessible only from your IP address. 

ssh to the VM and copy the database.sql file. Install postgresql on the instance to run psql. 

If there are authentication issues, you may need a line such as this to the bottom of /etc/postgresql/<VERSION>/main/pg_hba.conf:
```
host    all             all             rds-dash-vpc.cdwhodhtdtav.us-east-1.rds.amazonaws.com               md5
```
And restart the service:
```
$ sudo systemctl restart postgresql
```

The setup script can be run as follows (adjusting for hostname): 
```
$ psql -h rds-dash-vpc.cdwhodhtdtav.us-east-1.rds.amazonaws.com -U postgres -f database.sql
Password for user postgres:
CREATE DATABASE
psql (10.8 (Ubuntu 10.8-0ubuntu0.18.04.1), server 11.2)
WARNING: psql major version 10, server major version 11.
         Some psql features might not work.
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
You are now connected to database "dashboard" as user "postgres".
CREATE TABLE
INSERT 0 1
INSERT 0 1
```
Confirm the creation of db and tables, and initial data import:
```
$ psql -h rds-dash-vpc.cdwhodhtdtav.us-east-1.rds.amazonaws.com -U postgres
Password for user postgres:
psql (10.8 (Ubuntu 10.8-0ubuntu0.18.04.1), server 11.2)
WARNING: psql major version 10, server major version 11.
         Some psql features might not work.
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

postgres=> \c dashboard
psql (10.8 (Ubuntu 10.8-0ubuntu0.18.04.1), server 11.2)
WARNING: psql major version 10, server major version 11.
         Some psql features might not work.
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
You are now connected to database "dashboard" as user "postgres".
dashboard=> \dt
          List of relations
 Schema |   Name   | Type  |  Owner
--------+----------+-------+----------
 public | hardware | table | postgres
(1 row)

dashboard=> select * from hardware;
 id | provider | name
----+----------+-------
  1 | Amazon   | c5
  2 | Azure    | H16mr
```

# Updating the Configuration
Versioning is controlled by docker image tags with semantic versioning in the docker-compose.yml file. A simple continuous deployment system is implemented with a cron job set locally on the web servers that runs "git pull" followed by "docker stack deploy" against the master branch every 10 minutes. Changes to the master branch's version of docker-compose.yml will trigger new builds to be deployed on the web servers.



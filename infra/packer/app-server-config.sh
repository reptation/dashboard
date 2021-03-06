#!/bin/bash
#set -x

WEB_ROOT='/var/www/devops-homework'
APP_REPO='https://github.com/reptation/dashboard.git'
INFRA_REPO='https://github.com/reptation/scripts.git'
SUDO_USER="ubuntu"
SSH_DIR=/home/"${SUDO_USER}"/.ssh
cd /tmp/

# install docker, update software
apt-get update
git clone "${INFRA_REPO}" 
bash -x scripts/infrastructure/docker/docker-install.sh

# update without stalling out on ncurses menus
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

if [ -d "${WEB_ROOT}" ]; then
  rm -r "${WEB_ROOT}"
fi
mkdir -p "${WEB_ROOT}"
cd "${WEB_ROOT}"
git clone "${APP_REPO}" .

pushd portal
docker build -t dash-front:latest .
popd 

pushd hardware
docker build -t dash-back:latest .
popd

docker node ls
if [ $? == 1 ]; then
  docker swarm init
fi

# expectation is that packer provides AWS_DB_PASS env var
printf "${AWS_DB_PASS}" | docker secret create aws_db - 

# TODO pull images from private registry
# compose and external secrets not working together
#docker-compose build

docker stack deploy dashboard --compose-file ./docker-compose.yml

# bash construct to use 'latest' as default value if FRONT_TAG not set
docker tag dash-back:"${FRONT_TAG:-latest}" reptation/dash-back:"${FRONT_TAG:-latest}"
docker tag dash-front:"${BACK_TAG:-latest}" reptation/dash-front:"${BACK_TAG:-latest}"

# dockerhub complains about this 
docker login --username="${DOCKERHUB_USER}" --password="${DOCKERHUB_PASS}"

docker push reptation/dash-front:"${FRONT_TAG:-latest}" 
docker push reptation/dash-back:"${BACK_TAG:-latest}"  

cat << HERE > /etc/cron.d/update-stacks
*/10 * * * *  root  bash -x /usr/local/bin/poll-updates >> /var/log/dashboard-update.log
HERE

cat << HERE > /usr/local/bin/poll-updates.sh 
#!/bin/bash

WEB_ROOT="/var/www/devops-homework" 
cd $WEB_ROOT
git pull origin master
docker stack deploy dashboard --compose-file ./docker-compose.yml

HERE

cat << HERE >> /etc/docker/daemon.json
{
        "dns": ["1.1.1.1", "8.8.4.4", "8.8.8.8"]
}

HERE


###############################
# Creds for backend debugging #
###############################

mkdir -p "${SSH_DIR}"; chmod 700 "${SSH_DIR}"
cat << HERE  >> "${SSH_DIR}/authorized_keys"

ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCh+eCqUzNI/uPNUuDg2gel51xkQoXFM+aYqXnIgVig4ApiV3TQTgiuwYCyL7wR0nElSEvtIjS3V6ymvbYwvHpQ6BYdKBLTitdWlzcRuEfzwxjIiyjHQ6yrdnTxVXJd+NgwKZJqqnvbD1lVbTi0alc0Yy5FjhDKupKHPe+PVmg9vvLHg0pl+jNGwgRR+YYv6JDtU93+BBqK33ytFDe6qUJ3aFT5zZ36+bczIZJDEfhDSJ5nuji+nhUJdMEPfucWUGg3abZbSsUgHelKCEeZx3EUpuSHF0iOZT8BKTe68qXrHnHRriC1Y0DT5CD3A67da8QUkZF0hecSg4jgYMtJ1fjfSuxe5MSPgPcmMjGb1SSeuQEvqVz+QUKte2i+v4TRc697Mmo3JFsgyVVIYO2mLe0x661nknb/hOkatIarxhfpGyX2yoVjQBunsetCC/14FI0Jnqsr/0EeH1Yaw5xFfUBV0UfJ4bKXEKKE1uBBn20Dqf7cG8FfUiuzeEsqRxwmCpkZ72zdoVvjD6UsoMNQ6Ms/AEzkYjEXjdoOfK9n67D/aDLVXHcfX6Z6USuY+uCJ3heI0nJpiD4qqcbDUj2W3Lh8NomIJmLeM0ms6R4dwUIpUcJixg38S6T1c/z4m9jg/h0Rk1o/1RXo59+hXZD4w9e7lhnZHWFBowE+JUPD+YQnmQ== vagrant@jenkinsmaster

HERE
chown -R "${SUDO_USER}":"${SUDO_USER}" "${SSH_DIR}"



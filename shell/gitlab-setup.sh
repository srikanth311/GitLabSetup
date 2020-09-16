#!/bin/bash
# @skkodali

_usage()
{
    echo  "bash -x gitlab-setup.sh <S3_PATH>"
}
_setEnv()
{
    GITLAB_INITIAL_ROOT_PASSWD="changeme"
    SAMPLE_PROJECT_TOKEN="AbCdEfGyXZ"
    SAMPLE_PRJ_DIR="sample-node-app"
    DOCKER_USER=root

    MY_PUBLIC_IP=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
    echo $MY_PUBLIC_IP

    MY_PUBLIC_HOSTNAME=`curl http://169.254.169.254/latest/meta-data/public-hostname`
    echo ${MY_PUBLIC_HOSTNAME}

    ETC_HOSTS_FILE="/etc/hosts"

    URL="registry.srikanth.com"
    CERT_DIR_PATH="/etc/gitlab/trusted-certs/"
    CERT_KEY="registry.srikanth.com.key"
    CERT_CRT="registry.srikanth.com.crt"
    AWS=aws
    S3_COPY="s3 cp"
    GIT_CE_URL="https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh"
    BASH="/bin/bash"
    OPENSSL_OPTIONS="/C=US/ST=London/L=London/O=SrikanthInc/OU=DEV/CN=registry.srikanth.com"
    GITLAB_HOME="/etc/gitlab"
    GITLAB_CERTS_DIR=${GITLAB_HOME}/trusted-certs
    GITLAB_CONFIG_FILE="gitlab.rb"

    DOCKER_HOME="/etc/docker"

    GITLAB_RUNNER_HOME="/etc/gitlab-runner/"

}

_installPreRequiredPackages()
{
  sudo apt-get -y update
  sudo apt-get -y curl openssh-server postfix
}

_installGitLabCE()
{
  curl -sS ${GIT_CE_URL} | sudo ${BASH}
  sudo GITLAB_ROOT_EMAIL="example@example.com" GITLAB_ROOT_PASSWORD="changeme" apt-get install gitlab-ce -y
}

_setupSSLCerts()
{
  cd /etc/gitlab/
  sudo chmod -R 755 /etc/gitlab/trusted-certs/
  cd ${GITLAB_CERTS_DIR}
  sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${GITLAB_CERTS_DIR}/${CERT_KEY} -x509 -days 365 -out ${GITLAB_CERTS_DIR}/${CERT_CRT} -subj ${OPENSSL_OPTIONS}
  sudo chmod 600 ${GITLAB_CERTS_DIR}/${CERT_KEY}
  sudo chmod 600 ${GITLAB_CERTS_DIR}/${CERT_CRT}
}

_upLoadToS3Path()
{
  ${AWS} ${S3_COPY} ${GITLAB_CERTS_DIR}/${CERT_CRT} ${1}
}

_updateGitLabConfig()
{

  REGISTRY_URL_ENTRY="registry_external_url 'https:\/\/${URL}'"
  sudo sed -i "1i ${REGISTRY_URL_ENTRY}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}
  echo ${REGISTRY_URL_ENTRY}

  # gitlab_rails['registry_path'] = "/var/opt/gitlab/gitlab-rails/shared/registry"
  REGISTRY_PATH="gitlab_rails[\'registry_path\'] = \"\/var\/opt\/gitlab\/gitlab-rails\/shared\/registry\""
  echo ${REGISTRY_PATH}
  sudo sed -i "1i ${REGISTRY_PATH}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_ENABLE="registry[\'enable\'] = true"
  echo ${REGISTRY_ENABLE}
  sudo sed -i "1i ${REGISTRY_ENABLE}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_NGINX_ENABLE="registry_nginx[\'enable\'] = true"
  echo ${REGISTRY_NGINX_ENABLE}
  sudo sed -i "1i ${REGISTRY_NGINX_ENABLE}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_CRT="registry_nginx['ssl_certificate'] = \"${GITLAB_CERTS_DIR}/${CERT_CRT}\""
  echo ${REGISTRY_CRT}
  sudo sed -i "1i ${REGISTRY_CRT}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_KEY="registry_nginx['ssl_certificate_key'] = \"${GITLAB_CERTS_DIR}/${CERT_KEY}\""
  echo ${REGISTRY_KEY}
  sudo sed -i "1i ${REGISTRY_KEY}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  LFS_ENABLED="gitlab_rails[\'lfs_enabled\'] = true"
  echo ${LFS_ENABLED}
  sudo sed -i "1i ${LFS_ENABLED}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

}

_updateEtcHostsFile()
{
  ETC_HOSTS_ENTRY="${MY_PUBLIC_IP}    ${MY_PUBLIC_HOSTNAME}        ${URL}"
  sudo sed -i "1i ${ETC_HOSTS_ENTRY}" ${ETC_HOSTS_FILE}
}

_updateGitLabInitialPassword()
{
  sudo sed -i"" "s#\# gitlab_rails\['initial_root_password.*#gitlab_rails\['initial_root_password'\] = \""${GITLAB_INITIAL_ROOT_PASSWD}"\"#g" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}
}

_executeUpdateGitLabConfigSettings()
{
  # echo "hi"
  #sudo kill -9 `ps -u root -o pid=`
  #sudo gitlab-rake -s gitlab:setup force=yes DISABLE_DATABASE_ENVIRONMENT_CHECK=1
  #sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production GITLAB_ROOT_PASSWORD=yourpassword GITLAB_ROOT_EMAIL=youremail GITLAB_LICENSE_FILE="/path/to/license"
  sudo gitlab-ctl reconfigure
}

_createASampleProjectInGit()
{

  cd
  mkdir ${SAMPLE_PRJ_DIR}
  chmod -R 755 ${SAMPLE_PRJ_DIR}
  cd ${SAMPLE_PRJ_DIR}
  touch README.md
  git init
  git add .
  git commit -m "initial repo"
  sleep 60 # To make sure gitlab is up and running after reconfiguring.
  git push --set-upstream http://root:${GITLAB_INITIAL_ROOT_PASSWD}@${MY_PUBLIC_IP}/root/${SAMPLE_PRJ_DIR}.git master
}

_installAndSetupDocker()
{
  sudo apt-get -y update
  sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  sudo apt-get -y update
  sudo apt-get -y install docker-ce
  sudo usermod -aG docker ${USER}
  sudo usermod -aG docker ubuntu
}

_creatACopyOfCerts()
{
  cd;
  sudo mkdir -p ${DOCKER_HOME}/certs.d/
  sudo chown -R 755 ${DOCKER_HOME}/certs.d/
  cd ${DOCKER_HOME}/certs.d/
  sudo cp -r -p ${GITLAB_CERTS_DIR}/${CERT_CRT} ${DOCKER_HOME}/certs.d/
  sudo cp -r -p ${DOCKER_HOME}/certs.d/${CERT_CRT} ${DOCKER_HOME}/certs.d/ca.crt
  sudo chown -R 755 ${DOCKER_HOME}/certs.d/
  sudo cp -r -p ${DOCKER_HOME}/certs.d/ca.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
}

_reloadDockerService()
{
  sudo service docker reload
}

_loginToDocker()
{
  #sudo docker login registry.srikanth.com
  sudo docker login --username=${DOCKER_USER} --password=${GITLAB_INITIAL_ROOT_PASSWD} ${URL}
}

_setupGitLabRunner()
{
  cd;
  mkdir gitlab-runner
  cd gitlab-runner
  curl -LJO https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/gitlab-runner_amd64.deb
  sudo dpkg -i gitlab-runner_amd64.deb
  sudo gitlab-runner status
}

_registerRunner()
{
  # sudo gitlab-rails runner -e production "proj=Project.find_by(name:'${SAMPLE_PRJ_DIR}'); proj.runners_token='${SAMPLE_PROJECT_TOKEN}'; proj.save!"
  # sudo gitlab-rails runner -e production "proj=Project.find_by(name:'sample-node-app'); proj.runners_token='AbCdEfGyXZ'; proj.save!"
  GITLAB_TOKEN=`sudo gitlab-rails runner -e production "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"`
  GITLAB_SERVER="http://"${MY_PUBLIC_IP}"/"
  echo ${GITLAB_TOKEN}
  echo ${GITLAB_SERVER}
  sudo gitlab-runner register --non-interactive --url ${GITLAB_SERVER} --registration-token ${GITLAB_TOKEN} --executor "docker" --docker-image alpine:latest --description "docker-runner" --tag-list "docker,aws" --run-untagged="true" --locked="false" --access-level="not_protected"
}

_creatACopyOfCertsForRunner()
{
  sudo chmod -R 755 /etc/gitlab-runner/
  cd ${GITLAB_RUNNER_HOME}
  sudo mkdir -p config/certs
  cd ${GITLAB_RUNNER_HOME}/config/certs
  sudo cp -r -p ${GITLAB_CERTS_DIR}/${CERT_CRT} ${GITLAB_RUNNER_HOME}/config/certs/ca.crt
  #sudo mv ${GITLAB_RUNNER_HOME}/config/certs/${CERT_CRT} ${GITLAB_RUNNER_HOME}/config/certs/ca.crt
}

_updateConfigToml()
{
  sudo sed -i '/volumes.*/d' ${GITLAB_RUNNER_HOME}/config.toml
  sudo sed -i -e '$a\ \ \ \ volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock", "/etc/gitlab-runner/config/certs/ca.crt:/etc/gitlab-runner/config/certs/ca.crt"]' ${GITLAB_RUNNER_HOME}/config.toml
}

_restartGitLabRunner()
{
  sudo gitlab-runner status
  sudo gitlab-runner stop
  sudo gitlab-runner start
  sudo gitlab-runner status
}

_test()
{
  MAIL="admin@example.com"
  sudo gitlab-rails console production " user = User.where(id: 1).first user.password = '$GITLAB_INITIAL_ROOT_PASSWD' user.password_confirmation = '$GITLAB_INITIAL_ROOT_PASSWD' user.save!"
  sudo gitlab-ctl reconfigure
  #sudo gitlab-rails console production  user = User.where(id: 1).first user.password = 'secret_pass' user.password_confirmation = 'secret_pass' user.save!
}
################################################################################
################################# MAIN #########################################
################################################################################

_setEnv
_installPreRequiredPackages
_installGitLabCE
_setupSSLCerts
#_upLoadToS3Path
_updateGitLabConfig
_updateEtcHostsFile
_updateGitLabInitialPassword
_executeUpdateGitLabConfigSettings
_createASampleProjectInGit
_installAndSetupDocker
_creatACopyOfCerts
_reloadDockerService
_loginToDocker
_setupGitLabRunner
_registerRunner
_creatACopyOfCertsForRunner
_updateConfigToml
_restartGitLabRunner
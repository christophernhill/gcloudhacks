# 
# =====================================================================================
# Docker image specification for container that can be used to control
# GCP session. Doing this through docker provides a standard environment
# to script GCP commands. Image specification creates two volumes for
# holding GCP keys and ssh keys. These are used for interation with GCP VMs. GCP
# keys must be initiailized by executing docker run after image
# and associated persistent volumes have been created.
#
# To build image (and create the associated persistent volumes) by hand use commands:
#  export  GCP_SESSION_NAME=cnh-sess01
#  docker build -t ${GCP_SESSION_NAME} - < mygcecontroller.dockerfile 
#
# Once image is built to start by hand (and create assoiciated persistent volumes) use command:
#  docker run -P --rm -d --name ${GCP_SESSION_NAME} ${GCP_SESSION_NAME}
# 
# To initialize cloud keys and session profile do
#  export GCP_PROJECT=eaps-231119
#  export GCP_REGION=us-west1
#  export GCP_ZONE=us-west1-a
#  docker exec -it ${GCP_SESSION_NAME} gcloud auth login
#  docker exec -it ${GCP_SESSION_NAME} gcloud config set core/project   ${GCP_PROJECT}
#  docker exec -it ${GCP_SESSION_NAME} gcloud config set compute/region ${GCP_REGION}
#  docker exec -it ${GCP_SESSION_NAME} gcloud config set compute/zone   ${GCP_ZONE}
#
# To shut down
#  docker kill ${GCP_SESSION_NAME}
# =====================================================================================
#

FROM   google/cloud-sdk

RUN  apt-get -y update
RUN  apt-get -y install screen socat procps net-tools

RUN  mkdir /root/.ssh
RUN  ssh-keygen -f /root/.ssh/google_compute_engine -q -N "" < /dev/null

EXPOSE 8888

CMD  screen -Sdm s1; screen -Sdm s2; screen -Sdm s3; /bin/bash -c "sleep infinity"

FROM   google/cloud-sdk
VOLUME ["/root/.ssh"]

RUN  ssh-keygen -f /root/.ssh/google_compute_engine -q -N "" < /dev/null
CMD if [ -d /root/.config/gcloud/configurations ]; then echo already configured; else echo gcloud auth login; fi

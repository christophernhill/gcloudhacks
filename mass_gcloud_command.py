import logging

from time import sleep
from subprocess import Popen

logging.basicConfig(level=logging.INFO, format="[%(asctime)s.%(msecs)03d] %(funcName)s:%(levelname)s: %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
logger = logging.getLogger(__name__)

GPU_QUOTA = 4  # V100 quota on zones of interest.

PLUS_CMD = "/opt/julia/julia-1.1.0/bin/julia -E \"1+1\""
GIT_CLONE_CMD = "git clone https://github.com/climate-machine/Oceananigans.jl.git"
GIT_PULL_CMD = "cd Oceananigans.jl/; git pull; git checkout as/fc"
JL_ACTIVATE_CMD = "cd Oceananigans.jl/; /opt/julia/julia-1.1.0/bin/julia --project -e \"using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.build();\""
FREE_CONVECTION_CMD = "cd Oceananigans.jl/; nohup /opt/julia/julia-1.1.0/bin/julia --project examples/free_convection_mod.jl 75 0.01 128 6 8 1e-4 </dev/null >foo"

zones = ["us-west1-b", "us-central1-b", "asia-east1-c", "europe-west4-c"]

gpu_quotas = {
        "us-west1-b": 16,
        "us-central1-b": 4,
        "asia-east1-c": 1,
        "europe-west4-c": 1
        }


def spin_up_instances(name, username):
    n = 0
    instances = []
    for zone in zones:
        for _ in range(gpu_quotas[zone]):
            n = n + 1
            instance_name = name + str(n)
            logger.info("Spinning up instance {:s} on zone {:s}...".format(instance_name, zone))

            create_cmd = "gcloud --verbosity=info compute instances create " + instance_name + \
                         " --zone " + zone + \
                         " --accelerator=type=nvidia-tesla-v100,count=1 --maintenance-policy=TERMINATE" + \
                         " --boot-disk-size=500GB --local-ssd=interface=NVME" + \
                         " --image=julia-cuda --custom-cpu=4 --custom-memory=24GB" + \
                         " --scopes=storage-full"

            p = Popen(create_cmd, shell=True)
            instances.append({"name": instance_name, "zone": zone, "process": p})

    return instances


def poll_processes(instances, sleep_time=1):
    processes_done = 0
    while processes_done < len(instances):
        for instance in instances:
            if instance["process"].poll() is not None:
                processes_done += 1
        if processes_done < len(instances):
            logger.info("{:d}/{:d} processes done. Sleeping for {:f} seconds...".format(processes_done, len(instances), sleep_time))
            sleep(sleep_time)
        else:
            logger.info("{:d}/{:d} processes done.".format(processes_done, len(instances)))


def delete_instances(instances, username):
    for instance in instances:
        delete_cmd = "gcloud --verbosity=info --quiet compute instances delete " + \
                     instance["name"] + " --zone " + instance["zone"] + " --delete-disks all"

        logger.info("Deleting instance: {:s} on {:s}".format(instance["name"], instance["zone"]))
        p = Popen(delete_cmd, shell=True)


def run_gcloud_command(instance, username, command):
    base_cmd = "gcloud compute ssh"
    zone_arg = "--zone " + instance["zone"]
    location = username + "@" + instance["name"]
    full_cmd = base_cmd + " " + zone_arg + " " + location + " --command " + "\"" + command + "\""

    logger.info("Executing on {:s} [{:s}]: {:s}".format(instance["name"], instance["zone"], full_cmd))
    instance["process"] = Popen(full_cmd, shell=True)


def run_mass_gcloud_command(instances, username, command):
    for instance in instances:
        run_gcloud_command(instance["zone"], username, instance["name"], command)


if __name__ == "__main__":
    username = "alir"
    instances = spin_up_instances(name="convection", username="alir")
    delete_instances(instances, username)
    # run_mass_gcloud_command(instances, username, PLUS_CMD)

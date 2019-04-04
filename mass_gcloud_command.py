import logging

from subprocess import Popen

logging.basicConfig(level=logging.INFO, format="[%(asctime)s.%(msecs)03d] %(funcName)s:%(levelname)s: %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
logger = logging.getLogger(__name__)

GPU_QUOTA = 4  # V100 quota on zones of interest.

PLUS_CMD = "/opt/julia/julia-1.1.0/bin/julia -E \"1+1\""
GIT_CLONE_CMD = "git clone https://github.com/climate-machine/Oceananigans.jl.git"
GIT_PULL_CMD = "cd Oceananigans.jl/; git pull; git checkout as/fc"
JL_ACTIVATE_CMD = "cd Oceananigans.jl/; /opt/julia/julia-1.1.0/bin/julia --project -e \"using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.build();\""
FREE_CONVECTION_CMD = "cd Oceananigans.jl/; nohup /opt/julia/julia-1.1.0/bin/julia --project examples/free_convection_mod.jl 75 0.01 128 6 8 1e-4 </dev/null >foo"

zones = ["us-central1-b", "us-west1-b", "us-east1-b", "us-east4-b", "us-west2-b"]


def spin_up_instances(name, username):
    n = 0
    instances = []
    for zone in zones:
        for _ in range(GPU_QUOTA):
            n = n + 1
            instance_name = name + str(n) 
            logger.info("Spinning up instance {:s} on zone {:s}...".format(instance_name, zone))

            create_cmd = "gcloud --verbosity=info compute instances create " + instance_name + \
                         " --zone " + zone + \
                         " --accelerator=type=nvidia-tesla-v100,count=1 --maintenance-policy=TERMINATE" + \
                         " --boot-disk-size=500GB --local-ssd=interface=NVME" + \
                         " --image=julia-cuda --custom-cpu=4 --custom-memory=24GB"
            
            p = Popen(create_cmd, shell=True)

            instances.append({"name": instance_name, "zone": zone})

    # TODO? Wait until all instances have spun up? We can print periodic status updates.

    return instances


def delete_instances(instances, name, username):
    for instance in instances:
        delete_cmd = "gcloud --verbosity=info --quiet compute instances delete " + \
                     instance["name"] + " --zone " + instance["zone"] + " --delete-disks all"

        logger.info("Deleting instance: {:s} on {:s}".format(instance["name"], instance["zone"]))
        p = Popen(delete_cmd, shell=True)


def run_gcloud_command(zone, username, instance_name, command):
    base_cmd = r"gcloud compute ssh"
    zone_arg = r"--zone " + zone
    instance = username + "@" + instance_name
    full_cmd = base_cmd + " " + zone_arg + " " + instance + " --command " + "\"" + command + "\""
    
    logger.info("Executing on {:s} [{:s}]: {:s}".format(instance_name, zone, full_cmd))
    p = Popen(full_cmd, shell=True)


def run_mass_gcloud_command(instances, username, command):
    for instance in instances:
        run_gcloud_command(instance["zone"], username, instance["name"], command)


if __name__ == "__main__":
    username = "alir"
    instances = spin_up_instances(name="convection", username="alir")
    run_mass_gcloud_command(instances, username, PLUS_CMD)

import logging

from time import sleep
from subprocess import Popen

logging.basicConfig(level=logging.INFO, format="[%(asctime)s.%(msecs)03d] %(funcName)s:%(levelname)s: %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
logger = logging.getLogger(__name__)

JULIA = "/opt/julia/julia-1.1.0/bin/julia"

PLUS_CMD = JULIA + " -E \"1+1\""

MOUNT_GCSFUSE_CMD = "gcsfuse alir ~/bucket/"
BUCKET_WRITE_TEST = "touch bucket/\`hostname\`"
BUCKET_RM_TEST = "rm -v bucket/\`hostname\`"

GIT_CLONE_CMD = "rm -rf Oceananigans.jl/; git clone https://github.com/climate-machine/Oceananigans.jl.git"
JL_ACTIVATE_CMD = r"cd Oceananigans.jl/; " + JULIA + r" --project -e 'using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.build();'"
JL_ADD_PKG_CMD = r"cd Oceananigans.jl/; " + JULIA + r" --project -e 'using Pkg; Pkg.add(\"ArgParse\");'"

zones = ["us-west1-b", "us-central1-b", "asia-east1-c", "europe-west4-c"]

gpu_quotas = {
    "us-west1-b": 12,
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
                         " --image=julia-cuda --custom-cpu=2 --custom-memory=12GB" + \
                         " --scopes=storage-full"

            p = Popen(create_cmd, shell=True)
            instances.append({"name": instance_name, "zone": zone, "process": p})

    return instances


def poll_processes(instances, sleep_time=1):
    processes_done = 0
    while processes_done < len(instances):
        processes_done = 0
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
        run_gcloud_command(instance, username, command)


def run_free_convection_simulation(instance, username, N, Q, dTdz, kappa, dt, days, odir):
    cmd = "cd Oceananigans.jl/; nohup " + JULIA + " --project examples/free_convection.jl" + \
          " -N " + str(N) + " --heat-flux " + str(Q) + " --dTdz " + str(dTdz) + \
          " --diffusivity " + str(kappa) + " --dt " + str(dt) + " --days " + str(days) + \
          " --output-dir " + str(odir)
    run_gcloud_command(instance, username, cmd)

def run_wind_stress_simulation(instance, username, N, tau, Q, dTdz, kappa, dt, days, odir):
    cmd = "cd Oceananigans.jl/; nohup " + JULIA + " --project examples/wind_stress.jl" + \
          " -N " + str(N) + " --wind-stress" + str(tau) + " --heat-flux " + str(Q) + " --dTdz " + str(dTdz) + \
          " --diffusivity " + str(kappa) + " --dt " + str(dt) + " --days " + str(days) + \
          " --output-dir " + str(odir)
    run_gcloud_command(instance, username, cmd)

if __name__ == "__main__":
    username = "alir"

    instances = spin_up_instances(name="convection", username=username)
    poll_processes(instances)

    logger.info("We're going to wait for 5 minutes to make sure all instances are running...")
    sleep(300)

    free_convection_simulations = []
    for Q in [-10, -50, -100]:
        for dTdz in [0.01, 0.05, 0.005]:
            for kappa in [1e-3, 1e-4]:
                free_convection_simulations.append({
                    "N": 256,
                    "Q": Q,
                    "dTdz": dTdz,
                    "kappa": kappa,
                    "dt": 3 if abs(Q) < 75 else 2,
                    "days": 8,
                    "odir": "~/bucket/free_convection/"
                })

    for instance, s in zip(instances, free_convection_simulations):
        run_free_convection_simulation(instance, username, s["N"], s["Q"], s["dTdz"],
                                       s["kappa"], s["dt"], s["days"], s["odir"])

    wind_stress_simulations = []
    for Q in [10, 0, -75]:
        for dTdz in [0.01, 0.001]:
            for tau in [0, 0.04, 0.1]:
                wind_stress_simulations.append({
                    "N": 256,
                    "tau": tau,
                    "Q": Q,
                    "dTdz": dTdz,
                    "kappa": 1e-4,
                    "dt": 0.25,
                    "days": 6,
                    "odir": "~/bucket/free_convection/"
                })

    for instance, s in zip(instances, wind_stress_simulations):
        run_free_convection_simulation(instance, username, s["N"], s["tau"], s["Q"], s["dTdz"],
                                       s["kappa"], s["dt"], s["days"], s["odir"])

    # delete_instances(instances, username)
    # poll_processes(instances)
    # run_mass_gcloud_command(instances, username, "nvidia-smi")

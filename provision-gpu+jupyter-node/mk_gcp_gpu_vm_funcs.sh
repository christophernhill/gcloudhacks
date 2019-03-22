#!/bin/bash -xv

# Set a unique session name that is a valid DNS string
export GCP_SESSION_NAME=cnh-sess01

# Create the new session
function create_local_container {

 ## Create a Docker container with google cloud CLI tools and set authentication keys
 ## Container will be named according with value of GCP_SESSION_NAME
 ( docker volume create ${GCP_SESSION_NAME}-dotssh ) < /dev/null
 docker run -ti --name ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh google/cloud-sdk gcloud auth login
 ( docker run --rm --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh google/cloud-sdk ssh-keygen -f /root/.ssh/google_compute_engine -q -N "" ) < /dev/null
 ( docker run --rm --volumes-from ${GCP_SESSION_NAME} google/cloud-sdk gcloud config set core/project eaps-231119 ) </dev/null
 ( docker run --rm --volumes-from ${GCP_SESSION_NAME} google/cloud-sdk gcloud config set compute/region us-west1 ) </dev/null
 ( docker run --rm --volumes-from ${GCP_SESSION_NAME} google/cloud-sdk gcloud config set compute/zone us-west1-a ) </dev/null
 docker run --rm --volumes-from ${GCP_SESSION_NAME} -it google/cloud-sdk gcloud config list

}

function start_gcp_vm {
 
 ## Use container to execute gcloud API commands to launch a VM
 dr="docker run --rm --volumes-from ${GCP_SESSION_NAME} google/cloud-sdk gcloud compute"
 ( ${dr} instances create ${GCP_SESSION_NAME} --accelerator=type=nvidia-tesla-v100,count=1 --maintenance-policy=TERMINATE  --boot-disk-size=500GB --local-ssd=interface=NVME --image-project=centos-cloud --image-family=centos-7 --machine-type=n1-highcpu-4 ) </dev/null
 sleep 10

}

function configure_gcp_vm {

 ## Now have cointainer send gcloud commands to provision the VM 

 ## Start with base OHPC software setup
 dr="docker run --rm -it --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh google/cloud-sdk gcloud compute ssh cnh-google@${GCP_SESSION_NAME}"
 $dr -- sudo yum -y install wget perl epel-release nmap-ncat
 $dr -- sudo wget https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
 $dr -- sudo rpm -i ohpc-release-1.3-1.el7.x86_64.rpm
 $dr -- sudo /bin/rm ohpc-release-1.3-1.el7.x86_64.rpm

 $dr -- sudo yum -y install ohpc-base-compute lmod-ohpc EasyBuild-ohpc hwloc-ohpc spack-ohpc valgrind-ohpc
 $dr -- sudo yum -y install gnu8-compilers-ohpc openmpi3-gnu8-ohpc mpich-gnu8-ohpc ohpc-gnu8-perf-tools lmod-defaults-gnu8-openmpi3-ohpc
 $dr -- sudo yum -y install python-numpy-gnu8-ohpc   python-mpi4py-gnu8-openmpi3-ohpc   python-scipy-gnu8-openmpi3-ohpc
 $dr -- sudo yum -y install python34-numpy-gnu8-ohpc python34-mpi4py-gnu8-openmpi3-ohpc python34-scipy-gnu8-openmpi3-ohpc
 $dr -- sudo yum -y install phdf5-gnu8-openmpi3-ohpc pnetcdf-gnu8-openmpi3-ohpc.x86_64 hdf5-gnu8-ohpc
 $dr -- sudo yum -y install netcdf-cxx-gnu8-openmpi3-ohpc.x86_64 netcdf-fortran-gnu8-openmpi3-ohpc.x86_64 netcdf-gnu8-openmpi3-ohpc.x86_64
 $dr -- sudo yum -y install R-gnu8-ohpc gsl-gnu8-ohpc metis-gnu8-ohpc openblas-gnu8-ohpc plasma-gnu8-ohpc scotch-gnu8-ohpc superlu-gnu8-ohpc
 $dr -- sudo yum -y install boost-gnu8-openmpi3-ohpc fftw-gnu8-openmpi3-ohpc hypre-gnu8-openmpi3-ohpc mfem-gnu8-openmpi3-ohpc
 $dr -- sudo yum -y install mumps-gnu8-openmpi3-ohpc opencoarrays-gnu8-openmpi3-ohpc petsc-gnu8-openmpi3-ohpc ptscotch-gnu8-openmpi3-ohpc scalapack-gnu8-openmpi3-ohpc
 $dr -- sudo yum -y install slepc-gnu8-openmpi3-ohpc superlu_dist-gnu8-openmpi3-ohpc trilinos-gnu8-openmpi3-ohpc
 $dr -- sudo yum -y install hdf5 octave octave-'*' nco fuse sshfs
 $dr -- sudo yum -y install qtermwidget-qt5 qtermwidget-qt5-devel

 $dr -- sudo yum -y install python36 python36-pip python34-pip python-pip python34-devel
 $dr -- sudo pip2.7 install netCDF4
 $dr -- sudo pip3.4 install netCDF4
 $dr -- sudo pip3.6 install netCDF4 matplotlib

 ## Set up NVidia drives and toolkit
 # Set up
 # wget https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux
 # wget https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.105_418.39_linux.run
 # wget http://us.download.nvidia.com/XFree86/Linux-x86_64/418.43/NVIDIA-Linux-x86_64-418.43.run
 NVDNAME=NVIDIA-Linux-x86_64-418.43.run
 NVTNAME=cuda_10.1.105_418.39_linux.run
 NVDRIVER=scripts/nvidia/${NVDNAME}
 NVTOOLKIT=scripts/nvidia/${NVTNAME}
 # dr="docker run --rm -it --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh google/cloud-sdk gcloud compute ssh cnh-google@${GCP_SESSION_NAME}"
 dr="docker exec -it ${GCP_SESSION_NAME} google/cloud-sdk gcloud compute ssh cnh-google@${GCP_SESSION_NAME}"

 # Kernel driver
 $dr -- sudo yum -y groupinstall "Development tools"
 $dr -- sudo yum -y install kernel-devel
 # dc="docker run --rm -it --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh -v `pwd`/${NVDRIVER}:/tmp/${NVDNAME} google/cloud-sdk gcloud compute scp"
 # $dc /tmp/${NVDNAME} cnh-google@${GCP_SESSION_NAME}:/tmp
 $dr -- cd /tmp \; wget http://us.download.nvidia.com/XFree86/Linux-x86_64/418.43/${NVDNAME}
 $dr -- sudo chmod +x /tmp/${NVDNAME}
 $dr -- sudo /tmp/${NVDNAME} --silent
 # CUDA toolkit
 # dc="docker run --rm -it --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh -v `pwd`/${NVTOOLKIT}:/tmp/${NVTNAME} google/cloud-sdk gcloud compute scp"
 # $dc /tmp/${NVTNAME} cnh-google@${GCP_SESSION_NAME}:/tmp
 $dr -- cd /tmp \; wget https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/${NVTNAME}
 $dr -- sudo chmod +x /tmp/${NVTNAME}
 $dr -- sudo /tmp/${NVTNAME} --silent --toolkit --toolkitpath=/usr/local/cuda-10.1
 # Need to add /usr/local/cuda/bin to default search path

 ## Now setup Julia versions
 dr="docker run --rm -it --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh google/cloud-sdk gcloud compute ssh cnh-google@${GCP_SESSION_NAME}"
 $dr -- wget https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.0-linux-x86_64.tar.gz
 $dr -- wget https://julialang-s3.julialang.org/bin/linux/x64/1.0/julia-1.0.3-linux-x86_64.tar.gz
 $dr -- wget https://julialang-s3.julialang.org/bin/linux/x64/0.6/julia-0.6.4-linux-x86_64.tar.gz
 $dr -- sudo mkdir -p /opt/julia
 $dr -- cd /opt/julia \; sudo tar -xzvf /home/cnh-google/julia-1.1.0-linux-x86_64.tar.gz
 $dr -- cd /opt/julia \; sudo tar -xzvf /home/cnh-google/julia-1.0.3-linux-x86_64.tar.gz
 $dr -- cd /opt/julia \; sudo tar -xzvf /home/cnh-google/julia-0.6.4-linux-x86_64.tar.gz

 ## Now create user, conda setup and get github code
 $dr -- sudo adduser cnh
 $dr -- sudo -u cnh mkdir condas
 $dr -- sudo -i -u cnh 'bash -c "cd condas; wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh; pwd; ls -altr ; chmod +x  ./Miniconda3-latest-Linux-x86_64.sh"'
 $dr -- sudo -i -u cnh 'bash -c "./Miniconda3-latest-Linux-x86_64.sh -b -p `pwd`/miniconda3"'
 $dr -- sudo -i -u cnh 'bash -c "export PATH=`pwd`/miniconda3/bin:$PATH ; conda create -y -n defaultconda -c conda-forge python=3.7 dask distributed xarray jupyterlab mpi4py matplotlib basemap pillow astropy netCDF4"'
 $dr -- sudo -i -u cnh 'bash -c "export PATH=`pwd`/miniconda3/bin:$PATH ; source activate defaultconda ; conda install -y -c conda-forge jupyter_contrib_nbextensions jupyter_nbextensions_configurator octave_kernel"'
 $dr -- sudo -i -u cnh 'bash -c "export PATH=`pwd`/miniconda3/bin:$PATH ; source activate defaultconda ; /opt/julia/julia-1.1.0/bin/julia -e \"] add IJulia\""'
 # /opt/julia/julia-1.1.0/bin/julia
 #  ] add IJulia
 # 

 ## Now fuse mount directories (using some deamon to remount if needed)
 # ECCO from object store (need to add auth)
 # remote directories of engaging (for example)
}

function run_jlab{
 # Start a Jpuyter lab session in a screen on remote machine
 docker cp launch-jl.src ${GCP_SESSION_NAME}:.
 docker exec -it ${GCP_SESSION_NAME} gcloud compute scp launch-jl.src cnh-google@${GCP_SESSION_NAME}:
 docker exec -it ${GCP_SESSION_NAME} gcloud compute ssh --ssh-flag='-t' --ssh-flag='-L 8889:localhost:8888' --ssh-flag=-4 cnh-google@${GCP_SESSION_NAME} -- 'set -exv;screen -L -S jlab -d -m /bin/bash -c source\ launch-jl.src;screen -list'
}

function stop_jlab{
 docker exec -it ${GCP_SESSION_NAME} gcloud compute ssh --ssh-flag='-t' --ssh-flag='-L 8889:localhost:8888' --ssh-flag=-4 cnh-google@${GCP_SESSION_NAME} -- screen -XS jlab quit
}

# function run_jlab{
#   docker run -P --expose 8888 --rm -it --volumes-from ${GCP_SESSION_NAME} --mount type=volume,source=${GCP_SESSION_NAME}-dotssh,target=/root/.ssh google/cloud-sdk
#   apt-get update
#   apt-get -y install screen socat
#
#   SCREEN 1
#   socat -v TCP-LISTEN:8888,fork TCP:localhost:8889
#
#   SCREEN 2
#   gcloud compute ssh --ssh-flag='-L 8889:localhost:8888' --ssh-flag=-4 cnh-google@cnh-sess01
#    sudo bash
#    su -l cnh
#    cd condas
#    export PATH="`pwd`/miniconda3/bin:$PATH"
#    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${PATH}
#    source activate defaultconda
#    jupyter lab --no-browser --config=myconf.py --NotebookApp.notebook_dir=~ --notebook-dir=~
# }

# docker ports

function delete_gcp_vm {

 ## Shuts down and deletes the GCP VM with name GCP_SESSION_NAME
 echo y | docker run --rm --volumes-from ${GCP_SESSION_NAME} google/cloud-sdk gcloud compute instances delete ${GCP_SESSION_NAME}
}

function delete_local_container {

 ## Remove container artefacts with name from GCP_SESSION_NAME
 docker rm ${GCP_SESSION_NAME}
 docker volume rm ${GCP_SESSION_NAME}-dotssh

}

# create_local_container
# start_gcp_vm
# configure_gcp_vm
# delete_gcp_vm
# delete_local_container


### NEED TO SETUP SCREEN OR OTHER BACKGROUND PROCESS TO RUN
# apt-get install screen
# apt-get install net-tools
# apt-get install socat
# socat -v TCP-LISTEN:8888,fork TCP:localhost:8889
# and
# ( while [ 1 ]; do date; sleep 1; gcloud compute ssh --ssh-flag='-L 8889:localhost:30001' --ssh-flag='-4' cnh-google@cnh-sess01; done ) &
# on remote system
# also build ffmpeg

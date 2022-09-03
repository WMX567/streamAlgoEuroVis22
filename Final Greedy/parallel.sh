#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=100:00:00
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=200GB
#SBATCH --job-name=parallel
#SBATCH --mail-type=END
#SBATCH --mail-user=mw4355p@nyu.edu
#SBATCH --output=slurm_%j.out
##SBATCH -p nvidia

module purge

singularity exec --nv \
	    --overlay /scratch/mw4355/envh1/overlay-15GB-500K.ext3 \
	    /scratch/work/public/singularity/cuda11.1-cudnn8-devel-ubuntu18.04.sif \
	    /bin/bash -c "source /ext3/env.sh; nvcc -L/ext3/arrayfire/lib64/ -I/ext3/arrayfire/include final_greedy_version2.cu timer.cu -o test2 -lafcuda -lcusolver -lcudart -lcufft -lcublas; ./test2"
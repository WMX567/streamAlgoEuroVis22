#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=100:00:00
#SBATCH --mem-per-cpu=100GB
#SBATCH --job-name=single_pass
#SBATCH --mail-type=END
#SBATCH --mail-user=mw4355p@nyu.edu
#SBATCH --output=slurm_%j.out
##SBATCH -p nvidia

module purge

singularity exec \
	    --overlay /scratch/mw4355/env1/overlay-15GB-500K.ext3 \
	    /scratch/work/public/singularity/cuda11.1-cudnn8-devel-ubuntu18.04.sif \
	    /bin/bash -c "source /ext3/env.sh; conda activate run; python reconstruct.py"

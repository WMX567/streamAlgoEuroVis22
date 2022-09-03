#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=100:00:00
#SBATCH --mem-per-cpu=200GB
#SBATCH --job-name=euro_vis
#SBATCH --mail-type=END
#SBATCH --mail-user=mw4355p@nyu.edu
#SBATCH --output=slurm_%j.out
##SBATCH -p nvidia

module purge

g++ ar_dp.cpp timer.cpp -o test_ar_dp
./test_ar_dp

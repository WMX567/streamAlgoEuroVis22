## Streaming Approach to In Situ Selection of Key Time Steps for Time‐Varying Volume Data

This repository contains the author's implementation for the paper "Streaming Approach to In Situ Selection of Key Time Steps for Time‐Varying Volume Data", EuroVis 2022.

### Experiment Evironment and Dependencies
- 24-core 2.90 GHz Intel Xeon Platinum 8268 CPU
- 192GB RAM, nVidia Tesla RTX8000 GPU
- Linux Ubuntu OS
- ArrayFire Library (Matrix Operations)

### Datasets
- Vortex
- Isabel 
- TeraShake
- Radiation

The information on the original datasets can be found in our paper.

### Algorithms
- <strong> AR-DP </strong> <br />
  Accurate dynamic programming method gives globally optimal solutions to the restricted problem.
- <strong> Our DP </strong> <br />
  Our dynamic programming approach provides globally optimal solutions to the general key time steps selection problem.
- <strong> Basic Greedy </strong> <br />
  Our novel greedy algorithm is suitable for the online streaming and in situ settings.
- <strong> Final Greedy </strong> <br />
  Basic Greedy algorithm is dependent on the optimal cost. Since we do not have access to this value, we propose Final Greedy algorithm that avoids the dependency.
- <strong> Uniform Sampling </strong> <br />
  Sampling is basically the default method in common practice.

### Run Experiments
Please change the paths, information of the dataset, and the directory of codes according to your needs. The .sh files provide the method for how we run the experiments. For example, to run the Basic Greedy algorithm, you could refer to the following commands:
```bash
source /ext3/env.sh

nvcc -L/ext3/arrayfire/lib64/ -I/ext3/arrayfire/include basic_greedy.cu timer.cu \
-o test_greedy -lafcuda -lcusolver -lcudart -lcufft -lcublas

./test_greedy
```
time.h, time.cu and time.cpp could be found in the Helper folder.

 ### Citation
 ```
@inproceedings{wu2022streaming,
  title={Streaming Approach to In Situ Selection of Key Time Steps for Time-Varying Volume Data},
  author={Wu, Mengxi and Chiang, Yi-Jen and Musco, Christopher},
  booktitle={Computer Graphics Forum},
  volume={41},
  number={3},
  pages={309--320},
  year={2022},
  organization={Wiley Online Library}
}
```

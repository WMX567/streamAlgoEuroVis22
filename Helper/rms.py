import math
import cv2
import numpy as np

j = 44

our_path = "./Plots/isabelPlots/final_greedy/Isabel"+str(j)+".png"
ours = np.array(cv2.imread(our_path), dtype='int64')

sam_path = "./Plots/isabelPlots/sampling/Isabel_uni"+str(j)+".png"
sam = np.array(cv2.imread(sam_path), dtype='int64')

dp_path = "./Plots/isabelPlots/slow_dp/Isabel_dp"+str(j)+".png"
dp = np.array(cv2.imread(dp_path), dtype='int64')

ori_path = "./Plots/isabelPlots/original/Isabel_ori"+str(j)+".png"
ori = np.array(cv2.imread(ori_path), dtype='int64')

def mse(a, b):
	accu = 0
	s1,s2,s3 = a.shape
	for i in range(s1):
		for j in range(s2):
			for k in range(s3):
				accu += (a[i][j][k]-b[i][j][k])**2
	return math.sqrt(accu)

def o_(a):
	accu = 0
	s1,s2,s3 = a.shape
	for i in range(s1):
		for j in range(s2):
			for k in range(s3):
				accu += (a[i][j][k])**2
	return math.sqrt(accu)

 
ours_NRMSE = mse(ours, ori) / o_(ori)
print("ours: ", ours_NRMSE)

sam_NRMSE = mse(sam, ori) / o_(ori)
print("sam: ", sam_NRMSE)

dp_NRMSE = mse(dp, ori) / o_(ori)
print("dp: ", dp_NRMSE)




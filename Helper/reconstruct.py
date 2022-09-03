from re import I
import struct
from xml.dom.pulldom import SAX2DOM
import numpy as np

n = 600*248*248
N = 200

def get_num(i):
    if i % N == 0:
        return N
    elif i / N % 2 == 1:
        return (i % N) + (N+1)-2*(i % N)
    else:
        return i % N

def check_valid_Radiation(bT,n):
	for i in range(n):
		if bT[0][i] > 23000 or bT[0][i] < 70:
			bT[0][i] = 0
	return bT

def check_valid_Isabel(bT,n):
	for i in range(n):
		if bT[0][i] > 100 or bT[0][i] < -100:
			bT[0][i] = 100
	return bT

def read_Radiation(k):
    k -= 1
    if k < 10:
        num = "000" + str(k)
    elif k < 100:
        num = "00" + str(k)
    else:
        num= "0" + str(k)
    dir = "/scratch/mw4355/Radiation/"
    path = dir+"temperature"+num+".raw"
    file = open(path, 'rb')
    bT = np.array(struct.unpack('f'*n, file.read(4*n))).reshape(1,n)
    bT =  check_valid_Radiation(bT,n)
    return bT


def break_points_retrieve():
	N = 48
	M = N*N

	file1 = open('./Results/dp_break_point_Isabel.bin','rb')
	br_save = struct.unpack('i'*M, file1.read(4*M))
	breakpoints = np.zeros((N,N))
	index = 0
	for i in range(N):
		for j in range(N):
			breakpoints[i][j] = br_save[index]
			index += 1

	solu = []
	K = 13
	temp = 47
	for k in range(K, 0,-1):
		solu.append(int(breakpoints[temp][k]))
		temp = int(breakpoints[temp][k])
	solu.append(1)
	solu.reverse()
	solu.append(48)
	return solu

def read_Isabel(k):
    if k < 10:
        num = "0"+str(k)
    else:
        num = str(k)
    dir =  "/scratch/mw4355/Isabel/"
    path = dir+"TCf"+num+"converted.bin"
    file = open(path, 'rb')
    bT = np.array(struct.unpack('f'*n, file.read(4*n))).reshape(1,n)
    bT = check_valid_Isabel(bT, n)
    return bT

read_func = read_Radiation

def reconstruct(start, end):
    num = None
    a = np.ones((2,1))
    a[0][0] = start
    ATA = np.dot(a,a.T)
    num = get_num(start)
    bT = read_func(num)
    ATB = np.dot(a, bT)

    for i in range(start+1,end+1):
        num = get_num(i)
        bT = read_func(num)
        a[0][0] = i
        ATB += np.dot(a,bT)
        ATA += np.dot(a,a.T)

    ATA_inv = np.linalg.inv(ATA)
    coef = np.dot(ATA_inv, ATB)
    return coef

def save_file(file_path, val):
    file = open(file_path,'wb')
    myfmt='f'*len(val[0])
    bin_val=struct.pack(myfmt,*val[0])
    file.write(bin_val)
    file.close()

def sampling(start, end):
    num = get_num(start)
    s = read_func(num)
    num = get_num(end)
    e = read_func(num)
    slop = (s-e)/(start-end)
    intercept = s - slop*start
    return slop, intercept


def origin(j):
    num = get_num(j)
    bT = read_func(num)
    return bT

def select(start, end, ind):
    best_score = 0
    best_index = -1
    coef = reconstruct(start, end)
    slop, intercept = sampling(ind[0], ind[1])
    a = np.ones((2,1))
    for i in range(max(start, ind[0]+1), min(end+1, ind[1])):
        a[0][0] = i
        ours = np.dot(a.T,coef)
        sam = i*slop + intercept
        bT = origin(i)
        ours_loss = np.linalg.norm(ours[0]-bT[0])
        sam_loss = np.linalg.norm(sam[0]-bT[0])
        if sam_loss - ours_loss > best_score:
            best_score = ours_loss-sam_loss
            best_index = i
    if best_index == -1:
        print("Not Found")
        return
    a[0][0] = best_index
    ours = np.dot(a.T, coef)
    file_path = "./Isabel"+ str(best_index)+".bin"
    save_file(file_path, ours)
    sam = best_index*slop + intercept
    file_path = "./Isabel_uni"+str(best_index)+".bin"
    save_file(file_path, sam)
    ori = origin(best_index)
    file_path = "./Isabel_ori"+ str(best_index)+".bin"
    save_file(file_path, ori)


# inds = [[1, 8], [8, 15], [8, 15], [15, 22],[22,29],[29,38],[38,45]]

# select(1, 6, inds[0])
# select(7, 11, inds[1])
# select(12, 16, inds[2])
# select(17, 23, inds[3])
# select(24, 30, inds[4])
# select(31, 38, inds[5])
# select(39, 48, inds[6])

# solu = break_points_retrieve()
# print(solu)


inds = [[1,10],[46,55],[145,154],[181,190]]
indices = [7,48,151,186]

for i in range(len(indices)):
    slop, intercept = sampling(inds[i][0], inds[i][1])
    dp = indices[i]*slop + intercept
    file_path = "./Radiaion_uni"+str(indices[i])+".bin"
    save_file(file_path, dp)

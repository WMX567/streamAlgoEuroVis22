import numpy as np
import struct

def build(in_file, outfile):

    outf = open(outfile,'w')

    outstr=[]

    outstr.append('# vtk DataFile Version 3.0\n')
    outstr.append(outfile[:-4]+'\n')
    outstr.append('BINARY\n')
    outstr.append('DATASET STRUCTURED_POINTS\n')
    outstr.append('DIMENSIONS 600 248 248\n')
    outstr.append('ORIGIN 0 0 0 \n')
    outstr.append('SPACING 1 1 1 \n')
    outstr.append('POINT_DATA 36902400 \n')
    outstr.append('SCALARS temperature float\n')
    outstr.append('LOOKUP_TABLE default\n')

    outf.writelines(outstr)
    outf.close()

    f = open(in_file, "rb")
    raw = f.read(36902400*4)
    f.close()
    
    outf = open(outfile,'ab')
    outf.write(raw)
    outf.close()
        

if __name__ == '__main__':
    ind = [7,48,151,186]
    for x in ind:
        in_file = "Isabel/ori_"+str(x)+".bin"
        out_file = "Isabel/ori_"+str(x)+".vtk"
        build(in_file, out_file)
    
    for x in ind:
        in_file = "Radiation/uni_"+str(x)+".bin"
        out_file = "Radiation/uni_"+str(x)+".vtk"
        build(in_file, out_file)
    
    for x in ind:
        in_file = "Isabel/fb_"+str(x)+".bin"
        out_file = "Isabel/fb_"+str(x)+".vtk"
        build(in_file, out_file)

    for x in ind:
        in_file = "Isabel/dp_"+str(x)+".bin"
        out_file = "Isabel/dp_"+str(x)+".vtk"
        build(in_file, out_file)

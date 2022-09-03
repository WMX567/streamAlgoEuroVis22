#include <iostream>  
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <fstream>
#include <algorithm> 
#include <unistd.h>

using namespace std;

const int N = 1600;
const int n = 200;
const string dir = "/scratch/mw4355/Radiation/";
const int dim = 600*248*248;
double time_io = 0;

//******************************* Out-of Core ***********************
void readData_Vortex(float* s, int i){
    FILE * pFile;
    double time = 0;
    string num;

    if(i+1 == 65){
        num = to_string(64);
    }else{
        num = to_string(i+1);
    }
    string path = dir+"vorts"+num+"converted.data";

    pFile = fopen(path.c_str(),"rb");
    fread(s, dim*sizeof(float), 1, pFile);

    fclose(pFile);
}

void readData_Isabel(float* s, int i){
    FILE * pFile;
    double time = 0;
    string num;

    if (i+1 < 10)
        num = to_string(0)+to_string(i+1);
    else
        num= to_string(i+1);

    string path = dir+"TCf"+num+"converted.bin";

    pFile = fopen(path.c_str(),"rb");
    fread(s, dim*sizeof(float), 1, pFile);

    for(int j = 0; j < dim; j++){
        if(s[j] > 100 or s[j] < -100)
            s[j] = 100;
    }

    fclose(pFile);
}

void readData_Radiation(float* s, int file_num){
    string num;
    FILE * pFile;
    file_num -= 1;
    if (file_num < 10){
        num = "000" + to_string(file_num);
    }else if(file_num < 100){
        num = "00" + to_string(file_num);
    }else{
        num= "0" + to_string(file_num);
    }
    string path = dir+"temperature"+num+".raw";

    pFile = fopen(path.c_str(),"rb");
    fread(s, dim*sizeof(float), 1, pFile);
    for(int i = 0; i < dim; i++){
        if(s[i] > 23000 or s[i] < 70){
            s[i] = 0;
        }
    }
    fclose(pFile);
}

void readData_TeraShake(float* s, int file_num){
    FILE* pFile;
    string path = dir + "TeraShake" + to_string(file_num) + ".bin";
    pFile = fopen(path.c_str(),"rb");
    fread(s, dim*sizeof(float), 1, pFile);
    fclose(pFile);
}
//************************** Out-of Core **********************

int get_k(int i){
    if(i % n == 0){
        return n;
    }else if (i / n % 2 == 1){
        return (i % n) + (n+1)-2*(i % n);
    }else{
        return i % n;
    }
}

double compute_loss(int start, int end){
    double slop, intercept,loss, c, a, b;
    float* s = new float[dim];
    int k = get_k(start);
    readData_Radiation(s, k); //
    float* e = new float[dim];
    k = get_k(end);
    readData_Radiation(e, k);  //
    float* x = new float[dim];

    for(int i=start+1; i < end; i++){
        k = get_k(i);
        readData_Radiation(x, k);
        for(int m = 0; m < dim; m++){
             a = s[m];
             b = e[m];
             c = x[m];
             slop = (a-b)/(start-end);
             intercept = a - slop*start;
             loss += (c-(slop*i+intercept))*(c-(slop*i+intercept));
        }
    }

    delete [] s;
    delete [] e;
    delete [] x;
    return loss;
}


int main(){
    int seg = 0;
    double acc_loss = 0;
    int space = 0;
    string path1 = "./uniform_loss_Radiation_1600_part1.bin";
    string path2 = "./seg_Uniform_Radiation_1600_part1.bin";
    FILE * out1 = fopen(path1.c_str(), "w");
    FILE * out2 = fopen(path2.c_str(),"w");
    int spaces [11] = {1600, 800, 600, 500, 400, 320, 260, 227, 200, 178, 160}; 

    // Change Fast
    for(int i = 0; i < 11; ++i){
        for(int i = 1; i < N; i+=spaces[i]){
            acc_loss += compute_loss(i,min(i+spaces[i], N));
        }
        seg = int(N /(spaces[i]+1));
        if(1.0*N/(spaces[i]+1) > seg){
            seg += 1;
        }
        fwrite(&acc_loss, sizeof(double), 1, out1);
        fwrite(&seg, sizeof(int), 1, out2);
        cout << "Space: " << spaces[i] << endl;
        acc_loss = 0;
    }

    cout << "Finish!" << endl;
    fclose(out1);
    fclose(out2);
    return 0;
}


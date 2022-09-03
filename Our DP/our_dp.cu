#include <iostream>  
#include <math.h>
#include <arrayfire.h>
#include <stdio.h>
#include <stdlib.h>
#include "timer.h"
#include <fstream>
#include <algorithm> 
#include <chrono> 
#include <unistd.h>

using namespace af;
using namespace std;
using namespace std::chrono;

const int N = 48;
const int dim = 500*500*100;
double time_io = 0;
string dir = "/scratch/mw4355/Isabel/";
//********************************* In-Core ******************************************
auto data = new float[N][dim];

af::array readData_Radiation(int file_num){
    string num;
    FILE * pFile;

    file_num = file_num-1;
    if (file_num < 10){
        num = "000" + to_string(file_num);
    }else if(file_num < 100){
        num = "00" + to_string(file_num);
    }else{
        num= "0" + to_string(file_num);
    }
    string path = dir+"temperature"+num+".raw";
    float* data = new float[dim];
    TimerStart(0);
    pFile = fopen(path.c_str(),"rb");
    fread(data, dim*sizeof(float), 1, pFile);
    TimerStop(0);
    time_io +=  TimerGetRTime(0);
    double* data_ = new double[dim];
    for(int i = 0; i < dim; i++){
        if(data[i] > 23000 or data[i] < 70){
            data_[i] = 0;
        }else{
            data_[i] = data[i];
        }
    }
    fclose(pFile);
    af::array oneStep(1, dim, data_);
    delete[] data;
    delete[] data_;
    return oneStep;
}

array readData_TeraShake(int file_num){
    FILE* pFile;
    string path = dir + "TeraShake" + to_string(file_num) + ".bin";
    float* data = new float[dim];
    TimerStart(0);
    pFile = fopen(path.c_str(),"rb");
    fread(data, dim*sizeof(float), 1, pFile);
    TimerStop(0);
    time_io +=  TimerGetRTime(0);
    double* data_ = new double[dim];
    for(int i = 0; i < dim; i++){
        data_[i] = data[i];
    }
    fclose(pFile);
    array oneStep(1, dim, data_);
    delete[] data;
    delete[] data_;
    return oneStep;
}

void readData_Isabel(){
    FILE * pFile;
    string num;
    float* d = new float[dim];

    for(int i = 0; i < N; ++i){
        if (i+1 < 10)
            num = to_string(0)+to_string(i+1);
        else
            num= to_string(i+1);

        string path = dir+"TCf"+num+"converted.bin";
        TimerStart(0);
        pFile = fopen(path.c_str(),"rb");
        fread(d, dim*sizeof(float), 1, pFile);
        TimerStop(0);
        time_io +=  TimerGetRTime(0);

        for(int j = 0; j < dim; j++){
            data[i][j] = d[j];
            if(d[j] > 100 or d[j] < -100)
                data[i][j] = 100;
        }

        fclose(pFile);
    }
    delete [] d;
}

array getOne_Isabel(int i){
    double* data_ = new double[dim];
    for(int j = 0; j < dim; j++){
        data_[j] = data[i][j];
    }
    array oneStep(1, dim, data_);
    delete [] data_;
    return oneStep;
}

void readData_Vortex(){
    FILE * pFile;
    double time = 0;
    string num;
    float* d = new float[dim];

    for(int i = 0; i < N; ++i){
        if(i+1 == 65){
            num = to_string(64);
        }else{
            num = to_string(i+1);
        }
        string path = dir+"vorts"+num+"converted.data";
        TimerStart(0);
        pFile = fopen(path.c_str(),"rb");
        fread(d, dim*sizeof(float), 1, pFile);
        TimerStop(0);
        time_io +=  TimerGetRTime(0);

        for(int j = 0; j < dim; j++){
            data[i][j] = d[j];
        }

        fclose(pFile);
    }
    delete [] d;
}

array getOne_Vortex(int i){
    double* data_ = new double[dim];
    for(int j = 0; j < dim; j++){
        if(i+1 == 65){data_[j] = data[i-1][j];}
        else{data_[j] = data[i][j];}
    }
    array oneStep(1, dim, data_);
    delete [] data_;
    return oneStep;
}
//********************************** In-Core *****************************************

double loss(array& ATB, array& ATA, array& bT, 
    array& a, double& tr_BTB, bool two_near){
    int d = bT.dims(1);
    double temp;
    double* inv_CPU_1 = new double[2];
    double* inv_CPU_2 = new double[2];
    double* ATB_CPU_1 = new double[d];
    double* ATB_CPU_2 = new double[d];
    temp = norm(bT);
    tr_BTB += temp*temp;
    ATB += matmul(a, bT);
    ATA += matmul(a, transpose(a));
    if (two_near){return 0;}
    array ATA_inv = inverse(ATA);
    ATB(0, span).host(ATB_CPU_1);
    ATB(1, span).host(ATB_CPU_2);
    ATA_inv(0, span).host(inv_CPU_1);
    ATA_inv(1, span).host(inv_CPU_2);
    double tr;
    for(int i = 0; i < d; i++){
        if(i == 0){
            tr = ATB_CPU_1[i]*(ATB_CPU_1[i]*inv_CPU_1[0] + inv_CPU_2[0]*ATB_CPU_2[i]);
            tr += ATB_CPU_2[i]*(ATB_CPU_1[i]*inv_CPU_1[1] + inv_CPU_2[1]*ATB_CPU_2[i]);
            continue;
        }
        tr += ATB_CPU_1[i]*(ATB_CPU_1[i]*inv_CPU_1[0] + inv_CPU_2[0]*ATB_CPU_2[i]);
        tr += ATB_CPU_2[i]*(ATB_CPU_1[i]*inv_CPU_1[1] + inv_CPU_2[1]*ATB_CPU_2[i]);
    }
    delete [] ATB_CPU_1;
    delete [] ATB_CPU_2;
    delete [] inv_CPU_1;
    delete [] inv_CPU_2;
    return tr_BTB - tr;
}

void compute_E(double (&E)[N+1][N+1], string dir){
    array ATA, ATB, a, bT;
    double tr_BTB;
    //Compute E
    for(int i=1; i < N+1; i++){
        a = constant(1,2,1,f64);
        a(0,0) = i;
        //bT = getOne_Vortex(i,dir);
        bT = getOne_Isabel(i-1);
        ATA = matmul(a, transpose(a));
        ATB = matmul(a, bT);
        tr_BTB = norm(bT);
        tr_BTB *= tr_BTB;
        for(int j=i; j<N+1; j++){
            if (j == i){E[i][j] = 0; continue;}
            a(0,0) = j;
            bT = getOne_Isabel(j-1);
            if (j == i+1){E[i][j] = loss(ATB, ATA, bT, a, tr_BTB, true);}
            else{E[i][j] = loss(ATB, ATA, bT, a, tr_BTB, false);}
        }
    }
}

void dp_solu(double (&E)[N+1][N+1], double (&E_s)[N+1][N+1], int (&solu)[N+1][N+1]){
    for(int k=1; k<N+1; k++){
        for(int i=k;i<N+1; i++){
            if(k == 1){
                E_s[i][1] = E[1][i];
                solu[i][1] = i;
                continue;
            }
            for(int j=k; j < i+1; j++){
                if(j == k){ 
                    E_s[i][k] = E_s[j-1][k-1]+E[j][i];
                    solu[i][k] = j-1;
                }
                else{ 
                    if(E_s[i][k] > E_s[j-1][k-1]+E[j][i]){
                        E_s[i][k] = E_s[j-1][k-1]+E[j][i];
                        solu[i][k] = j-1;
                    }
                }
            }
        }
    }
}

int main(void){
    
    TimerStart(3);
    double E[N+1][N+1];
    double E_s[N+1][N+1];
    int solu[N+1][N+1];

    setDevice(0);
    readData_Isabel();

    TimerStart(1);
    compute_E(E,dir);
    TimerStop(1);
    cout << "Preprocess Time:" << TimerGetRTime(1) << endl;

    auto start = high_resolution_clock::now();
    dp_solu(E, E_s, solu);
    auto stop = high_resolution_clock::now();
    auto duration = duration_cast<microseconds>(stop - start); 
    cout << "DP Time:" << duration.count() << endl;
    TimerStop(3);
    cout << "Total Runtime: "<< TimerGetRTime(3) << endl;
    cout << "IO Time: " <<  time_io << endl;
    
    return 0;
}

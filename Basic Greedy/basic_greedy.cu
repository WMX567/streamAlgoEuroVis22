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
#include <limits>
#include <set>
using namespace af;
using namespace std;

const int N = 200;  //Number of Data Samples
const string dir = "/scratch/mw4355/Radiation/";  //Path of the Dataset
const int dim =600*248*248;  //Dimension of Each Data Sample
double time_io = 0;

//+++++++++++++++++++++++++ Reading Functions Area +++++++++++++++++++++++++++++
array readData_Isabel(int file_num){
    string num;
    FILE * pFile;
    if (file_num < 10){
        num = "0"+to_string(file_num);
    }else{
        num=to_string(file_num);
    }
    string path = dir+"TCf"+num+"converted.bin";
    float* data = new float[dim];

    TimerStart(0);
    pFile = fopen(path.c_str(),"rb");
    fread(data, dim*sizeof(float), 1, pFile);
    TimerStop(0);
    time_io += TimerGetRTime(0);

    double* data_ = new double[dim];
    for(int i = 0; i < dim; i++){
        if(data[i] > 100 or data[i] < -100){
            data_[i] = 100;
        }
        else{
            data_[i] = data[i];
        }
    }
    fclose(pFile);
    array oneStep(1, dim, data_);
    delete[] data;
    delete[] data_;
    return oneStep;
}

array readData_Vortex(int file_num){
    string num;
    FILE * pFile;
    if(file_num == 65){
        num = to_string(64);
    }else if(file_num == 24){
        num = to_string(25);
    }else{
        num = to_string(file_num);
    }
    string path = dir+"vorts"+num+"converted.data";
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

array readData_Radiation(int file_num){
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
    array oneStep(1, dim, data_);
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
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//+++++++++++++++++++++++++ Algorithm ++++++++++++++++++++++++++++++++++++++++
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


void valid_range(double & upper, double & lower){

    array a, bT, ATA_1, ATB_1, ATA, ATB;
    double cur_loss1 = numeric_limits<double>::infinity();
    int seg1 = 0;
    double tr_BTB[2];

    a = constant(1,2,1,f64);
    bT = readData_TeraShake(1);
    ATA = matmul(a,transpose(a));
    ATB = matmul(a,bT);
    tr_BTB[1] = norm(bT);
    tr_BTB[1] *= tr_BTB[1];

    ATA_1 = matmul(a,transpose(a));
    ATB_1 = matmul(a,bT);
    tr_BTB[0] = norm(bT);
    tr_BTB[0] *= tr_BTB[0];
    seg1 = 1;

    double t = 0.0;
    double s = 0.0;
    bool is_set = false;

    for(int i = 1; i < N+1; ++i){

        a(0,0) = i;
        bT = readData_TeraShake(i);
        s = norm(bT);
        if(s != 0 && is_set == false){
            is_set = true;
            t = s * s * 10000000000000000;
            cout << "Threshold: " << t << endl;
        }

        if(i == 1){
            continue;
        }

        if(seg1 < 3){
            cur_loss1 = loss(ATB_1, ATA_1, bT, a, tr_BTB[0], true);
            seg1 += 1;
        }else{
            cur_loss1 = loss(ATB_1, ATA_1, bT, a, tr_BTB[0], false);
            seg1 += 1;
        }

        if(i < 3){
            upper=loss(ATB, ATA, bT, a, tr_BTB[1], true);
        }else{
            upper=loss(ATB, ATA, bT, a, tr_BTB[1], false);
        }

        if (t == 0){
            continue;
        }

        if(cur_loss1 > t){

            lower = min(lower, cur_loss1);
            ATA_1 = matmul(a,transpose(a));
            ATB_1 = matmul(a,bT);
            tr_BTB[0] = norm(bT);
            tr_BTB[0] *= tr_BTB[0];
            seg1 = 1;
        }
    }

}


double greedy_construct(double alpha, int& num_segment){

    array a, bT, ATA, ATB;
    int num_points = 0;
    double acc_loss = 0;
    double cur_loss = 0;
    double prev_loss = 0;
    double tr_BTB = 0;
    vector<int> solu;

    a = constant(1,2,1,f64);
    bT = readData_Radiation(1);
    ATA = matmul(a,transpose(a));
    ATB = matmul(a,bT);
    tr_BTB = norm(bT);
    tr_BTB *= tr_BTB;
    num_points = 1;

    for(int i=2;i<N+1;i++){
        
        a(0,0) = i;
        bT = readData_Radiation(i);
        num_points += 1;

        if (num_points == 2){
            cur_loss=loss(ATB, ATA, bT, a, tr_BTB, true);
        }
        else{
            cur_loss=loss(ATB, ATA, bT, a, tr_BTB, false);
        }

        if(cur_loss > alpha or i == N){
            if(i == N){
                acc_loss += cur_loss;
                continue;
            }
            if(i < N){
                acc_loss += prev_loss;
                solu.push_back(i-1);
            }
            ATA = matmul(a, transpose(a));
            ATB = matmul(a, bT);
            tr_BTB = norm(bT);
            tr_BTB *= tr_BTB;
            cur_loss = 0;
            prev_loss = 0;
            num_points = 1;
        }else{
            prev_loss = cur_loss;
            
        }
    }

    for(auto iter = solu.begin() ; iter != solu.end() ; ++iter){      
        cout<<*iter<<" ";
    }
    cout<<endl;

    return acc_loss;
}

int intlog(double base, double x) {
    return (int)(log(x) / log(base));
}

int main(void){

    setDevice(0);
    int num = 0;
    double alpha = 0;
    double acc_loss = 0;
    double base = 5.0;

    alpha = pow(base, 21);
    cout <<"Therashold: " << alpha << endl;
    acc_loss = greedy_construct(alpha, num);
    cout <<"Loss: "<<acc_loss << endl;
    cout <<"Number of Segments: "<< num << endl;
    
    return 0;
}

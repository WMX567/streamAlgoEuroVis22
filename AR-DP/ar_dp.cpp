#include <iostream>  
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "timer.h"
#include <fstream>
#include <algorithm> 
#include <chrono> 
#include <unistd.h>

using namespace std;
using namespace std::chrono;

const int N = 48;
const int dim = 500*500*100;

//********************************* In-Core ******************************************
auto data = new float[N][dim];

void readData_Isabel(string dir){
    FILE * pFile;
    double time = 0;
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
        time +=  TimerGetRTime(0);

        for(int j = 0; j < dim; j++){
            data[i][j] = d[j];
            if(d[j] > 100 or d[j] < -100)
                data[i][j] = 100;
        }

        fclose(pFile);
    }
    cout << "I/O Time:" << time << endl;
    delete [] d;
}

void readData_Vortex(string dir){
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
        time +=  TimerGetRTime(0);

        for(int j = 0; j < dim; j++){
            data[i][j] = d[j];
        }

        fclose(pFile);
    }
    cout << "I/O Time:" << time << endl;
    delete [] d;
}

//********************************** In-Core *****************************************
void compute_E(double (&E)[N+1][N+1], string dir){
    double slop, intercept,loss, c, a, b;
    //Compute E
    for(int i=1; i < N+1; i++){
        for(int j=i; j<N+1; j++){
            if (j == i or j == i+1){E[i][j] = 0; continue;}
            loss = 0;
            for(int k=i; k <=j; ++k){
                for(int m=0; m < dim; ++m){
                    a = data[i-1][m];
                    b = data[j-1][m];
                    c = data[k-1][m];
                    slop = (a-b)/(i-j);
                    intercept = a - slop*i;
                    loss += (c-(slop*k+intercept))*(c-(slop*k+intercept));
                }
            }
            E[i][j] = loss;
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

    string dir = "/scratch/mw4355/Isabel/";

    //readData_Vortex();
    readData_Isabel(dir);

    TimerStart(1);
    compute_E(E, dir);
    TimerStop(1);
    cout << "Preprocess Time:" << TimerGetRTime(1) << endl;

    auto start = high_resolution_clock::now();
    dp_solu(E, E_s, solu);
    auto stop = high_resolution_clock::now();
    auto duration = duration_cast<microseconds>(stop - start); 
    cout << "DP Time:" << duration.count() << endl;
    TimerStop(3);
    cout << "Total Runtime:"<< TimerGetRTime(3) << endl;

    string out_file = "./dp_break_point_Isabel.bin";
    FILE* out = fopen(out_file.c_str(), "w");
    out = fopen(out_file.c_str(), "w");
    for(int i = 1; i < N+1; i++){
        for(int k=1; k < N+1; k++){
            fwrite(&solu[i][k], sizeof(int), 1, out);
        }
    }
    fclose(out);
    
    return 0;
}

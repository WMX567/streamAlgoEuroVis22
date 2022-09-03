#include <iostream>  
#include <math.h>
#include <arrayfire.h>
#include <stdio.h>
#include <stdlib.h>
#include "timer.h"
#include <fstream>
#include <unistd.h>
#include <limits>
#include <unordered_map>
#include <condition_variable>
#include <cmath>
#include <thread>
#include <mutex>
#include <vector>
using namespace af;
using namespace std;

const int N = 800;
const int n = 200;
const string dir = "/scratch/mw4355/Radiation/";
const int dim = 600*248*248;
double time_io = 0;

// Save result
ofstream savedFile("Radiation800_saved.txt");

//+++++++++++++++++++++++++ Reading Functions Area+++++++++++++++++++++++++++++
af::array readData_Isabel(int file_num){
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
    af::array oneStep(1, dim, data_);
    delete[] data;
    delete[] data_;
    return oneStep;
}

af::array readData_Vortex(int file_num){
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
    af::array oneStep(1, dim, data_);
    delete[] data;
    delete[] data_;
    return oneStep;
}

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

af::array readData_TeraShake(int file_num){
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
    af::array oneStep(1, dim, data_);
    delete[] data;
    delete[] data_;
    return oneStep;
}
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//+++++++++++++++++++++++++ Algorithm ++++++++++++++++++++++++++++++++++++++++
double loss(af::array& ATB, af::array& ATA, af::array& bT, 
    af::array& a, double& tr_BTB, bool two_near){
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
    af::array ATA_inv = inverse(ATA);
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


//+++++++++++++++++++++++++ Helper Function ++++++++++++++++++++++++++++++++++++++++
//Parallel Computing
af::array shared_bT = readData_Radiation(1);
af::array shared_a = constant(1,2,1,f64);
int test_a = 1;
condition_variable cond;
mutex m_lock;
int counter = 0;
vector<thread> threads;
unordered_map<int, int> hash_;
double Err1 = 0;

int get_k(int i){
    if(i % n == 0){
        return n;
    }else if (i / n % 2 == 1){
        return (i % n) + (n+1)-2*(i % n);
    }else{
        return i % n;
    }
}

void keep_going_or_not(int prev_i){
    unique_lock<mutex> lk(m_lock);
    cond.wait(lk, [prev_i]{return test_a == prev_i+1;});
    lk.unlock();
    cond.notify_all();
}

void update_counter(){
    //Change Counter
    unique_lock<mutex> lk(m_lock);
    counter += 1;
    lk.unlock();
    cond.notify_all();
}

int intlog(double base, double x) {
    return (int)(log(x) / log(base));
}

void reading(){
    for(int i = 2; i < N+1; ++i){
        unique_lock<mutex> lk(m_lock);
        cond.wait(lk,[]{return counter == threads.size();});
        int k = get_k(i);
        shared_bT = readData_Radiation(k); //Read Data
        shared_a(0,0) = i;
        test_a = i;
        counter = 0;
        lk.unlock();
        cond.notify_all();
    }
}

void greedy_construct(double prev_loss, double alpha, 
int start, vector<int> solu){
    af::array ATA, ATB;
    int num_points = 0;
    int prev_i = start-1;
    double acc_loss = prev_loss;
    double cur_loss = 0;
    double tr_BTB = 0;
    for(int i=start;i<N+1;i++){
        keep_going_or_not(prev_i);
        prev_i += 1;
        if(i == start){
            prev_loss = 0;
            ATA = matmul(shared_a,transpose(shared_a));
            ATB = matmul(shared_a,shared_bT);
            tr_BTB = norm(shared_bT);
            tr_BTB *= tr_BTB;
            num_points = 1;
            update_counter(); //Update Counter
            continue;
        }
    
        num_points += 1;
        if (num_points == 2){
            cur_loss=loss(ATB, ATA, shared_bT, shared_a, tr_BTB, true);
        }
        else{
            cur_loss=loss(ATB, ATA, shared_bT, shared_a, tr_BTB, false);
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
            ATA = matmul(shared_a, transpose(shared_a));
            ATB = matmul(shared_a, shared_bT);
            tr_BTB = norm(shared_bT);
            tr_BTB *= tr_BTB;
            cur_loss = 0;
            prev_loss = 0;
            num_points = 1;
        }else{
            prev_loss = cur_loss;
            
        }
        //Change Counter
        update_counter();
    }
    unique_lock<mutex> lk(m_lock);
    savedFile << alpha << ":" << solu.size()+1 << ":" << acc_loss << endl;
    lk.unlock();
    cond.notify_all();
}

void update_thread(double prev_loss, double alpha, 
int start, vector<int> solu){
    unique_lock<mutex> lk(m_lock);
    threads.push_back(thread(greedy_construct, prev_loss, alpha, start, solu));
    lk.unlock();
    cond.notify_all();
}

void compute_max(){
    af::array  ATA_1, ATB_1;
    double tr_BTB;
    int prev_i = 0;

    for(int i = 1; i < N+1; i++){
        keep_going_or_not(prev_i);
        prev_i += 1;
        if(i == 1){
            ATA_1 = matmul(shared_a,transpose(shared_a));
            ATB_1 = matmul(shared_a,shared_bT);
            tr_BTB = norm(shared_bT);
            tr_BTB *= tr_BTB;
            //Update Counter
            update_counter();
            continue;
        }

        if(i==2){
            Err1 = loss(ATB_1, ATA_1, shared_bT, shared_a, tr_BTB, true);
        }else{
            Err1 = loss(ATB_1, ATA_1, shared_bT, shared_a, tr_BTB, false);
        }

        update_counter();

    }

    unique_lock<mutex> lk(m_lock);
    savedFile << Err1 << ":"<< 1 <<":"<<Err1<<endl;
    lk.unlock();
    cond.notify_all();

}


int main(void){
    setDevice(0);
    TimerStart(4);
    double Err2 = 0;
    af::array ATA, ATB;
    double upper = 0;
    double lower = numeric_limits<double>::infinity();
    double base = 5.0;
    double t = 0.000001;
    double tr_BTB;
    int e_1 = 0;
    int e_2 = 0;
    int l_seg = 1;
    int prev_i = 0;
    vector<int> zero_solu;

    {
        unique_lock<mutex> lk(m_lock);
        threads.push_back(thread(reading));
        threads.push_back(thread(compute_max));
        lk.unlock();
        cond.notify_all();
    }
    
    for(int i = 1; i < N+1; i++){
        keep_going_or_not(prev_i);
        prev_i += 1;
        if(i == 1){
            //Data Reading
            ATA = matmul(shared_a,transpose(shared_a));
            ATB = matmul(shared_a,shared_bT);
            tr_BTB = norm(shared_bT);
            tr_BTB *= tr_BTB;
            //Update Counter
            update_counter();
            continue;
        }

        if(l_seg < 2){
            Err2 = loss(ATB, ATA, shared_bT, shared_a, tr_BTB, true);
            l_seg += 1;
        }else{
            Err2 = loss(ATB, ATA, shared_bT, shared_a, tr_BTB, false);
            l_seg += 1;
        }

        while(Err1 == upper && Err1 != 0){}

        if(Err1 > t){
            e_2 = intlog(base, Err1);
            if(upper == 0){
                e_1 = e_2;
            }else{
                e_1 = intlog(base, upper)+1;
                if(intlog(base, upper) == log(upper) / log(base)){
                    e_1 -= 1;
                }
            }
            for(int j = e_1; j <= e_2; j++){
                if(hash_.find(j) == hash_.end()){
                    hash_.insert(pair<int,int>(j,1));
                    vector<int> solu;
                    solu.push_back(i-1);
                    threads.push_back(thread(greedy_construct, upper, pow(base, j),i,solu));
                }
            }
            upper = Err1;
        }

       if(Err2 > t){
            zero_solu.push_back(i-1);
            ATA = matmul(shared_a,transpose(shared_a));
            ATB = matmul(shared_a,shared_bT);
            tr_BTB = norm(shared_bT);
            tr_BTB *= tr_BTB;
            l_seg = 1;
            if(lower > Err2){
                e_1 = intlog(base, Err2)+1;
                if(intlog(base, Err2) == log(Err2) / log(base)){
                    e_1 -= 1;
                }
                if(lower == numeric_limits<double>::infinity()){
                    e_2 = e_1;
                }else{
                    e_2 = intlog(base, lower);
                }
                for(int j= e_1; j <= e_2; j++){
                    if(hash_.find(j) == hash_.end()){
                        hash_.insert(pair<int,int>(j,1));
                        zero_solu[zero_solu.size()-1] = i;
                        threads.push_back(thread(greedy_construct, Err2, pow(base, j), i+1, zero_solu));
                        update_counter();
                        zero_solu[zero_solu.size()-1] = i-1;
                    }
                }
                lower = Err2;
            }
        }

        update_counter();
    }

    for(auto &th: threads){
        th.join();
    }

    TimerStop(4);
    cout << "Time: " << TimerGetRTime(4) << endl;
    cout << "IO Time: " << time_io << endl;
    unique_lock<mutex> lk(m_lock);
    savedFile << 0 << ":"<< zero_solu.size()+1 << ":"<<0<<endl;
    lk.unlock();
    cond.notify_all();
    savedFile.close();
    return 0;
    
}

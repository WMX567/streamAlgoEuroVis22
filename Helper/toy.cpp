#include <thread>
#include <mutex>
#include <condition_variable>
#include <vector>
#include <iostream>
using namespace std;

int shared_bT=5;
int shared_a=0;
condition_variable cond;
mutex m_lock;
int counter = 0;

int data [4] = {5,4,3,2};
vector<thread> threads_;

void keep_going_or_not(int prev_i){
    unique_lock<mutex> lk(m_lock);
    cond.wait(lk, { return shared_a == prev_i+1;});
    lk.unlock();
}

void reading(){

    for(int i = 1; i < 4; ++i){
        unique_lock<mutex> lk(m_lock);
        cond.wait(lk, {return counter == threads_.size();});
        shared_bT = data[i]; //Read Data
        shared_a = i;
        counter = 0;
        lk.unlock();
        cond.notify_all();
    }
}

void add(int acc, int prev_i){

    for(int i = prev_i+1; i < 4; ++i){

        keep_going_or_not(prev_i);
        acc += shared_bT;
        prev_i += 1;;

        //Change Counter
        unique_lock<mutex> lk(m_lock);
        counter += 1;
        cond.notify_all();
        lk.unlock();

    }

    cout << "Total:"<< acc << endl;

}


int main(){

    int acc = 0;
    int prev_i = -1;

    threads_.push_back(thread(reading));
    threads_.push_back(thread(add, 0, -1));
    threads_.push_back(thread(add, 0, -1));
    threads_.push_back(thread(add, 0, -1));
    

    for(int i = prev_i+1; i < 4; ++i){

        keep_going_or_not(prev_i);
        acc += shared_bT;
        prev_i += 1;

        //Change Counter
        cout << "Change counter here :" << endl;
        unique_lock<mutex> lk(m_lock);
        counter += 1;
        lk.unlock();
        cond.notify_all();

    }

    for(int i =0; i < threads_.size(); i++){
        threads_[i].join();
    }

    cout << "Total:"<< acc << endl;
    return 0;
}
#include<stdio.h>
#include<stdlib.h>
#include<string>
#include <iostream> 
using namespace std;

void convert(string input_name, string output_name){
    int count = 0;
    FILE* in = fopen(input_name.c_str(), "r");
    FILE* out = fopen(output_name.c_str(), "w");
    unsigned inw, outw;  /* unsigned integers, 4 bytes */
    while(fread(&inw, sizeof(unsigned), 1, in)!=0) {
      outw =  ((inw & 0x000000ff) << 24) |
        ((inw & 0x0000ff00) << 8) |
        ((inw & 0x00ff0000) >> 8) |
        ((inw & 0xff000000) >> 24);
      fwrite(&outw, sizeof(unsigned), 1, out);
      count += 1;
    }
    fclose(in);
    fclose(out);
    cout << count << endl;
}

int main() {

  int spaces [7] = {7,48,151,186}; 
  int k = 4;
  // for (int i=0; i < k; i++){
  //   string inw = "Isabel/Isabel_ori"+to_string(spaces[i])+".bin";
  //   string out_path = "Isabel/ori_"+to_string(spaces[i])+".bin";
  //   convert(inw, out_path);
  // }

   for (int i=0; i < k; i++){
    string inw = "Radiation/Radiation_uni"+to_string(spaces[i])+".bin";
    string out_path = "Radiation/uni_"+to_string(spaces[i])+".bin";
    convert(inw, out_path);
  }

  // for (int i=0; i < k; i++){
  //   string inw = "Isabel/Isabel"+to_string(spaces[i])+".bin";
  //   string out_path = "Isabel/fb_"+to_string(spaces[i])+".bin";
  //   convert(inw, out_path);
  // }

  // for (int i=0; i < k; i++){
  //   string inw = "Isabel/Isabel_dp"+to_string(spaces[i])+".bin";
  //   string out_path = "Isabel/dp_"+to_string(spaces[i])+".bin";
  //   convert(inw, out_path);
  // }
  return 0;
}
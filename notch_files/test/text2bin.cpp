#include <iostream>
#include <fstream>

using namespace std;

#define NO_SAMPLES 963144       // no of samples
#define SAMPLE_SCALING 2147483647

#define INPUT "wav.txt"
#define OUTPUT "wav.bin"

int main(){
    ifstream input(INPUT, ifstream::in);
    ofstream output(OUTPUT, ofstream::binary | ofstream::out | ofstream::trunc);
    
    for (int i = 0; i < NO_SAMPLES; i++){
        double in;
        input >> in;
        in *= SAMPLE_SCALING;
        
        int out = int(in);
        output.write((const char *) &out, sizeof(int));
        
    }
    
    cout << "Done" << endl;

    return 0;
}
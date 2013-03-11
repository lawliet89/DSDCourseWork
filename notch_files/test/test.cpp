// Pro -tip. In matlab use
// dlmwrite('wav.txt', wav,  'delimiter', sprintf('\n'), 'precision', 16);

#include <iostream>
#include <fstream>
#include <vector>
#include <boost/circular_buffer.hpp>

#define NO_SAMPLES 963144       // no of samples
#define SAMPLE_SCALING 2147483647
#define COEFF_SCALING 17297

#define N 2    // order - DO NOT CHANGE. Higher orders with quantisation errors cause filter to become unstable


#define INPUT "wav.txt"
#define SCALED_INPUT "wav_scaled.txt"
#define OUTPUT "out.txt"
#define SCALED_OUTPUT "out_scaled.txt"
#define COEFF "coeff.txt"


using namespace std;

int main()
{
    ifstream input(INPUT, ifstream::in);
    ofstream output(OUTPUT, ofstream::out | ofstream::trunc);
    
    ofstream scaledInput(SCALED_INPUT, ofstream::out | ofstream::trunc);
    ofstream scaledOutput(SCALED_OUTPUT, ofstream::out | ofstream::trunc);
    
    ifstream coeff(COEFF, ifstream::in);
    
        
    vector<int> samples(NO_SAMPLES, 0);   // samples
    vector<short> a(N+1, 0);        // a coeff
    vector<short> b(N+1, 0); // b coeff
    
    boost::circular_buffer<long long> outputBuffer(N, 0);
    
    
    // read a coefficients
    cout << "a = ";
    for (int i = 0; i < (N+1); i++)
    {
        double temp;
        coeff >> temp;
        a.at(i) = (short) (temp*COEFF_SCALING);
        cout << a.at(i) << " ";
    }
    cout << endl;
    
    // read b coefficients
     cout << "b = ";
    for (int i = 0; i < (N+1); i++)
    {
        double temp;
        coeff >> temp;
        b.at(i) = (short) (temp*COEFF_SCALING);
        cout << b.at(i) << " ";
    }
    cout << endl;
    
    cout << "Reading and scaling samples" << endl;
    // read and scale samples
    for (int i = 0; i < NO_SAMPLES; i++){
        double temp;
        input >> temp;
        samples.at(i) = (int) (temp*SAMPLE_SCALING);

        scaledInput << samples.at(i)  << "\n";
    }
    
    cout << "Performing IIR Filtering (Direct Form I)" << endl;
    
    // We can only do Direct Form I because we have scaled the coefficients
    // https://ccrma.stanford.edu/~jos/fp/Direct_Form_I.html
    for (int i = 0; i < NO_SAMPLES; i++)
    {
        //cout << outputBuffer[0] << " " << outputBuffer[1] << endl;
        long long y = 0;
        for (int j = 0; j < N+1; j++){
            
            // input
            if (i >= j)
            {
                y += (long long)(b[j])*(long long)(samples.at(i-j));
                
            }    
            // output
            if (j != 0)
                y -= (long long)(a[j])*outputBuffer[j-1];
        }
        
        // get rid of coefficient scaling
        y /= COEFF_SCALING;
        
        // push to front of circular buffer
        outputBuffer.push_front(y);
        
        scaledOutput << y << "\n";
        
        double scaled = double(y)/SAMPLE_SCALING;
        output << scaled << "\n";
    }
    
    /*
    // Let's perform the IIR filtering
    for (int i = 0; i < NO_SAMPLES; i++){
        int y = 0;
        y = int (  v[0] + b[0]*samples[i] );
        
        for (int j = 0; j < N-2; j++){
            v[j] = v[j+1] + b[j+1]*samples[i] - a[j+1]*y;
        }
        v[N-2] = b[N-1]*samples[i] - a[N-1]*y;
        
        scaledOutput << y << "\n";
        
        double scaled = double(y)/SAMPLE_SCALING;
        output << scaled << "\n";
    }*/
    cout << "Done" << endl;
}
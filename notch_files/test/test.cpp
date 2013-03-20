// Pro -tip. In matlab use
// dlmwrite('wav.txt', wav,  'delimiter', sprintf('\n'), 'precision', 16);

#include <iostream>
#include <fstream>
#include <vector>
#include <boost/circular_buffer.hpp>

#define NO_SAMPLES 963144       // no of samples
#define SAMPLE_SCALING 2147483647
#define COEFF_SCALING 16383

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
    

    // get the number of sections
    int sections;
    coeff >> sections;
    cout << sections << " sections filtering" << endl;

    // coefficients vectors

    vector<short> a(sections*(N+1), 0);        // a coeff
    vector<short> b(sections*(N+1), 0); // b coeff
    vector<short> scale(sections+1, 1);

    // circular buffer for delay lines
    boost::circular_buffer<long long> delayBuffer(N, 0);
    
    // buffer for in between sections
    vector<int> bufferA(NO_SAMPLES, 0);  
    vector<int> bufferB(NO_SAMPLES, 0);  

    vector<int> *inputBuffer = &bufferA;
    vector<int> *outputBuffer = &bufferB;
    
    for (int j = 0; j < sections; j++)
    {
        cout << "Reading section " << (j+1) << " coefficients" << endl;

        // read b coefficients
         cout << "b = ";
        for (int i = 0; i < (N+1); i++)
        {
            double temp;
            coeff >> temp;
            b.at(j*N + i) = (short) (temp*COEFF_SCALING);
            cout << b.at(j*N + i) << " ";
        }
        cout << endl;
        // read a coefficients
        cout << "a = ";
        for (int i = 0; i < (N+1); i++)
        {
            double temp;
            coeff >> temp;
            a.at(j*N + i) = (short) (temp*COEFF_SCALING);
            cout << a.at(j*N + i) << " ";
        }
        cout << endl;
        
    }

    cout << "Reading Section Scale values" << endl;
    for (int i = 0; i <= sections; i ++)
    {
        double temp;
        coeff >>  temp;
        scale.at(i) = short(temp*COEFF_SCALING);
    }

    cout << "Reading and scaling samples" << endl;
    // read and scale samples
    for (int i = 0; i < NO_SAMPLES; i++){
        double temp;
        input >> temp;
        inputBuffer->at(i) = (int) (temp*SAMPLE_SCALING);

        scaledInput << inputBuffer->at(i)  << "\n";
    }
    
    cout << "Performing IIR Filtering (Direct Form I)" << endl;
    
    // We can only do Direct Form I because we have scaled the coefficients
    // https://ccrma.stanford.edu/~jos/fp/Direct_Form_I.html

    for (int k = 0; k < sections; k++)
    {
        cout << "Filter section " << (k+1) << endl;

        // clear circular buffer
        delayBuffer.assign(N,0);

        for (int i = 0; i < NO_SAMPLES; i++)
        {
            long long y = 0;
            for (int j = 0; j < N+1; j++){
                
                // input
                if (i >= j)
                {
                    y += (long long)(b[k*N + j])*(long long)(inputBuffer->at(i-j));
                    
                }    
                // output
                if (j != 0)
                    y -= (long long)(a[k*N + j])*delayBuffer[j-1];
            }
            
            // get rid of coefficient scaling
            y /= COEFF_SCALING;
            
            // push to front of circular buffer
            delayBuffer.push_front(y);
            
            if (k == sections-1)
                scaledOutput << int(y) << "\n";
            else
                outputBuffer -> at(i) = int(y);
            
            if (k == sections-1){
                double scaled = double(int(y))/SAMPLE_SCALING/1.5811168108056664;
                output << scaled << "\n";
            }   
        }

        // swap buffers
        if (k != sections-1)
        {
            vector<int>* temp;
            temp = inputBuffer;
            inputBuffer = outputBuffer;
            outputBuffer = inputBuffer;
        }
    }
    
    cout << "Done" << endl;
}
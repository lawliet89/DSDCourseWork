% Hd is the filter we have designed
[wav, fs] = audioread('beeth5_noise.wav');
out = filter(Hd, wav);
audiowrite('out.wav', out, fs);
audiowrite('calculated.wav', calculated, fs);

% Plot amplitude spectrum.
figure;
L = length(calculated);
NFFT = 2^nextpow2(L); 
Y = fft(calculated,NFFT)/L;
f = fs/2*linspace(0,1,NFFT/2+1);
plot(f,2*abs(Y(1:NFFT/2+1)),'r') 
title('Single-Sided Amplitude Spectrum of Matlab Implementation vs C++ Simulation');
xlabel('Frequency (Hz)')
ylabel('|beeth5\_noise(f)|')


hold on;
L = length(out);
NFFT = 2^nextpow2(L); 
Y = fft(out,NFFT)/L;
f = fs/2*linspace(0,1,NFFT/2+1);
plot(f,2*abs(Y(1:NFFT/2+1))) 
title('Single-Sided Amplitude Spectrum of Matlab Implementation vs FPGA Output');
xlabel('Frequency (Hz)');
ylabel('|signal(f)|');

legend('FPGA', 'Matlab');


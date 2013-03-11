


load beeth5_noise.mat
%sound(beeth5_noise,fs,8);

%doc filter



% Plot amplitude spectrum.
figure;
L = length(beeth5_noise);
NFFT = 2^nextpow2(L); 
Y = fft(beeth5_noise,NFFT)/L;
f = fs/2*linspace(0,1,NFFT/2+1);
plot(f,2*abs(Y(1:NFFT/2+1)),'r') 
title('Single-Sided Amplitude Spectrum of beeth5\_noise(t)')
xlabel('Frequency (Hz)')
ylabel('|beeth5\_noise(f)|')


% notch filter

fo = 1000;              % notch freq
fr = fo / fs;           % frequency ratio
filter_width = .001;

zeros = [ exp(1i*2*pi*fr), exp(-1i*2*pi*fr) ];
poles = (1 - filter_width) * zeros;

a = poly(poles);
b = poly(zeros);

% truncate coeffs
a = floor(a .* 256) / 256;
b = floor(b .* 256) / 256;

beeth5_recovered = filter(b,a,beeth5_noise);

%sound(beeth5_recovered,fs,8);



hold on;
L = length(beeth5_recovered);
NFFT = 2^nextpow2(L); 
Y = fft(beeth5_recovered,NFFT)/L;
f = fs/2*linspace(0,1,NFFT/2+1);
plot(f,2*abs(Y(1:NFFT/2+1))) 
title('Single-Sided Amplitude Spectrum of beeth5\_noise(t) and beeth5\_recovered(t)');
xlabel('Frequency (Hz)');
ylabel('|signal(f)|');

legend('beeth5\_noise', 'beeth5\_recovered');



N     = 6;      % Order
F0    = 1000;   % Center frequency
Q     = 2.5;    % Q-factor
Apass = 0.4;    % Passband Ripple (dB)
Fs    = 44100;  % Sampling Frequency

h = fdesign.notch('N,F0,Q,Ap', N, F0, Q, Apass, Fs);

Hd = design(h, 'cheby1', ...
    'FilterStructure', 'df2tsos', ...
    'SOSScaleNorm', 'Linf');

fvtool(Hd);

% [EOF]

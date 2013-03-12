scale = 2147483647;
out = 'output.dat';
in = 'beeth5_noise.wav';

[wav, fs] = wavread(in);
wav_scaled = scale * wav;
fd = fopen(out,'wb');
fwrite(fd, wav_scaled, 'int32');
fclose(fd);
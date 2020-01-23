%% Generate noise and calculate Noise Power
% Choose parameters
noiseFloorDBMHZ = -30; % dBm/Hz
bandwidth = 1e6; % Hz (-bandwidth/2 -> bandwidth/2)
% Convert to linear units
noiseFloorWHZ = 10^((noiseFloorDBMHZ-30)/10); % Watts/Hz
% Calculate noise power
NoisePower = noiseFloorWHZ*bandwidth; % Watts
ComplexNoisePower = 1e-4;

% % OG sine wave
% Fs = 8000;                   % samples per second
% dt = 1/Fs;                   % seconds per sample
% StopTime = 0.25;             % seconds
% t = (0:dt:StopTime-dt)';     % seconds
% %%Sine wave:
% Fc = 10;                     % hertz
% x = cos(2*pi*Fc*t);
% plot(t,x);

% New cosine wave with added noise
Fs = 100;
t = 0:1/Fs:1-1/Fs;
% Cosine wave with AWGN
x = cos(2*pi*100*t) + randn(size(t));
N = length(x);
% Take the FFT of the Cosine w/ AWGN and plot it
xdft = fft(x);          % Raw fourier transform
xdft = xdft(1:N/2+1);   % Appended raw fourier transform (cuts off some of the end last values)
xdft = abs(xdft).^2;    % Magnitude response of the FFT
%plot(xdft);             % Plot the magnitude response
% Get the PSD of the signal
psdx = (1/(Fs*N)) * xdft;
psdx(2:end-1) = 2*psdx(2:end-1);
freq = 0:Fs/length(x):Fs/2;
plot(freq,10*log10(psdx))
grid on
title('Periodogram Using FFT')
xlabel('Frequency (Hz)')
ylabel('Power/Frequency (dB/Hz)')
%%
sinusoidPower = 0;

% Generate AWGN signal with desired noise power
fftLen = 2^10; frames = 1e3;
noiseC = sqrt(ComplexNoisePower)/sqrt(2).*(randn(fftLen*frames,1)+randn(fftLen*frames,1).*1i); % Complex noise
noise = sqrt(NoisePower).*(randn(fftLen*frames,1)); % Real Noise
noiseS = sqrt(sinusoidPower).*(randn(fftLen*frames,1)); % Real Noise
% Check
disp([NoisePower var(noise) var(noiseC) rms(noise)^2 rms(noiseC)^2]);
%% Veryify PSD
noiseFramesC = reshape(noiseC,fftLen,frames);
noiseFrames = reshape(noise,fftLen,frames);
noiseFramesS = reshape(noiseS,fftLen,frames);
% Determine PSD in Watts/(Frequency Bin)
noiseFramesFreqC = fft(noiseFramesC,fftLen);
noiseFramesFreq = fft(noiseFrames,fftLen);
noiseFramesFreqS = fft(noiseFramesS,fftLen);
% Autocorrelate and calculate mean power
S_kC = mean(abs(noiseFramesFreqC).^2,2)/fftLen;
S_k = mean(abs(noiseFramesFreq).^2,2)/fftLen;
S_kS = mean(abs(noiseFramesFreqS).^2,2)/fftLen;
% Convert to dBm/Hz
S_k_DBMHZC = 10*log10(S_kC/bandwidth) + 30;
S_k_DBMHZ = 10*log10(S_k/bandwidth) + 30;
S_k_DBMHZS = 10*log10(S_kS/bandwidth) + 30;
% Plot
freqs = linspace(-bandwidth/2,bandwidth/2,fftLen);
figure;plot(freqs,S_k_DBMHZ,freqs,S_k_DBMHZC,freqs,S_k_DBMHZS);
xlabel('Hz');ylabel('dBm/Hz');grid on;
ylim(noiseFloorDBMHZ+[-20 20]);
legend('Real Noise','Complex');

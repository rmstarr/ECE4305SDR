%% SDR Rx of WiFi Signals

% Creating the SDR connection
rx = sdrrx('Pluto'); % This will allow you to create sdr object, also lists properties
rx.CenterFrequency = 920e6; % Allows you to change center frequency

% Creating the DSP Connection
% ViewType is changed to Spectrogram so the WiFi signals can be displayed
x = dsp.SpectrumAnalyzer("ViewType", "Spectrogram");
x.SampleRate = 10e6;  % Sample rate of 10MHz

% Continuously run the Spectrogram to track WiFi signals!
% Note: Will need to run section separately, or you can't reach next
% section of the code
% while 1
%     x(rx())
% end

%% SDR Tx and Rx 

% Transmit a Sine Wave and then receive it
tx = sdrtx('Pluto');        % Transmitter
tx.Gain = -80;              % Set gain
sine = dsp.SineWave('Frequency', 1, 'ComplexOutput', true, 'SamplesPerFrame', 2048);
scope = dsp.TimeScope;      % Time Scope of the DSP
tx.transmitRepeat(sine());  % Continuously repeat the sine wave signal

% Open the scope to view transmitted and received signals
while 1
    scope(rx());
end

%% Automate Change in Center Function Frequency 

rx.CenterFrequency = 650e6;     % Set Center Frequency
frequencyStep = 5e6;            % Set Frequency Step
frequencyEnd = 3.5e9;           % Set End Frequency
dwellTime = 0.6;                % Set Dwell (Delay) Time

% Loop through center frequencies in Spectrogram
while rx. CenterFrequency < frequencyEnd
    x(rx())
    rx.CenterFrequency = rx.CenterFrequency + frequencyStep;
    pause(dwellTime)
    disp(rx.CenterFrequency)
end

%% Provided Code from Lab 0 Document

% Generate noise and calculate Noise Power 
% Choose parameters 
noiseFloorDBMHZ = -30; % dBm/Hz 
bandwidth = 1e6; % Hz (-bandwidth/2 -> bandwidth/2) 

% Convert to linear units 
noiseFloorWHZ = 10^((noiseFloorDBMHZ-30)/10); % Watts/Hz 

% Calculate noise power 
NoisePower = noiseFloorWHZ*bandwidth; % Watts 
NoiseComplex = 1e-4; % 100uW should be about -70dB

% Sinusoidal signal
% Construction of the sinusoid
rng default
Fs = 1000;
t = 0:1/Fs:1-1/Fs;
x = cos(2*pi*100*t) + randn(size(t));

% Fourier Transform and PSD of resulting wave
N = length(x);
xdft = fft(x);
xdft = xdft(1:N/2+1);
psdx = (1/(Fs*N)) * abs(xdft).^2;
psdx(2:end-1) = 2*psdx(2:end-1);
freq = 0:Fs/length(x):Fs/2;

% Plot resulting signal
plot(freq,10*log10(psdx))
grid on
title('Periodogram Using FFT')
xlabel('Frequency (Hz)')
ylabel('Power/Frequency (dB/Hz)')

% Generate AWGN signal with desired noise power 
fftLen = 2^10; 
frames = 1e3; 
noiseC = sqrt(NoiseComplex)/sqrt(2).*... 
    (randn(fftLen*frames,1)+randn(fftLen*frames,1).*1i); % Complex noise 
noise = sqrt(NoisePower).*(randn(fftLen*frames,1)); % Real Noise 

% Check 
disp([NoisePower var(noise) var(noiseC) rms(noise)^2 rms(noiseC)^2]);

% Veryify PSD 
noiseFramesC = reshape(noiseC,fftLen,frames);
noiseFrames = reshape(noise,fftLen,frames); 

% Determine PSD in Watts/(Frequency Bin) 
noiseFramesFreqC = fft(noiseFramesC,fftLen); 
noiseFramesFreq = fft(noiseFrames,fftLen); 

% Autocorrelate and calculate mean power 
S_kC = mean(abs(noiseFramesFreqC).^2,2)/fftLen;
S_k = mean(abs(noiseFramesFreq).^2,2)/fftLen; 

% Convert to dBm/Hz 
S_k_DBMHZC = 10*log10(S_kC/bandwidth) + 30; 
S_k_DBMHZ = 10*log10(S_k/bandwidth) + 30; 

% Plot 
freqs = linspace(-bandwidth/2,bandwidth/2,fftLen);
figure;plot(freqs,S_k_DBMHZ,freqs,S_k_DBMHZC);
xlabel('Hz');
ylabel('dBm/Hz');
grid on; 
ylim(noiseFloorDBMHZ+[-20 20]); 
legend('Real Noise','Complex');

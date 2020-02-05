%% Names: Ethan Martin, Robert Starr, and Andrew Duncan
% Professor Wyglinski
% ECE 4305, C2020
% Lab Due: 7 February 2020
close all;


%% General system details
sampleRateHz = 1e6; % Sample rate
samplesPerSymbol = 1;
frameSize = 2^10;
numFrames = 100;
numSamples = numFrames*frameSize; % Samples to simulate
modulationOrder = 2;
filterUpsample = 8;
filterSymbolSpan = 8;

%% Impairments
snr = 15;
frequencyOffsetHz = 1e5; % Offset in hertz
phaseOffset = 0; % Radians

%% Generate symbols
data = randi([0 samplesPerSymbol], numSamples, 1);
mod = comm.DBPSKModulator();
modulatedData = mod.step(data);


% Generation of QPSK Data
qpskmod = comm.QPSKModulator();
modulatedQPSK = qpskmod.step(data);


%% Add TX Filter
TxFlt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample, 'FilterSpanInSymbols', filterSymbolSpan);
filteredData = step(TxFlt, modulatedData);

% Filtered Data for the QPSK 
filteredQPSK = step(TxFlt, modulatedQPSK);

%% Add noise
noisyData = awgn(filteredData,snr);%,'measured');

% Noise injected into QPSK
noisyQPSK = awgn(filteredQPSK, snr);

%% Setup visualization object(s)
% sa = dsp.SpectrumAnalyzer('SampleRate',sampleRateHz,'ShowLegend',true);

%% Model of error
% Add frequency offset to baseband signal

% Precalculate constant(s)
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;
T = 1/sampleRateHz;
K = 1024;
offsetData = zeros(size(noisyData));
newBoi = zeros(size(noisyData));

% Precalculate QPSK Offset size
offsetQPSK = zeros(size(noisyQPSK));
newBoi_QPSK = zeros(size(noisyQPSK));

for k=1:frameSize:numSamples*filterUpsample

    % Create phase accurate vector
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = (noisyData(timeIndex).*freqShift);
    
    % Offset for QPSK
    offsetQPSK(timeIndex) = (noisyQPSK(timeIndex).*freqShift);
    
    % Offset Adjustment:
    
    %Important corrections from previous solution: 
    
    %   1. The frequency offset is obtained by performing the equation 
    %   to the actual offset data, not to the noisy data.
    
    %   2. The Fourier Transform needs to be squared after, we shouldn't
    %   square the data, then put it into the fourier. That way our actual
    %   offset will actually be accurate. When I tried using our method
    %   with the offset data I kept getting a number in the 200 - 300
    %   range. But when that number is squared, then I believe our coarse
    %   frequency comphensation will be more accurate. 
    
    
    % Take fourier of offset data
    FFT = abs(fft(offsetData(timeIndex).^2, 1024));
    
    % Take Fourier of offsetted QPSK
    FFT_QPSK = abs(fft(offsetQPSK(timeIndex).^2, 1024));
    
    % Square the fourier transform:
    fftSquared = FFT.^2;
    
    fftSquared_QPSK = FFT_QPSK.^2;
    
    % Finish the equation to get the actual offset. 
    [~,actualOffset] = max(fftSquared);
    actualOffset = actualOffset-1;
    
    % Finish QPSK equation
    [~, actualOffset_QPSK] = max(fftSquared_QPSK);
    actualOffset_QPSK = actualOffset_QPSK - 1;
    
    
    if actualOffset >= 512 
        actualOffset = actualOffset - 1024;
    end
    
    % Offseted QPSK Adjustments
    if actualOffset_QPSK >= 512
        actualOffset_QPSK = actualOffset_QPSK - 1024;
    end
   
    
    actualOffset = (actualOffset*sampleRateHz)/(2*K);
    disp(actualOffset);
    
    
    actualOffset_QPSK = (actualOffset_QPSK* sampleRateHz) / (2*K);
    disp(actualOffset_QPSK);
    
    % The rest of the solution is the same.

    % Use the frequency offset found in prior section, and create
    % adjustment constant
    adjustment = -1i .*2*pi * actualOffset ./ sampleRateHz;
    
    adjustment_QPSK = -1i .*2*pi * actualOffset_QPSK ./ sampleRateHz;
    
    % Frequency adjustment in terms of e^j*pi*w
    freqAdjust = exp(adjustment*timeIndex);
    
    freqAdjust_QPSK = exp(adjustment_QPSK*timeIndex);
    
    
    % New original signals
    newBoi(timeIndex) = (offsetData(timeIndex) .* freqAdjust);
    
    newBoi_QPSK(timeIndex) = (offsetData(timeIndex) .* freqAdjust_QPSK);
    
    % Visualize Error
     %step(sa,[noisyData(timeIndex), newBoi(timeIndex)]);pause(0.1); %#ok<*UNRCH>

end


%% Plot
figure
df = sampleRateHz/frameSize;
frequencies = -sampleRateHz/2:df:sampleRateHz/2-df;
spec = @(sig) fftshift(10*log10(abs(fft(sig))));
h = plot(frequencies, spec(noisyData(timeIndex)),...
     frequencies, spec(newBoi(timeIndex)));
grid on;xlabel('Frequency (Hz)');ylabel('PSD (dB)');
legend('Original','Offset','Location','Best');
NumTicks = 5;L = h(1).Parent.XLim;
set(h(1).Parent,'XTick',linspace(L(1),L(2),NumTicks))


% Plot for the QPSK modulated waveform
figure
qpskPlot = plot(frequencies, spec(noisyQPSK(timeIndex)),...
    frequencies, spec(newBoi_QPSK(timeIndex)));
grid on; xlabel('Frequency (Hz)'); ylabel('PSD (dB)');
legend('Original QPSK', 'Offset', 'Location', 'Best');
NumTicks_QPSK = 5; L_QPSK = qpskPlot(1).Parent.XLim;
set(qpskPlot(1).Parent, 'XTick', linspace(L_QPSK(1), L_QPSK(2), NumTicks_QPSK))


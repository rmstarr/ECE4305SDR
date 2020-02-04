%% General system details
sampleRateHz = 1e6; % Sample rate
% 1 for BPSK, 3 for QPSK
samplesPerSymbol = 1;
frameSize = 2^10;
numFrames = 100;
numSamples = numFrames*frameSize; % Samples to simulate
% 4 for QPSK, 2 for BPSK
modulationOrder = 2;
filterUpsample = 4;
filterSymbolSpan = 8;

%% Impairments
snr = 15;
frequencyOffsetHz = 1e5; % Offset in hertz
phaseOffset = 0; % Radians

%% Generate symbols
data =  randi([0 samplesPerSymbol], numSamples, 1);
% mod = comm.DBPSKModulator();
% modulatedData = mod.step(data);

% Generate QPSK Symbols:
qpskmod = comm.QPSKModulator();
qpskmodulatedData = qpskmod.step(data);


%% Add TX Filter
TxFlt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample, 'FilterSpanInSymbols', filterSymbolSpan);
filteredData = step(TxFlt, qpskmodulatedData);

%% Add noise
noisyData = awgn(filteredData,snr);%,'measured');


%% Setup visualization object(s)
 %sa = dsp.SpectrumAnalyzer('SampleRate',sampleRateHz,'ShowLegend',true);

%% Model of error
% Add frequency offset to baseband signal

% Precalculate constant(s)
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;
T = 1/sampleRateHz;
K = 1024;
offsetData = zeros(size(noisyData));
recoveredSig = zeros(size(noisyData));
M = 4; % MPSK: 4 for QPSK, 2 for DBPSK

for k=1:frameSize:numSamples*filterUpsample

    % Create phase accurate vector
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = (noisyData(timeIndex).*freqShift);
 
    % Offset Adjustment:
    
    % Take fourier of offset data
    FFT = abs(fft(offsetData(timeIndex).^M, 1024));
    % Square the fourier transform:
    % Find the maximum argument in the FFT 
    [~,actualOffset] = max(FFT);
    actualOffset = actualOffset-1;
  
    actualOffset = (actualOffset*sampleRateHz)/(M*K);
    disp(actualOffset);
    % Use the frequency offset found in prior section, and create
    % adjustment constant
    adjustment = -1i .*2*pi * actualOffset ./ sampleRateHz;
    % Frequency adjustment in terms of e^j*pi*w
    freqAdjust = exp(adjustment*timeIndex);
    % New original signals
    recoveredSig(timeIndex) = (offsetData(timeIndex) .* freqAdjust);
    
    
    % Visualize Error
     %step(sa,[noisyData(timeIndex), recoveredSig(timeIndex)]);pause(0.1); %#ok<*UNRCH>

end


%% Plot
figure
df = sampleRateHz/frameSize;
frequencies = -sampleRateHz/2:df:sampleRateHz/2-df;
spec = @(sig) fftshift(10*log10(abs(fft(sig))));
h = plot(frequencies, spec(noisyData(timeIndex)),...
     frequencies, spec(recoveredSig(timeIndex)));
grid on;xlabel('Frequency (Hz)');ylabel('PSD (dB)'); title('After Coarse Frequency Compensation')
legend('Original','Adjusted','Location','Best');
NumTicks = 5;L = h(1).Parent.XLim;
set(h(1).Parent,'XTick',linspace(L(1),L(2),NumTicks))

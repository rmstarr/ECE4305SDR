%% General system details
sampleRateHz = 1e6; % Sample rate
samplesPerSymbol = 4;
frameSize = 2^10;
numFrames = 200;
numSamples = numFrames*frameSize; % Samples to simulate
modulationOrder = 2;
filterSymbolSpan = 10;

%% Visuals
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'SymbolsToDisplaySource','Property',...
    'SymbolsToDisplay',frameSize/2,...
    'Name','Baseband with Timing Offset');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side

%% Impairments
snr = 15;
timingOffset = samplesPerSymbol*0.01; % Samples

%% Generate symbols
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator();
modulatedData = mod.step(data);

%% Add TX/RX Filters
TxFlt = comm.RaisedCosineTransmitFilter(...
    'OutputSamplesPerSymbol', samplesPerSymbol,...
    'FilterSpanInSymbols', filterSymbolSpan);

RxFlt = comm.RaisedCosineReceiveFilter(...
    'InputSamplesPerSymbol', samplesPerSymbol,...
    'FilterSpanInSymbols', filterSymbolSpan,...
    'DecimationFactor', 1);% Set to filterUpsample/2 when introducing timing estimation
RxFltRef = clone(RxFlt);

%% Add noise source
chan = comm.AWGNChannel( ...
    'NoiseMethod',  'Signal to noise ratio (SNR)', ...
    'SNR',          snr, ...
    'SignalPower',  1, ...
    'RandomStream', 'mt19937ar with seed');

%% Add delay
varDelay = dsp.VariableFractionalDelay;

%% Setup visualization object(s)
sa = dsp.SpectrumAnalyzer('SampleRate',sampleRateHz,'ShowLegend',true);

%% Symbol Synchronizer Object:

timeSync =  comm.SymbolSynchronizer('Modulation', 'PAM/PSK/QAM', 'TimingErrorDetector', 'Mueller-Muller (decision-directed)', 'NormalizedLoopBandwidth', 0.01);

%% Model of error
% Add timing offset to baseband signal
filteredData = [];
adjustedSig = [];

for k=1:frameSize:(numSamples - frameSize)
    
    timeIndex = (k:k+frameSize-1).';
    
    % Filter signal
    filteredTXData = step(TxFlt, modulatedData(timeIndex));
    
    % Pass through channel
    noisyData = step(chan, filteredTXData);
    
    % Time delay signal
    offsetData = step(varDelay, noisyData, k/frameSize*timingOffset); % Variable delay
    
 
  
    % Filter signal
    filteredData = step(RxFlt, offsetData);
    filteredDataRef = step(RxFltRef, noisyData);
    disp(length(filteredData));
    
    % Do timing correction:
    %adjust = offsetData(1:1/2:length(offsetData)-0.5);
    adjustedSig = timeSync(filteredData);
    disp(length(adjustedSig));
    
    % Visualize Error
    step(cdPre,filteredData);
    step(cdPost,adjustedSig);pause(0.1); 
    release(cdPost);
   
    
end
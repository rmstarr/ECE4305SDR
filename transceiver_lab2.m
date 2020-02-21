  
%% Timing Correction on PLUTO SDR
% Ethan Martin, Robert Starr, and Andrew Duncan

%% Communication with Timing Correction on a Single PLUTO
%% General system details
sampleRateHz = 1e6;                     % Sample rate
samplesPerSymbol = 4;                   % Upsampling factor    
decimationFactor = 2;                   % Downsampling factor
frameSize = 2^10;                       % Frame size
numFrames = 200;                        % Total frames to simulate
numSamples = numFrames*frameSize;       % Samples to simulate
modulationOrder = 2;                    % Modulation order of signal
filterSymbolSpan = 10;                  % Span of Filter
normalizedLoopBandwidth = 0.01;         % Normalized Loop BW of RC filter

%% Visuals
% Constellations
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'SymbolsToDisplaySource','Property',...
    'SymbolsToDisplay',frameSize/2,...
    'Name','Baseband with Timing Offset');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side

% EVM Scope
scope = dsp.TimeScope('YLabel', 'EVM (%)', 'SampleRate', 1000, 'TimeSpan', 10);

%% PLUTO Radio setup
% Declaration of system parameters for hardware testing
centerFrequency = 2.4e9;

% Creation of SDR TX and RX objects
% Transmitter
transmitter = sdrtx('Pluto', ...
    'CenterFrequency', centerFrequency, ...
    'Gain', -10); 

% Receiver
receiver = sdrrx('Pluto', ...
    'CenterFrequency', centerFrequency, ...
    'SamplesPerFrame', 1e6, ...
    'OutputDataType', 'double');

%% Data creation
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator();
modulatedData = mod.step(data);
phaseOffset = 30;

%% Transmit and receiver filter setup
txFilterPLUTO = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', ...
    samplesPerSymbol, 'FilterSpanInSymbols', filterSymbolSpan);

rxFilterPLUTO = comm.RaisedCosineReceiveFilter('InputSamplesPerSymbol', ...
    samplesPerSymbol, 'FilterSpanInSymbols', filterSymbolSpan, ... 
    'DecimationFactor', decimationFactor );

%% Impairments and channel creation
snr = 15;
timingOffset = samplesPerSymbol*0.01; % Samples

%% Frequency Synchronization Object:

freqSync = comm.CarrierSynchronizer('Modulation', 'BPSK', 'SamplesPerSymbol', samplesPerSymbol, 'DampingFactor', 1/sqrt(2));

%% Timing synchronization object setup
timeSyncPLUTO = comm.SymbolSynchronizer('Modulation', 'PAM/PSK/QAM', ...
    'SamplesPerSymbol', samplesPerSymbol,'NormalizedLoopBandwidth', ...
    normalizedLoopBandwidth);

%% Delay factor
tDelay = dsp.VariableFractionalDelay();

%% Throw Data into transmit raised cosine:

% Filter Signal (TX Side) 
filteredTxData = step(txFilterPLUTO, modulatedData);

%% Creation of Signal, TX Offset, and TX Corrected Signal
filteredRxData = [];
tCorrectedSig = [];

while 1
 
    % Continuously transmit the data repeatedly
    transmitter.transmitRepeat(filteredTxData);
    
    % Continuosly receiving the data
    receivedData = receiver();
    
    % Carrier Synchronization:
    alignedData = step(freqSync,receivedData);
    
%     % Filter Signal (RX Side)
%     filteredRxData = step(rxFilterPLUTO, alignedData);
%     
    % Do Timing Correction
    tCorrectedSig = step(timeSyncPLUTO, alignedData);
    
    % Visualize Error
    step(cdPre, alignedData);
   step(cdPost, tCorrectedSig);
    pause(0.1);
    release(cdPost)
end

% % Transmit the Filtered, Offset Data
% transmitter(filteredRxData);
% 
% 
% % Release the objects, transmit the corrected data
% release(transmitter);
% release(receiver);
% 
% transmitter(tCorrectedSig);
% receivedTCorrectedData = receiver();
% 
% release(transmitter);
% release(receiver);

%% EVM Analysis of the Signals
% constPoints = 2; % DBPSK, but same constellation as 2-PAM
% refConst = pammod(data, constPoints);
% evm = comm.EVM('ReferenceSignalSource', 'Estimated from reference constellation', ...
%     'ReferenceConstellation', refConst);
% 
% rxFilterEVM = evm(receivedFilteredData);
% 
% rxTCorrectedEVM = evm(receivedTCorrectedData);
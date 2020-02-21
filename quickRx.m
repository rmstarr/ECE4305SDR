%% General parameters
sampleRateHz = 1e6;             % Sample Rate in Hz
visuals = true;                 % Used for displaying constellation
filterSymbolSpan = 10;           % Number of symbols filter spans
decimationFactor = 4;           % Downsampling factor
GainFactor = 30;                % Gain of received signal
SamplesPerFrame = 4096;         % Samples per frame of data         
inputSamplesPerSymbol = 4;     % Input samples in a single symbol

%% Receiver setup
Rx = sdrrx('Pluto', 'SamplesPerFrame', SamplesPerFrame, 'OutputDataType', 'double', 'GainSource', 'Manual', 'Gain', GainFactor);
Rx.BasebandSampleRate = sampleRateHz;

%% Digital Downsampling and Filtering
% Raised cosine filter to restructure samples
rcRxFilt = comm.RaisedCosineReceiveFilter('InputSamplesPerSymbol', inputSamplesPerSymbol, 'FilterSpanInSymbols', filterSymbolSpan, 'DecimationFactor', decimationFactor);
% filteredData = step(rcRxFilt, inputData);

%% Define Communication Object
fineSync = comm.CarrierSynchronizer('DampingFactor',1/sqrt(2), ...
'NormalizedLoopBandwidth',0.01, ...
'SamplesPerSymbol',1, ...
'Modulation','QPSK');

%% Timing synchronization object setup
timeSyncPLUTO = comm.SymbolSynchronizer('Modulation', 'PAM/PSK/QAM', ...
   'NormalizedLoopBandwidth', ...
    0.01);


%% Setup Constellation Object for Visualization
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Input');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'SymbolsToDisplaySource','Property',...
    'SymbolsToDisplay',SamplesPerFrame/2,...
    'Name','Output');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
ap = dsp.ArrayPlot;ap.ShowGrid = true;
ap.Title = 'Frequency Histogram';ap.XLabel = 'Hz';ap.YLabel = 'Magnitude';
ap.XOffset = -sampleRateHz/2;
ap.SampleIncrement = (sampleRateHz)/(2^10);
cdOut = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPreOut = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');

%% Model Received and Fine Frequency Compensated Data
while 1
    % Receive Data from Tx
    inputData = Rx();  
    
    % Fine Frequency Compensation
    receivedData = fineSync(inputData);
    raisedCos = rcRxFilt(receivedData);
    time = timeSyncPLUTO(raisedCos);
    
    % Display constellations
    if visuals
        step(cdPre,receivedData);
        step(cdPost,time);
        pause(0.1);
    end
    
release(cdPost);
end

%% EVM Analysis of the Signals
% constPoints = 4; % DBPSK, but same constellation as 2-PAM
% refConst = qammod(data, constPoints);
% evm = comm.EVM('ReferenceSignalSource', 'Estimated from reference constellation', ...
%     'ReferenceConstellation', refConst);
% 
% rxFilterEVM = evm(receivedFilteredData);
% 
% rxTCorrectedEVM = evm(receivedTCorrectedData);



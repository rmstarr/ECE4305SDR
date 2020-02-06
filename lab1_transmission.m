%% General system details
samplesPerSymbol = 1;
frameSize = 2^12; %Samples per frame 
numFrames = 30; % Will transmit these number of unique frames across the channel, not as important for transmission
numSamples = numFrames*frameSize; % Samples to simulate
modulationOrder = 2;
filterUpsample = 4; % Upsample rate (the decimation factor is half of this)
sampleRateHz = 1e6; % Sample rate
filterSymbolSpan = 8;
%% Generate symbols
data =  randi([0 samplesPerSymbol], numSamples, 1);
mod = comm.DBPSKModulator();
modulatedData = mod.step(data);
%% Add TX Filter
TxFlt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample, 'FilterSpanInSymbols', filterSymbolSpan);
filteredData = step(TxFlt, modulatedData);
%% Transmission of Data:
% Setup PlutoSDR object
% Note: The filtered data length needs to be equal to the size of the
% datarate
txPluto = sdrtx('Pluto','RadioID','usb:0','Gain', 0,'CenterFrequency',2.4e9, ...
               'BasebandSampleRate',sampleRateHz,'ChannelMapping',1);
 
% Continuously transmit the data repeatedly
txPluto.transmitRepeat(modulatedData);





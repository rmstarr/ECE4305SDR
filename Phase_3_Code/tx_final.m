%% BLE Final Transmitter
% Ethan Martin, Robert Starr, and Andrew Duncan
clear;
close;
visuals = true;

commSupportPackageCheck('BLUETOOTH');

%% Instantiation of BLE Parameters:

phyMode = 'LE1M';
bleTx = configBLEReceiver(phyMode);

%% Creation of BLE Advertsing Configuration and Data
T = readtable('sonar_2.csv', 'HeaderLines',1);  % skips the first three rows of data
data1 = table2array(T);
[rowsD,colsD] = size(data1);
data = reshape(data1, 1, rowsD*colsD);

% Data to send in the PDU
data2 = 0:0.1:1;


dataHex = num2hex(data);
[rows, cols] = size(dataHex);

datHex = reshape(dataHex,rows*8,2);
[R,C] = size(datHex);
% Check for the input: If the input is every greater than 255, then we
% remove the remaining bits from the end 
if R >= 251
    datHex(252:end, :) = [];
end

% % Configure an advertising channel PDU
% LLConfig = bleLLAdvertisingChannelPDUConfig;
% LLConfig.PDUType         = 'Advertising indication';
% LLConfig.AdvertisingData = datHex;
% LLConfig.AdvertiserAddress = '123456FFFFFF';
% 
% % Generate an advertising channel PDU
% message = bleLLAdvertisingChannelPDU(LLConfig);



%% Creation of BLE Connection Configuration and Data

LLConfig2 = bleLLDataChannelPDUConfig;
LLConfig2.CRCInitialization = '123456';
dataMessage = bleLLDataChannelPDU(LLConfig2, datHex);


%% Creation of Tx and Display Objects

% BLE Transmitted Waveform Generator
bleTxWave = bleWaveformGenerator(dataMessage, 'Mode', phyMode, 'SamplesPerSymbol', ...
    bleTx.SamplesPerSymbol, 'ChannelIndex', bleTx.ChannelIndex, 'AccessAddress', ...
    bleTx.AccessAddress);

% Setup the Spectrum Analyzer to view magnitude of Tx Data
SpectrumAnalyzer = dsp.SpectrumAnalyzer('SampleRate', bleTx.sampleRateHz, ...
    'SpectrumType', 'Power density', 'Title', 'Output Tx Signal Power', ...
    'YLabel', 'Power Spectral Density (dB/m)');

% Display the PSD of the BLE Waveform
SpectrumAnalyzer(bleTxWave);

%% Transmission for PLUTO

% Creation of PLUTO Tx Parameters
connectedRadios = findPlutoRadio;                               % Find connected Pluto
idTx = connectedRadios(1).RadioID;                              % Radio ID
centerFrequency = 2.402e9;                                      % Center frequency of Channel
txGain = 0;                                                     % Gain of Transmitter (dB)
txFrame = length(bleTxWave);                                    % Frame size to Tx
bbTxSampleRate = bleTx.SamplesPerSymbol*bleTx.symbolRate;     % Tx baseband sample rate

txPluto = sdrtx('Pluto', 'RadioID', idTx, 'CenterFrequency', centerFrequency, ...
    'Gain', txGain, 'SamplesPerFrame', txFrame, 'BasebandSampleRate', bbTxSampleRate);

% Continuously transmit BLE Wave
while true
    txPluto(bleTxWave)
end
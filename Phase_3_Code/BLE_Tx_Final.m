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

% Data to send in the PDU
data = "0123456789ABCDEF";

% Configure an advertising channel PDU
LLConfig = bleLLAdvertisingChannelPDUConfig;
LLConfig.PDUType         = 'Advertising indication';
LLConfig.AdvertisingData = data;
LLConfig.AdvertiserAddress = '1234567890AB';

% Generate an advertising channel PDU
message = bleLLAdvertisingChannelPDU(LLConfig);

%% Creation of Tx and Display Objects

% BLE Transmitted Waveform Generator
bleTxWave = bleWaveformGenerator(message, 'Mode', phyMode, 'SamplesPerSymbol', ...
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
bbTxSampleRate = bleTx.SamplesPerSymbol*bleTx.sampleRateHz;     % Tx baseband sample rate

txPluto = sdrtx('Pluto', 'RadioID', idTx, 'CenterFrequency', centerFrequency, ...
    'Gain', txGain, 'SamplesPerFrame', txFrame, 'BasebandSampleRate', bbTxSampleRate);

% Continuously transmit BLE Wave
while true
    txPluto(bleTxWave)
end

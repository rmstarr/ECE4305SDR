%% Project Phase 2: Computer Simulation
% Ethan Martin, Robert Starr, and Andrew Duncan
clear;
close;
visuals = true;

% Check to ensure BLE is supported by MATLAB
commSupportPackageCheck('BLUETOOTH');

%% General system details
sampleRateHz = 1e6;                     % Sample rate
samplesPerSymbol = 1;
frameSize = 2^3;                        % Size of data frame (1 byte)
numSamples = 2097;                      % Samples to simulate
modulationOrder = 2;
filterUpsample = 4;                     % Upsampling factor
filterSymbolSpan = 8;
inputSamplesPerSymbol = 4;              % Input samples in a single symbol
decimationFactor = 2;                   % Downsampling factor

%% Bluetooth Parameters
BLE_Mode = 'LE1M';                       % Use 1Msps for BLE
channel = 37;                           % Channel to transmit BLE data 

preamble = [0 1 0 1 0 1 0 1];           % 1 byte BLE preamble
accAddr = 'A8C8F245';                   % 4 bytes
PDUlength = 257;                        % amount of data in bytes
CRClength = 3;                          % will be defined based on what data ends up as

PDUbits = PDUlength*8;                  % Conversion of bytes to bits
rawData = ones(1, PDUbits);             % generation of "raw" data
CRCbits = CRClength*8;                  % CRC length in bits
CRC = zeros(1, CRCbits);                % Creation of empty CRC

accAddrBinary = hexToBinaryVector(accAddr);

dataPacket = [preamble accAddrBinary rawData CRC];

% turn to column vector
dataPacket = dataPacket';

%% Impairments
snr = 15;
% frequencyOffsetHz = sampleRateHz*0.02; % Offset in hertz
% phaseOffset = 0; % Radians

%% Generate symbols
modulatedData = mod.step(dataPacket);

%% Add noise
noisyData = awgn(modulatedData,snr);%,'measured');

%% Raised Cosine Filter on TX Side
txFilt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample,...
    'FilterSpanInSymbols', filterSymbolSpan);
filteredData = step(txFilt, noisyData);

%% Transmit the Data in BLE
bleTx = bleWaveformGenerator(filteredData, 'Mode', BLE_Mode, 'ChannelIndex', channel,...
    'SamplesPerSymbol', samplesPerSymbol, 'AccessAddress', accAddr);

%----------------------------------------------------------------------
%----------------------------------------------------------------------
%% Start of RX
% 1) AGC (Gain) - done
% 2) Remove DC Offset - done
% 3) Match filter - done
% 4) Frequency Offset Correction - done
% 5) Synchronization (Don't worry about for now) 
% 6) Demodulation
% 7) Decoding & Pattern De-mapping
% 8) De-whitening
% 9) CRC Check

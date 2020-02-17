%% Project Phase 2: Computer Simulation
% Ethan Martin, Robert Starr, and Andrew Duncan
clear;
close;
visuals = true;

% Check to ensure BLE is supported by MATLAB
% commSupportPackageCheck('BLUETOOTH');

%% General system details
sampleRateHz = 1e6;                     % Sample rate
samplesPerSymbol = 1;
frameSize = 2^3;                        % Size of data frame (1 byte)
modulationOrder = 2;
filterUpsample = 4;                     % Upsampling factor
filterSymbolSpan = 8;
inputSamplesPerSymbol = 4;              % Input samples in a single symbol
decimationFactor = 2;  
SamplesPerFrame = 4096;         % Samples per frame of data% Downsampling factor



%% Bluetooth Parameters
BLE_Mode = 'LE1M';                       % Use 1Msps for BLE
channel = 35;                           % Channel to transmit BLE data 

preamble = [0 1 0 1 0 1 0 1];           % 1 byte BLE preamble
accAddr = 'A8C8F245';                   % 4 bytes
PDUlength = 257;                        % amount of data in bytes
CRClength = 3;                          % will be defined based on what data ends up as

PDUbits = PDUlength*8;                  % Conversion of bytes to bits
rawData = ones(1, PDUbits);             % generation of "raw" data
CRCbits = CRClength*8;                  % CRC length in bits
CRC = zeros(1, CRCbits);                % Creation of empty CRC

accAddrBinary = hexToBinaryVector(accAddr)';

%dataPacket = [preamble accAddrBinary rawData CRC];

% turn to column vector
%dataPacket = dataPacket';

DATA_NO_HEADER = [rawData CRC]';

numSamples = length(DATA_NO_HEADER);                      % Samples to simulate

%% Impairments
snr = 15;
% frequencyOffsetHz = sampleRateHz*0.02; % Offset in hertz
% phaseOffset = 0; % Radians

% %% Generate symbols   - Probably don't need, GF/MSK modulation happens in
% bleTX
% modulatedData = mod.step(dataPacket);


%% Transmit the Data in BLE
bleTx = bleWaveformGenerator(DATA_NO_HEADER, 'Mode', BLE_Mode, 'ChannelIndex', channel,...
    'SamplesPerSymbol', samplesPerSymbol, 'AccessAddress', accAddrBinary);


%% Raised Cosine Filter


TxFlt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample, 'FilterSpanInSymbols', filterSymbolSpan);
filteredData = step(TxFlt, bleTx);
%% Add RF Imparements to signal to recover 

% send through awgn channel
noisyData = awgn(filteredData,snr);%,'measured');

% Apply Frequency Offset
frequencyOffsetHz = 10000;
% Add frequency offset to noisy data.
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;
offsetData = zeros(size(noisyData));
for k=1:frameSize:numSamples
    
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = noisyData(timeIndex).*freqShift;
end
%% Steps to Receiver:

% 1. Automatic gain control (AGC) 
% 2. DC removal 
% 3. Carrier frequency offset correction 
% 4. Matched filtering
% 5. Packet detection
% 6. Timing error correction
% 7. Demodulation and decoding
% 8. Dewhitening


% Initialize Receiver Objects and Variables:


% Bluetooth Object 
phyMode = 'LE1M';
bleParam = helperBLEReceiverConfig(phyMode);

%AGC
agc = comm.AGC('MaxPowerGain',20,'DesiredOutputPower',2);

% FFC
loopBand = 0.05; % Loop bandwidt
lamda = 1 / sqrt(2) ; % Dampening Factor
fineSync = comm.CarrierSynchronizer('DampingFactor',lamda, ...
    'NormalizedLoopBandwidth',loopBand, ...
    'SamplesPerSymbol',samplesPerSymbol, ...
    'Modulation','QPSK');
preDet = comm.PreambleDetector(bleParam.RefSeq,'Detections','First');

% Initialize counter variables
pktCnt = 0;
crcCnt = 0;
displayFlag = true; % true if the received data is to be printed


%% Automatic Gain Control
agcData = agc(offsetData);

%% DC removal
% Subtract the mean from the signal.
dcData = agcData - mean(agcData);
%% Match Filtering:
% Raised cosine filter to restructure samples
rcRxFilt = comm.RaisedCosineReceiveFilter('InputSamplesPerSymbol', inputSamplesPerSymbol, 'FilterSpanInSymbols', filterSymbolSpan, 'DecimationFactor', decimationFactor);
filteredData = step(rcRxFilt, dcData);

%% Carrier Frequency Offset Correction (Our implementation)
freqAdjust = fineSync(filteredData);
% 

%% Timing Synchronization:

% Not gonna do, we'll have this complete when we do the thing
% Haven't done yet. Can we find a way to do it without actually
% implementing it on our own? We'll take a look at 

% Perform frame timing synchronization

% Code from example. Don't know what it does, but it contains information
% we need to complete the receiver structure. 

%% Demodulation
% 
gDemod = comm.GMSKDemodulator('BandwidthTimeProduct', 0.5, 'PulseLength', 1, 'SamplesPerSymbol', samplesPerSymbol);
extractedData = gDemod(filteredData); % Demodulate the Data
%% Encoding, (Demodulation), Dewhittening, and extraction of Data:

% NOTE: WHEN IMPLEMENTING, DOUBLE CHECK THAT YOU DO DEMODULATION ONLY ONCE.
% CURRENTLY THE FUNCTION HERE DOES DEMODULATION. SO BEFORE RUNNING THE
% PROGRAM, DELETE ONE OF THOSE. 
[dewhitenedBits,pktCnt,crcCnt,startIdx] = helperBLEPhyBitRecover_Data_No_Time_Comp(extractedData,pktCnt,crcCnt,bleParam);


% Release Receiver Objects:

release(preDet);
release(fineSync);
release(agc);

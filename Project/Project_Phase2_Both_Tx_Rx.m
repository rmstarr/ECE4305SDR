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
rcTxFilt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample,...
    'FilterSpanInSymbols', filterSymbolSpan);
filteredTxData = step(rcTxFilt, noisyData);

%% Transmit the Data in BLE
bleTx = bleWaveformGenerator(filteredTxData, 'Mode', BLE_Mode, 'ChannelIndex', channel,...
    'SamplesPerSymbol', samplesPerSymbol, 'AccessAddress', accAddr);


%% Start of RX
%% Automatic Gain Control
rxAGC = comm.AGC('DesiredOutputPower', 1);
rxSigGain = rxAGC(bleTx);


%% DC Offset Correction
%------------------------------%

%% Digital Downsampling and Filtering
rcRxFilt = comm.RaisedCosineReceiveFilter('InputSamplesPerSymbol', inputSamplesPerSymbol, 'FilterSpanInSymbols', filterSymbolSpan, 'DecimationFactor', decimationFactor);
filteredRxData = step(rcRxFilt, rxSigGain);

%% Fine Frequency Compensator Variable initialization:

loopBand = 0.05; % Loop bandwidth
lamda = 1 / sqrt(2) ; % Dampening Factor
M = 4; % Constellation Order

theta = loopBand / (M * (lamda + (0.25/lamda)));
delta = 1 + 2*lamda*theta+theta^2;

% Define the PLL Gains:
G1 = (4*lamda*theta / delta) / M;
G2 = ((4/M) * theta^2 / delta) / M;

%% Define Communication Object - will change to GMSK (including Gaussian filter)

% Use OQPSK for demodulation with BLE's GFSK modulation
fineSync = comm.CarrierSynchronizer('DampingFactor',lamda, ...
'NormalizedLoopBandwidth',loopBand,'SamplesPerSymbol',samplesPerSymbol, ...
'Modulation','OQPSK');

%% Model of error
% Add frequency offset to baseband signal

% Precalculate constants
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;

Phase = zeros(1:length(numSamples));
offsetData = zeros(size(noisyData));
for k=1:frameSize:numSamples
    
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = noisyData(timeIndex).*freqShift;
    % Fine Frequency Compensation
    [rxData] = fineSync(offsetData);
    [~, phaseOff] = fineSync(offsetData);
    
    % Take phase offset, put inside a vector
    % Take differentiation of it
    % Plot it
    
    Phase(k:k+frameSize-1) = phaseOff(timeIndex);
%     if visuals
%         step(cdPre,noisyData(timeIndex));
%         step(cdPre,offsetData(timeIndex));
%         step(cdPost,rxData(timeIndex));pause(0.1); %#ok<*UNRCH>
%     end

end

%% Synchronization
%-------------------------

%% Demodulation

comm.OQPSKDemodulator()

%% Decode & Pattern De-mapping

%% De-whitening


%% CRC Check


%% Error Rate Calculation 

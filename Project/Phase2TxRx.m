%% Project Phase 2: Computer Simulation
% Ethan Martin, Robert Starr, and Andrew Duncan
clear;
close;
visuals = true;

% Check to ensure BLE is supported by MATLAB
% commSupportPackageCheck('BLUETOOTH');

%% General system details
sampleRateHz = 1e6;                     % Sample rate
samplesPerSymbol = 8;
frameSize = 2^3;                        % Size of data frame (1 byte)
modulationOrder = 2;
filterUpsample = 4;                     % Upsampling factor
filterSymbolSpan = 8;
inputSamplesPerSymbol = 4;              % Input samples in a single symbol
decimationFactor = 2;                   % Downsampling factor

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
frequencyOffsetHz = sampleRateHz*0.02; % Offset in hertz
phaseOffset = 0; % Radians

% %% Generate symbols   - Probably don't need, GF/MSK modulation happens in
% bleTX
% modulatedData = mod.step(dataPacket);


%% Transmit the Data in BLE
bleTx = bleWaveformGenerator(DATA_NO_HEADER, 'Mode', BLE_Mode, 'ChannelIndex', channel,...
    'SamplesPerSymbol', samplesPerSymbol, 'AccessAddress', accAddrBinary);

% LOL Ethan pls help plot the mag. response
% numSamples = length(bleTx);
% magResp = abs(bleTx);
% plot(magResp);
%% Raised Cosine Filter on TX Side
rcTxFilt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample,...
    'FilterSpanInSymbols', filterSymbolSpan);
filteredTxData = step(rcTxFilt, bleTx);
% LOL Ethan pls help plot the mag. response
% filteredMagResp = abs(filteredTxData);
% plot(filteredMagResp);
%% Add noise
noisyData = awgn(bleTx,snr);%,'measured');

%% Start of RX
%% Automatic Gain Control
rxAGC = comm.AGC('DesiredOutputPower', 1);
rxSigGain = rxAGC(noisyData);

%% DC Offset Correction
rxSigNoDC = rxSigGain - mean(rxSigGain);

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
offsetData = zeros(size(filteredRxData));
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

%% Demodulation
rxDataDemod = gmskDemod(rxData,samplesPerSymbol);

%% Decode & Pattern De-mapping
rxDataNoPreamble = rxDataDemod(8:end); % I believe it is 8 bits long
recovAccAddr = int8(rxDataNoPreamble(1:32));
recovData = int8(rxDataNoPreamble(33:end));

%% De-whitening
dewhitenStateLen = 6;
chIndex = rem(floor(channel*pow2(1-dewhitenStateLen:0)),2);
initState = [1 chIndex]; % Initial conditions of shift register
bitOutput = whiten(recovData, initState);

%% CRC Check

%% Error Rate Calculation 

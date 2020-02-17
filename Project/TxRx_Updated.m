%% Project Phase 2: Computer Simulation
% Ethan Martin, Robert Starr, and Andrew Duncan
clear all;
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

DATA_NO_HEADER = [rawData CRC]';

numSamples = length(DATA_NO_HEADER);                      % Samples to simulate

%% Impairments
% Iterate across a range of SNR values
snr = 0:1:20;

%% Transmit the Data in BLE
bleTx = bleWaveformGenerator(DATA_NO_HEADER, 'Mode', BLE_Mode, 'ChannelIndex', channel,...
    'SamplesPerSymbol', samplesPerSymbol, 'AccessAddress', accAddrBinary);

%% Add RF Imparements to signal to recover
for i = 1:length(snr)
    [numErrs,perCnt] = deal(0);
    numPkt = 1;
    % send through awgn channel
    noisyData = awgn(bleTx,snr(i));%,'measured');
    
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
    % 5. Packet Detection
    % 6. Timing Correction
    % 7. Demodulation and decoding
    % 8. Dewhitening
    
    %% Start of RX
    %% 1. Automatic Gain Control
    rxAGC = comm.AGC('DesiredOutputPower', 1);
    rxSigGain = rxAGC(offsetData);
    
    %% 2. DC Offset Correction
    rxSigNoDC = rxSigGain - mean(rxSigGain);
    
    %% 3a. Fine Frequency Compensator Variable initialization:
    
    loopBand = 0.05; % Loop bandwidth
    lamda = 1 / sqrt(2) ; % Dampening Factor
    M = 4; % Constellation Order
    
    theta = loopBand / (M * (lamda + (0.25/lamda)));
    delta = 1 + 2*lamda*theta+theta^2;
    
    % Define the PLL Gains:
    G1 = (4*lamda*theta / delta) / M;
    G2 = ((4/M) * theta^2 / delta) / M;
    
    %% 3b. FFC
    
    % Use OQPSK for demodulation with BLE's GFSK modulation
    fineSync = comm.CarrierSynchronizer('DampingFactor',lamda, ...
        'NormalizedLoopBandwidth',loopBand,'SamplesPerSymbol',samplesPerSymbol, ...
        'Modulation','OQPSK');
    
    rxData = fineSync(offsetData);
    
    %% 4. Matched Filtering
    initRxParams = helperBLEReceiverInit(BLE_Mode,samplesPerSymbol,accAddrBinary);
    rxFilteredData = conv(rxData,initRxParams.h,'same');
    
    %     %% 5. Timing Correction
    %     timrecDelay = 2;
    %     rxFilteredData = [rxFilteredData;zeros(timrecDelay*initRxParams.sps,1)];
    %     rxWfmTimeComp = initRxParams.gmsktSync(rxFilteredData);
    %     rxWfmTimeComp = rxWfmTimeComp(timrecDelay+1:end); % Remove the delays
    %
    %     %% 6. Packet Detection
    %     rxDataTimeSync = preambleDetection(rxWfmTimeComp,initRxParams);
    
    %% 5a. Demodulation
    rxDataDemod = gmskDemod(rxFilteredData,samplesPerSymbol);
    
    %% 5b. Decode & Pattern De-mapping
    rxDataNoPreamble = rxDataDemod(8:end); % I believe it is 8 bits long
    recovAccAddr = int8(rxDataNoPreamble(1:32));
    recovData = int8(rxDataNoPreamble(33:end));
    
    %% 6. De-whitening
    dewhitenStateLen = 6;
    chIndex = rem(floor(channel*pow2(1-dewhitenStateLen:0)),2);
    initState = [1 chIndex]; % Initial conditions of shift register
    bitOutput = whiten(recovData, initState);
    
    %% CRC Check
    
    %% Error Rate Calculation
    errorRate = comm.ErrorRate('Samples','Custom',...
        'CustomSamples',1:(2080-1));
    
    % Determine the BER and PER
    if(length(DATA_NO_HEADER) == length(bitOutput))
        errors = errorRate(DATA_NO_HEADER,bitOutput); % Outputs the accumulated errors
        ber(BLE_Mode,snr) = errors(1);       % Accumulated BER
        currentErrors = errors(2)-numErrs; % Number of errors in current packet
        if(currentErrors) % Check if current packet is in error or not
            perCnt  = perCnt + 1;          % Increment the PER count
        end
        numErrs = errors(2);               % Accumulated errors
        numPkt = numPkt + 1;
    end
%     per(BLE_Mode,snr) = perCnt/(numPkt-1);
end







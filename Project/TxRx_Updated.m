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
    % 5. Demodulation and decoding
    % 6. Dewhitening
    
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
    
end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
%     % Initialize Receiver Objects and Variables:
%     % Bluetooth Object
%     phyMode = 'LE1M';
%     bleParam = helperBLEReceiverConfig(phyMode);
%     
%     sigSrc = comm.BasebandFileReader(bbFileName);
%     bbSampleRate = sigSrc.SampleRate;
%     sigSrc.SamplesPerFrame = 1e7;
%     bleParam.SamplesPerSymbol = bbSampleRate/bleParam.SymbolRate;
%     
%     % *Capture the BLE Packets*
%     
%     % The transmitted waveform is captured as a burst
%     dataCaptures = sigSrc();
%     
%     %AGC
%     agc = comm.AGC('MaxPowerGain',20,'DesiredOutputPower',2);
%     
%     % FFC
%     loopBand = 0.05; % Loop bandwidt
%     lamda = 1 / sqrt(2) ; % Dampening Factor
%     fineSync = comm.CarrierSynchronizer('DampingFactor',lamda, ...
%         'NormalizedLoopBandwidth',loopBand, ...
%         'SamplesPerSymbol',samplesPerSymbol, ...
%         'Modulation','QPSK');
%     
%     %% Automatic Gain Control
%     % Increase gain of transmitted BLE signal
%     agcData = agc(bleTx);
%     
%     %% DC removal
%     % Subtract the mean from the signal.
%     dcData = agcData - mean(agcData);
%     
%     %% Carrier Frequency Offset Correction (Our implementation)
%     freqAdjust = fineSync(dcData);
%     
%     %% Everything Else
%     prbDet = comm.PreambleDetector(bleParam.RefSeq,'Detections','First');
%     % Initialize counter variables
%     pktCnt = 0;
%     crcCnt = 0;
%     displayFlag = true; % true if the received data is to be printed
%     dataCaptures = length(DATA_NO_HEADER);
%     % Loop to decode the captured BLE samples
%     while length(dataCaptures) > bleParam.MinimumPacketLen
%         
%         % Consider two frames from the captured signal for each iteration
%         startIndex = 1;
%         endIndex = min(length(dataCaptures),2*bleParam.FrameLength);
%         rcvSig = dataCaptures(startIndex:endIndex);
%         
%         rcvAGC = agc(rcvSig); % Perform AGC
%         rcvDCFree = rcvAGC - mean(rcvAGC); % Remove the DC offset
%         rcvFreqComp = freqCompensator(rcvDCFree); % Estimate and compensate for the carrier frequency offset
%         rcvFilt = conv(rcvFreqComp,bleParam.h,'same'); % Perform gaussian matched filtering
%         
%         % Perform frame timing synchronization
%         [~, dtMt] = prbDet(rcvFilt);
%         release(prbDet)
%         prbDet.Threshold = max(dtMt);
%         prbIdx = prbDet(rcvFilt);
%         
%         % Extract message information
%         [cfgLLAdv,pktCnt,crcCnt,remStartIdx] = helperBLEPhyBitRecover(rcvFilt,...
%             prbIdx,pktCnt,crcCnt,bleParam);
%         
%         % Remaining signal in the burst captures
%         dataCaptures = dataCaptures(1+remStartIdx:end);
%         
%         % Display the decoded information
%         if displayFlag && ~isempty(cfgLLAdv)
%             fprintf('Advertising PDU Type: %s\n', cfgLLAdv.PDUType);
%             fprintf('Advertising Address: %s\n', cfgLLAdv.AdvertiserAddress);
%         end
%         
%         % Release System objects
%         release(freqCompensator)
%         release(prbDet)
%     end
%     
%     % Release the signal source
%     %     release(sigSrc)
%     
%     % Determine the PER
%     if pktCnt
%         per(i) = 1-(crcCnt/pktCnt);
%         fprintf('Packet error rate for %s mode is %f.\n',bleParam.Mode,per);
%     else
%         fprintf('\n No BLE packets were detected.\n')
%     end
%     
% end
% %% Data Display
% 
% % Plot of SNR versus PER
% plot(snr, per)
% title('PER Versus SNR')
% xlabel('SNR (dB)')
% ylabel('PER')
% 
% 
% %% Stuff Removed
% % %% Gaussian Match Filtering:
% %
% % rcvFilt = conv(freqAdjust, bleParam.h, 'same');
% % %% Timing Synchronization:
% %
% % % Perform frame timing synchronization
% %
% % [~, mt] = prbDet(rcvFilt);
% % %disp(mt);
% % release(prbDet);
% % prbDet.Threshold = max(mt);
% % prbInd = prbDet(rcvFilt);
% %
% % %% Demodulation
% %
% %
% % %% Encoding, (Demodulation), Dewhittening, and extraction of Data:
% %
% % %[bits, accessAddress] = bleReceiverPractical(gDemod,bleParam, channel, initRxParams);
% % [cfgllData,pktCnt,crcCnt,startIdx] = dataBLEPhyBitRecover(rcvFilt, prbInd,pktCnt,crcCnt,bleParam);
% %
% % % Release Receiver Objects:
% % disp(cfgllData)
% %
% % release(fineSync);
% % release(agc);
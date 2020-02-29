% BLE Receiver Function:

% Below is the construction of our BLE Receiver at the physical layer
% level. The process of reconstruction is as follows:

% 1. 
% 2.
% 3.
% 4.
% 5.
% 6.
% 7.
% 8.


%% Initialize Adalm Pluto Environment:
phyMode = 'LE1M';
bleObj = configBLEReceiver(phyMode);

sigSrc = sdrrx('Pluto',...
    'RadioID',             'usb:0',...
    'CenterFrequency',     2.402e9,...
    'BasebandSampleRate',  bleObj.sampleRateHz,...
    'SamplesPerFrame',     1e6,...
    'GainSource',         'Manual',...
    'Gain',                30,...
    'OutputDataType',     'double');

%% Receiver Object Initialization:

% Automatic Gain Control:
rxAGC = comm.AGC('DesiredOutputPower', 1);

    
loopBand = 0.05; % Loop bandwidth
lamda = 1 / sqrt(2) ; % Dampening Factor
% Use OQPSK for demodulation with BLE's GFSK modulation
fineSync = comm.CarrierSynchronizer('DampingFactor',lamda, ...
    'NormalizedLoopBandwidth',loopBand,'SamplesPerSymbol',bleObj.samplesPerSymbol, ...
    'Modulation','OQPSK');

% Timing Synchronization Object:
timeSync =  comm.SymbolSynchronizer('Modulation', 'PAM/PSK/QAM', 'NormalizedLoopBandwidth', 0.01);

%% Collect Data from the signal source;

% Fills our buffer array
receivedSig = sigSrc(); % Has 1e7 samples (bits)

%Number of packets we could have in a single stream. This value will be
%smaller when we process all the packets. 
numPackets_Theoretical = 1e6 / bleObj.samplesPerPacket;


%% Receiver Processing:

% AGC on the received signal
receivedSigADC = rxAGC(receivedSig);
% Remove DC offset
receivedSignalDCFree = receivedSigADC - mean(receivedSigADC);
% Frequency Compensation:
receivedSigFreq = fineSync(receivedSignalDCFree);
% Gaussian Matched Filtering 
receivedSigMatched = conv(receivedSigFreq,bleObj.filt,'same'); % Perform gaussian matched filtering
% Time Compensation
receivedSigTimed = timeSync(receivedSigMatched);
% GMSK demodulation NOTE(Matlab reference performed this operation after the preamble detection. For our implementation, we're
% gonna try it before, and see if we can detect the right bits.)

receivedDemod = gmskDemod(receivedSigTimed, bleObj.SamplesPerSymbol);

%% PHY LAYER RECOVERY: 

% Step 1: Determine valid packet's based on the input demodulated data
[packets, numPackets] = preambleDetect(receivedDemod,bleObj);


% Step 2: Do the rest of the PHY processing:

packetLength = bleObj.packetLength;
PER = 0; % Packet Error Rate
packetOutput = [];
crcCount = 0;
for i = i:packetLength:packets
    
    timeIndex = i:i+packetLength - 1;
    [pduData, error] = phyRecover(packets(timeIndex), numPackets, bleObj);
    if error == 0
        crcCount = crcCount + 1;
        pduHEX = binaryVectorToHex(pduData);
        pduStr = char(hex2dec(pduHEX));
        % Insert string data into the pdu vector for output
        packetOutput(crcCount) = pduStr;
        disp('Packet number', char(crcCount), 'is equal to', pduStr);
    end
    %Packet Error Rate 
    PER = 1 - (crcCount/numPackets);
    disp('Packet Error rate equals', char(PER));
    pause(0.75);
end









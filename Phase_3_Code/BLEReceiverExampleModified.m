%% Bluetooth Low Energy Receiver

%% Check for Support Package Installation

% Check if the 'Communications Toolbox Library for the Bluetooth Protocol'
% support package is installed or not.
commSupportPackageCheck('BLUETOOTH');

%% Example Structure
%
% The general structure of the BLE receiver example is described as
% follows:
%
% # Initialize the receiver parameters
% # Signal source
% # Capture the BLE packets
% # Receiver processing

%%
% *Initialize the Receiver Parameters*
%
% The <matlab:edit('helperBLEReceiverConfig.m') helperBLEReceiverConfig.m>
% script initializes the receiver parameters. You can change |phyMode|
% parameter to decode the received BLE waveform based on the PHY
% transmission mode. |phyMode| can be one from the set:
% {'LE1M','LE2M','LE500K','LE125K'}.

phyMode = 'LE1M';
bleParam = helperBLEReceiverConfigModified(phyMode);

%%

% First check if the HSP exists
if isempty(which('plutoradio.internal.getRootDir'))
    error(message('comm_demos:common:NoSupportPackage', ...
        'Communications Toolbox Support Package for ADALM-PLUTO Radio',...
        ['<a href="https://www.mathworks.com/hardware-support/' ...
        'adalm-pluto-radio.html">ADALM-PLUTO Radio Support From Communications Toolbox</a>']));
end

bbSampleRate = bleParam.SymbolRate * bleParam.SamplesPerSymbol;
sigSrc = sdrrx('Pluto',...
    'RadioID',             'usb:0',...
    'CenterFrequency',     2.476e9,...
    'BasebandSampleRate',  bbSampleRate,...
    'SamplesPerFrame',     1e7,...
    'GainSource',         'Manual',...
    'Gain',                20,...
    'OutputDataType',     'double');

% Setup spectrum viewer
spectrumScope = dsp.SpectrumAnalyzer( ...
    'SampleRate',       bbSampleRate,...
    'SpectrumType',     'Power density', ...
    'SpectralAverages', 10, ...
    'YLimits',          [-130 -30], ...
    'Title',            'Received Baseband BLE Signal Spectrum', ...
    'YLabel',           'Power spectral density');

%%
% *Capture the BLE Packets*

% The transmitted waveform is captured as a burst
dataCaptures = sigSrc();

% Show power spectral density of the received waveform
spectrumScope(dataCaptures);

%%
% *Receiver Processing*
%
% The baseband samples received from the signal source are processed to
% decode the PDU header information and raw message bits. The following
% diagram shows the receiver processing.
%
% <<../BLEReceiverFlow.png>>
%
% # Perform automatic gain control (AGC)
% # Remove DC offset
% # Estimate and correct for the carrier frequency offset
% # Perform matched filtering with gaussian pulse
% # Timing synchronization
% # GMSK demodulation
% # FEC decoding and pattern demapping for LECoded PHYs (LE500K and LE125K)
% # Data dewhitening
% # Perform CRC check on the decoded PDU
% # Compute packet error rate (PER)

% Initialize System objects for receiver processing
agc = comm.AGC('MaxPowerGain',20,'DesiredOutputPower',2);

freqCompensator = comm.CoarseFrequencyCompensator('Modulation', 'OQPSK',...
    'SampleRate',bbSampleRate,...
    'SamplesPerSymbol',2*bleParam.SamplesPerSymbol,...
    'FrequencyResolution',100);

prbDet = comm.PreambleDetector(bleParam.RefSeq,'Detections','First');

% Initialize counter variables
pktCnt = 0;
crcCnt = 0;
displayFlag = true; % true if the received data is to be printed
perVals = [];
collectedData = [];
int = 0;

tStamps = datetime('now')-minutes(11):minutes(1):datetime('now');
channelID = 1009015;
writeKey = 'L7C6E68PQQKAP61S';

% Loop to decode the captured BLE samples
while length(dataCaptures) > bleParam.MinimumPacketLen
    
    % Consider two frames from the captured signal for each iteration
    startIndex = 1;
    skip = 0;
    endIndex = min(length(dataCaptures),2*bleParam.FrameLength);
    rcvSig = dataCaptures(startIndex:endIndex);
    
    rcvAGC = agc(rcvSig); % Perform AGC
    rcvDCFree = rcvAGC - mean(rcvAGC); % Remove the DC offset
    rcvFreqComp = freqCompensator(rcvDCFree); % Estimate and compensate for the carrier frequency offset
    rcvFilt = conv(rcvFreqComp,bleParam.h,'same'); % Perform gaussian matched filtering
    
    % Perform frame timing synchronization
    [~, dtMt] = prbDet(rcvFilt);
    release(prbDet)
    prbDet.Threshold = max(dtMt);
    prbIdx = prbDet(rcvFilt);
    
    % Extract message information
    [cfgLLData,pktCnt,crcCnt,remStartIdx, payload] = helperBLEPhyBitRecoverModified(rcvFilt,...
        prbIdx,pktCnt,crcCnt,bleParam);
    
    % Remaining signal in the burst captures
    dataCaptures = dataCaptures(1+remStartIdx:end);
    
    % Convert the binary back to original type - display results
    [rows, cols] = size(payload);
    hexNum = floor(rows/8);
    leftovers = mod(rows, 8);
    
    if leftovers ~= 0
        payload = payload(1 : hexNum*8, :);
        [rows, cols] = size(payload);
        if cols == 0
            skip = 1;  % Eliminate edge case where we return nothing
        end
        
    end
    
    % Only collect and display data if we get it
    
    if skip == 0
        decodedData = char(reshape(payload, (rows/8), 16));
        decodedData2 = hex2num(decodedData);
        if displayFlag && ~isempty(cfgLLData)
            disp('Decoded Data:')
            disp(decodedData2);
        end
        
        % Send data to ThingSpeak
        if ~(isempty(decodedData2))
            thingSpeakWrite(channelID, decodedData2, 'TimeStamp', tStamps, 'WriteKey', writeKey);
            disp('done');
            pause(15);
        end
    
    else
        disp('Packet lost in transmission...') % Double check w/ Kuldeep
    end
    
    % Parse out Joystick Data
%     xVals = decodedData2(1:(length(decodedData2)/2));
%     yVals = decodedData2(((length(decodedData2)/2)+1):(length(decodedData2)));    
    
    % Display the decoded information
    %     if displayFlag && ~isempty(cfgLLData)
    %         disp('Decoded Data:')
    %         disp(decodedData2);
    %     end
    
    % Release System objects
    release(freqCompensator)
    release(prbDet)
    
    perVals = [perVals, 1-(crcCnt/pktCnt)];
    
    int = int+1;
end

t = 1:int;
figure;
plot(t, perVals(t));
title('PER of a single transmission vs. Time');
xlabel('Packet Number');
ylabel('Error Rate');

% Release the signal source
release(sigSrc)

% Determine the PER
if pktCnt
    per = 1-(crcCnt/pktCnt);
    fprintf('Packet error rate for %s mode is %f.\n',bleParam.Mode,per);
else
    fprintf('\n No BLE packets were detected.\n')
end

%% BLE Receiver
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

%% Our implementation

% phyMode = 'LE1M';
% sampleRateHz = 1e6;
% samplesPerSymbol = 8;
% RxSampleRate = sampleRateHz*samplesPerSymbol;
% rxCenterFrequency = 2.476e9;
% 
% rx = sdrrx('Pluto',...
%     'RadioID',             'usb:0',...
%     'CenterFrequency',     rxCenterFrequency,...
%     'BasebandSampleRate',  RxSampleRate,...
%     'SamplesPerFrame',     1e7,...
%     'GainSource',         'Manual',...
%     'Gain',                25,...
%     'OutputDataType',     'double');
% 
% % modData = zeros(1, 318000);
% % for i=1:length(modData)
% dataCaptures = rx();

%% MATLAB BLE Receiver

phyMode = 'LE1M';
bleParam = helperBLEReceiverConfig(phyMode);

%%
signalSource = 'File'; % The default signal source is 'File'

if strcmp(signalSource,'File')
    switch bleParam.Mode
        case 'LE1M'
            bbFileName = 'bleCapturesLE1M.bb';
        case 'LE2M'
            bbFileName = 'bleCapturesLE2M.bb';
        case 'LE500K'
            bbFileName = 'bleCapturesLE500K.bb';
        case 'LE125K'
            bbFileName = 'bleCapturesLE125K.bb';
        otherwise
            error('Invalid PHY transmission mode. Valid entries are LE1M, LE2M, LE500K and LE125K.');
    end
    sigSrc = comm.BasebandFileReader(bbFileName);
    bbSampleRate = sigSrc.SampleRate;
    sigSrc.SamplesPerFrame = 1e7;
    bleParam.SamplesPerSymbol = bbSampleRate/bleParam.SymbolRate;

elseif strcmp(signalSource,'ADALM-PLUTO')

    bbSampleRate = bleParam.SymbolRate * bleParam.SamplesPerSymbol;
    sigSrc = sdrrx('Pluto',...
        'RadioID',             'usb:0',...
        'CenterFrequency',     2.402e9,...
        'BasebandSampleRate',  bbSampleRate,...
        'SamplesPerFrame',     1e7,...
        'GainSource',         'Manual',...
        'Gain',                25,...
        'OutputDataType',     'double');
else
    error('Invalid signal source. Valid entries are File and ADALM-PLUTO.');
end

% Setup spectrum viewer
spectrumScope = dsp.SpectrumAnalyzer( ...
    'SampleRate',       bbSampleRate,...
    'SpectrumType',     'Power density', ...
    'SpectralAverages', 10, ...
    'YLimits',          [-130 -30], ...
    'Title',            'Received Baseband BLE Signal Spectrum', ...
    'YLabel',           'Power spectral density');

%%
% The transmitted waveform is captured as a burst
dataCaptures = sigSrc();

% Show power spectral density of the received waveform
spectrumScope(dataCaptures);

%%
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
displayFlag = false; % true if the received data is to be printed

% Loop to decode the captured BLE samples
while length(dataCaptures) > bleParam.MinimumPacketLen

    % Consider two frames from the captured signal for each iteration
    startIndex = 1;
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
    [cfgLLAdv,pktCnt,crcCnt,remStartIdx] = helperBLEPhyBitRecover(rcvFilt,...
                                prbIdx,pktCnt,crcCnt,bleParam);

    % Remaining signal in the burst captures
    dataCaptures = dataCaptures(1+remStartIdx:end);

    % Display the decoded information
    if displayFlag && ~isempty(cfgLLAdv)
        fprintf('Advertising PDU Type: %s\n', cfgLLAdv.PDUType);
        fprintf('Advertising Address: %s\n', cfgLLAdv.AdvertiserAddress);
    end

    % Release System objects
    release(freqCompensator)
    release(prbDet)
end

% Release the signal source
release(sigSrc)

% Determine the PER
if pktCnt
    per = 1-(crcCnt/pktCnt);
    fprintf('Packet error rate for %s mode is %f.\n',bleParam.Mode,per);
else
    fprintf('\n No BLE packets were detected.\n')
end

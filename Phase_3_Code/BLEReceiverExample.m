%% Bluetooth Low Energy Receiver
% This example shows how to implement a Bluetooth(R) Low Energy (BLE)
% receiver using the Communications Toolbox(TM) Library for the Bluetooth
% Protocol. You can either use captured signals or receive signals in real
% time using the ADALM-PLUTO Radio. A suitable signal for reception can be
% generated by simulating the companion example,
% <docid:comm_examples#example-blueBLETransmitterExample Bluetooth Low
% Energy Transmitter>, with any one of the following setup: (i) Two SDR
% platforms connected to the same host computer which runs two MATLAB
% sessions (ii) Two SDR platforms connected to two computers which run
% separate MATLAB sessions.
%
% Refer to the <docid:plutoradio_ug#bvn89q2-14> documentation for details
% on how to configure your host computer to work with the Support Package
% for ADALM-PLUTO Radio.

% Copyright 2019 The MathWorks, Inc.

%% Required Hardware and Software
% To run this example using captured signals, you need the following
% software:
%
% * Communications Toolbox Library for the Bluetooth Protocol
%
% To receive signals in real time, you also need an ADALM-PLUTO radio and
% the corresponding support package Add-On:
%
% * <matlab:web(['https://www.mathworks.com/hardware-support/adalm-pluto-radio.html'],'-browser')
% Communications Toolbox Support Package for ADALM-PLUTO Radio>
%
% For a full list of Communications Toolbox supported SDR platforms,
% refer to Supported Hardware section of the
% <matlab:web(['https://www.mathworks.com/discovery/sdr.html'],'-browser')
% Software Defined Radio (SDR) discovery page>.

%% Background
% The Bluetooth Special Interest Group (SIG) introduced BLE for low power
% short range communications. The Bluetooth standard [ <#13 1> ] specifies
% the *Link* layer which includes both *PHY* and *MAC* layers. BLE
% applications include image and video file transfers between mobile
% phones, home automation, and the Internet of Things (IoT).
%
% Specifications of BLE:
%
% * *Transmission frequency range*: 2.4-2.4835 GHz
% * *RF channels* : 40
% * *Symbol rate* : 1 Msym/s, 2 Msym/s
% * *Modulation* : Gaussian Minimum Shift Keying (GMSK)
% * *PHY transmission modes* :
% (i) LE1M - Uncoded PHY with data rate of 1 Mbps (ii) LE2M - Uncoded PHY
% with data rate of 2 Mbps (iii) LE500K - Coded PHY with data rate of 500
% Kbps (iv) LE125K - Coded PHY with data rate of 125 Kbps
%
% The Bluetooth standard [ <#13 1> ] specifies air interface packet formats
% for all the four PHY transmission modes of BLE using the following
% fields:
%
% * *Preamble*: The preamble depends on PHY transmission mode. LE1M mode
% uses an 8-bit sequence of alternate zeros and ones, '01010101'. LE2M uses
% a 16-bit sequence of alternate zeros and ones, '0101...'. LE500K and
% LE125K modes use an 80-bit sequence of zeros and ones obtained by
% repeating '00111100' ten times.
% * *Access Address*: Specifies the connection address shared between two
% BLE devices using a 32-bit sequence.
% * *Coding Indicator*: 2-bit sequence used for differentiating coded
% modes (LE125K and LE500K).
% * *Payload*: Input message bits including both protocol data unit (PDU)
% and cyclic redundancy check (CRC). The maximum message size is 2080 bits.
% * *Termination Fields*: Two 3-bit vectors of zeros, used in forward error
% correction encoding. The termination fields are present for coded modes
% (LE500K and LE125K) only.
%
% Packet format for uncoded PHY (LE1M and LE2M) modes is shown in the
% figure below:
%
% <<../BLEUncodedPhy.png>>
%
% Packet format for coded PHY (LE500K and LE125K) modes is shown in the
% figure below:
%
% <<../BLECodedPhy.png>>

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
bleParam = helperBLEReceiverConfig(phyMode);

%%
% *Signal Source*
%
% Specify the signal source as 'File' or 'ADALM-PLUTO'.
%
% * *File*:Uses the <docid:comm_ref#bvbbo5v-1 comm.BasebandFileReader> to
% read a file that contains a previously captured over-the-air signal.
% * *ADALM-PLUTO*: Uses the <docid:plutoradio_ref#bvn84ra-1 sdrrx> System
% object to receive a live signal from the SDR hardware.
%
% If you assign ADALM-PLUTO as the signal source, the example searches your
% computer for the ADALM-PLUTO radio at radio address 'usb:0' and uses it
% as the signal source.

signalSource = 'ADALM-PLUTO'; % The default signal source is 'File'

%%
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
        'CenterFrequency',     2.402e9,...
        'BasebandSampleRate',  bbSampleRate,...
        'SamplesPerFrame',     1e7,...
        'GainSource',         'Manual',...
        'Gain',                20,...
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
        fprintf('Advertising Address: %s\n', cfgLLAdv.AdvertisingData);
        disp(char(hex2dec(cfgLLAdv.AdvertisingData))');
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

%% Further Exploration
% The companion example
% <docid:comm_examples#example-blueBLETransmitterExample Bluetooth Low
% Energy Transmitter> can be used to transmit a standard-compliant BLE
% waveform which can be decoded by this example. You can also use this
% example to transmit the data channel PDUs by changing channel index,
% access address and center frequency values in both the examples.

%% Troubleshooting
% General tips for troubleshooting SDR hardware and the Communications
% Toolbox Support Package for ADALM-PLUTO Radio can be found in
% <docid:plutoradio_ug#bvn89q2-68 Common Problems and Fixes>.

%% Appendix
% This example uses the following helper functions:
%
% * <matlab:edit('helperBLEReceiverConfig.m') helperBLEReceiverConfig.m>
% * <matlab:edit('helperBLEPhyBitRecover.m') helperBLEPhyBitRecover.m>

%% Selected Bibliography
% # Volume 6 of the Bluetooth Core Specification, Version 5.0 Core System
% Package [Low Energy Controller Volume].

%% Bluetooth Low Energy Transmitter
% This example shows how to implement a Bluetooth(R) Low Energy (BLE)
% transmitter using the Communications Toolbox(TM) Library for the
% Bluetooth Protocol. You can either transmit BLE signals using the
% ADALM-PLUTO radio or write to a baseband file (*.bb). The transmitted BLE
% signal can be received by the companion example,
% <docid:comm_examples#example-blueBLEReceiverExample Bluetooth Low Energy
% Receiver>, with any one of the following setup: (i) Two SDR platforms
% connected to the same host computer which runs two MATLAB sessions (ii)
% Two SDR platforms connected to two computers which run separate MATLAB
% sessions.
%
% Refer to the <docid:plutoradio_ug#bvn89q2-14> documentation for details
% on how to configure your host computer to work with the Support Package
% for ADALM-PLUTO Radio.

% Copyright 2019 The MathWorks, Inc.

%% Required Hardware and Software
% To run this example, you need the following software:
%
% * Communications Toolbox Library for the Bluetooth Protocol
%
% To transmit signals in real time, you also need ADALM-PLUTO radio and the
% corresponding support package Add-On:
%
% * <matlab:web(['https://www.mathworks.com/hardware-support/adalm-pluto-radio.html'],'-browser')
% Communications Toolbox Support Package for ADALM-PLUTO Radio>
%
% For a full list of Communications Toolbox supported SDR platforms, refer
% to Supported Hardware section of the
% <matlab:web(['https://www.mathworks.com/discovery/sdr.html'],'-browser')
% Software Defined Radio (SDR) discovery page>.

%% Background
% The Bluetooth Special Interest Group (SIG) introduced BLE for low power
% short range communications. The Bluetooth standard [ <#11 1> ] specifies
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
% * *PHY transmission modes* : (i) LE1M - Uncoded PHY with data rate of 1
% Mbps (ii) LE2M - Uncoded PHY with data rate of 2 Mbps (iii) LE500K -
% Coded PHY with data rate of 500 Kbps (iv) LE125K - Coded PHY with data
% rate of 125 Kbps
%
% The Bluetooth standard [ <#11 1> ] specifies air interface packet formats
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
% * *Coding Indicator*: 2-bit sequence used for differentiating coded modes
% (LE125K and LE500K).
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
% The general structure of the BLE transmitter example is described as
% follows:
%
% # Generate link layer PDUs
% # Generate baseband IQ waveforms
% # Transmitter processing

%%
% *Generate Link Layer PDUs*
%
% Link layer PDUs can be either advertising channel PDUs or data channel
% PDUs. You can configure and generate advertising channel PDUs using
% <matlab:help('bleLLAdvertisingChannelPDUConfig')
% bleLLAdvertisingChannelPDUConfig> and
% <matlab:help('bleLLAdvertisingChannelPDU') bleLLAdvertisingChannelPDU>
% functions respectively. You can configure and generate data channel PDUs
% using <matlab:help('bleLLDataChannelPDUConfig')
% bleLLDataChannelPDUConfig> and <matlab:help('bleLLDataChannelPDU')
% bleLLDataChannelPDU> functions respectively.

% Configure an advertising channel PDU
cfgLLAdv = bleLLAdvertisingChannelPDUConfig;
cfgLLAdv.PDUType         = 'Advertising indication';
cfgLLAdv.AdvertisingData = '0123456789ABCDEF';
cfgLLAdv.AdvertiserAddress = '0123456789AB';

% Generate an advertising channel PDU
messageBits = bleLLAdvertisingChannelPDU(cfgLLAdv);

%%
% *Generate Baseband IQ Waveforms*
%
% You can use the <matlab:help('bleWaveformGenerator')
% bleWaveformGenerator> function to generate standard-compliant waveforms.

phyMode = 'LE1M'; % Select one mode from the set {'LE1M','LE2M','LE500K','LE125K'}
sps = 8;          % Samples per symbol
channelIdx = 37;  % Channel index value in the range [0,39]
accessAddLen = 32;% Length of access address
accessAddHex = '8E89BED6';  % Access address value in hexadecimal
accessAddBin = de2bi(hex2dec(accessAddHex),accessAddLen)'; % Access address in binary

% Symbol rate based on |'Mode'|
symbolRate = 1e6;
if strcmp(phyMode,'LE1M')
    symbolRate = 2e6;
end

% Generate BLE waveform
txWaveform = bleWaveformGenerator(messageBits,...
    'Mode',            phyMode,...
    'SamplesPerSymbol',sps,...
    'ChannelIndex',    channelIdx,...
    'AccessAddress',   accessAddBin);

% Setup spectrum viewer
spectrumScope = dsp.SpectrumAnalyzer( ...
    'SampleRate',       symbolRate*sps,...
    'SpectrumType',     'Power density', ...
    'SpectralAverages', 10, ...
    'YLimits',          [-130 0], ...
    'Title',            'Baseband BLE Signal Spectrum', ...
    'YLabel',           'Power spectral density');

% Show power spectral density of the BLE signal
spectrumScope(txWaveform);

%%
% *Transmitter Processing*
%
% Specify the signal sink as 'File' or 'ADALM-PLUTO'.
%
% * *File*:Uses the <docid:comm_ref#bvby020-1 comm.BasebandFileWriter> to
% write a baseband file.
% * *ADALM-PLUTO*: Uses the <docid:plutoradio_ref#bvn84t3-1 sdrtx> System
% object to transmit a live signal from the SDR hardware.

%%

% Initialize the parameters required for signal source
txCenterFrequency       = 2.402e9;  % Varies based on channel index value
txFrameLength           = length(txWaveform);
txNumberOfFrames        = 1e4;
txFrontEndSampleRate    = symbolRate*sps;

% The default signal source is 'File'
signalSink = 'ADALM-PLUTO';

if strcmp(signalSink,'File')
    
    sigSink = comm.BasebandFileWriter('CenterFrequency',txCenterFrequency,...
        'Filename','bleCaptures.bb',...
        'SampleRate',txFrontEndSampleRate);
    sigSink(txWaveform); % Writing to a baseband file 'bleCaptures.bb'
    
elseif strcmp(signalSink,'ADALM-PLUTO')
    
    % First check if the HSP exists
    if isempty(which('plutoradio.internal.getRootDir'))
        error(message('comm_demos:common:NoSupportPackage', ...
                      'Communications Toolbox Support Package for ADALM-PLUTO Radio',...
                      ['<a href="https://www.mathworks.com/hardware-support/' ...
                      'adalm-pluto-radio.html">ADALM-PLUTO Radio Support From Communications Toolbox</a>']));
    end
    connectedRadios = findPlutoRadio; % Discover ADALM-PLUTO radio(s) connected to your computer
    radioID = connectedRadios(1).RadioID;
    sigSink = sdrtx( 'Pluto',...
        'RadioID',           radioID,...
        'CenterFrequency',   txCenterFrequency,...
        'Gain',              0,...
        'SamplesPerFrame',   txFrameLength,...
        'BasebandSampleRate',txFrontEndSampleRate);
    % The transfer of baseband data to the SDR hardware is enclosed in a
    % try/catch block. This means that if an error occurs during the
    % transmission, the hardware resources used by the SDR System
    % object(TM) are released.
    currentFrame = 1;
    try
        while true
            % Data transmission
            sigSink(txWaveform);
            % Update the counter
            currentFrame = currentFrame + 1;
        end
    catch ME
        release(sigSink);
        rethrow(ME)
    end
else
    error('Invalid signal sink. Valid entries are File and ADALM-PLUTO.');
end

% Release the signal sink
release(sigSink)

%% Further Exploration
% The companion example <docid:comm_examples#example-blueBLEReceiverExample
% Bluetooth Low Energy Receiver> can be used to decode the waveform
% transmitted by this example. You can also use this example to transmit
% the data channel PDUs by changing channel index, access address and
% center frequency values in both the examples.

%% Troubleshooting
% General tips for troubleshooting SDR hardware and the Communications
% Toolbox Support Package for ADALM-PLUTO Radio can be found in
% <docid:plutoradio_ug#bvn89q2-68 Common Problems and Fixes>.

%% Selected Bibliography
% # Volume 6 of the Bluetooth Core Specification, Version 5.0 Core System
% Package [Low Energy Controller Volume].

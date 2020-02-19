%% Section 1: Theoretical Preparation
% Robert Starr, Ethan Martin, and Andrew Duncan
% Professor Wyglinski, ECE 4305
% Due 2/21/2020

clear;
close all;

%% Generation of frequency response for SRRC filter

% Data and Filter parameters
data = 2.*round(rand(1,100))-1;     % Create 100 samples of -1 or 1 data
beta = [0, 0.1, 0.25, 0.5, 1];      % Beta Values for filter
span = 4;                           % Signal span 
sps = 8;                            % Samples per symbol
numPoints = 256;                    % Number of frequency points
sampleRateHz = 1e3;                 % Sample rate (Hz)

% Generation of SRRC filters
for i = 1:length(beta)
    SRRC = rcosdesign(beta(i), span, sps, 'sqrt');
    % Convolve the signal with the SRRC:
    filt_sig = conv(data, SRRC);
    
    % Generation of the frequency response
    figure
    freqz(filt_sig, numPoints, sampleRateHz)
end

%% Generation of Transmit and Receive Plots with SRRC

% Filter parameters
% Will be using same data from first section
betaQ3 = [0.1 0.5 0.9];             % New Beta values
snr = 5;                            % SNR value, used in AWGN Generation
decimationFactor = 1;               % Decimation Factor, used in Rx SRRC

for i = 1:length(betaQ3)
    %------------------------------------------------------------------
    % Section 1: Transmitted Data, Data w/ Noise, SRRC'ed data
    noisyData = awgn(data, snr);
    sqrtTxCosine = comm.RaisedCosineTransmitFilter('Shape', 'Square root', ...
        'RolloffFactor', betaQ3(i), 'FilterSpanInSymbols', span, ...
        'OutputSamplesPerSymbol', sps);
    
    % Filter, Adjust shifts in filter design, create time axis for filter
    filtSig = sqrtTxCosine([data'; zeros(span/2,1)]);
    filterDelay = span/(2*sampleRateHz);
    filtSig = filtSig(filterDelay*(sampleRateHz*sps)+1:end);
    taxisFilter = 1:(1/sps):101-(1/sps);
    
    % Plots of the data
    figure
    subplot(3,1,1)
    stem(data, 'Marker', 'x', 'MarkerEdgeColor', 'k')
    hold on
    plot(noisyData, 'MarkerEdgeColor', 'r')
    plot(taxisFilter, filtSig, 'Marker', 'o', 'MarkerEdgeColor', 'b', 'Color', 'blue')
    hold off
    xlabel('Time (s)')
    ylabel('Amplitude')
    title(['Data with Beta value of ', num2str(betaQ3(i))])
    legend('Transmitted Data', 'Received Data with Noise', 'Transmitted SRRC')
    
    %-----------------------------------------------------------------
    % Section 2: Transmitted Data, Received Filter Output, Demodulated
    sqrtRxCosine = comm.RaisedCosineReceiveFilter('Shape', 'Square root', ...
        'RolloffFactor', betaQ3(i), 'FilterSpanInSymbols', span, ...
        'InputSamplesPerSymbol', sps, 'DecimationFactor', decimationFactor);
    
    rxFiltSig = sqrtRxCosine([filtSig; zeros(span*sps/2,1)]);
    
    % Adjustments to filter shifts
    rxFiltSig = rxFiltSig(filterDelay*(sampleRateHz*sps)+1:end);
    
    % Decode / demodulate data (closest point = decoded symbol)
    demodFiltData = downsample(rxFiltSig, sps);
    demodFiltData = (floor(demodFiltData/2)*2)+1;
    
    % Prevent accidental rounding - limit to [-1 1] range
    demodFiltData(demodFiltData > 1) = 1;
    demodFiltData(demodFiltData < -1) = -1;

    % Plots of the data
    subplot(3,1,2)
    stem(data, 'Marker', 'x', 'MarkerEdgeColor', 'k')
    hold on
    plot(taxisFilter, rxFiltSig, 'MarkerEdgeColor', 'b')
    stem(demodFiltData, 'Marker', 'o', 'MarkerEdgeColor', 'm', 'Color', 'm')
    hold off
    legend('Transmitted Data', 'Received Filter Output', 'Demodulated')
    xlabel('Time (s)')
    ylabel('Amplitude')

    %-----------------------------------------------------------------
    % Section 3: Transmitted Data, Received Data w/ Noise, Demodulated
    demodNoisyData = (floor(noisyData/2)*2)+1;
    
    % Prevent accidental rounding - limit to [-1 1] range
    demodNoisyData(demodNoisyData > 1) = 1;
    demodNoisyData(demodNoisyData < -1) = -1;
    
    % Plots of the data
    subplot(3,1,3)
    stem(data, 'Marker', 'x', 'MarkerEdgeColor', 'k')
    hold on
    plot(noisyData, 'MarkerEdgeColor', 'r')
    stem(demodNoisyData, 'Marker', 'o', 'MarkerEdgeColor', 'm', 'Color', 'm')
    hold off
    legend('Transmitted Data', 'Received Data with Noise', 'Demodulated')
    xlabel('Time (s)')
    ylabel('Amplitude')
    
end

%% Timing Error with Pluto SDR

% Declaration of system parameters for hardware testing
samplesPerSecond = 8;
decimation = 4;
centerFrequency = 2.4e9;


% Creation of SDR TX and RX objects
% Transmitter
transmitter = sdrtx('Pluto', ...
    'CenterFrequency', centerFrequency, ...
    'Gain', -10);            

% Receiver
receiver = sdrrx('Pluto', ...
    'CenterFrequency', centerFrequency, ...
    'SamplesPerFrame', 1e6, ...
    'OutputDataType', 'double');

% Generate random data for QPSK modulation
randData = randi([0 1], 1000, 1); 
qpskModulation = comm.QPSKModulator('BitInput', true);
qpskData = qpskModulation(randData);

% Transmitter and Receiver Raised Cosine Filters
RCFilt_tx = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', samplesPerSecond);
RCFilt_rx = comm.RaisedCosineReceiveFilter('InputSamplesPerSymbol', samplesPerSecond, ...
    'DecimationFactor', decimation);

% Transmit data to receiver
filt_qpskTX = RCFilt_tx(qpskData);
transmitter.transmitRepeat(filt_qpskTX);

% Receive Data 
qpskRX = RCFilt_rx(receiver());

% Apply Timing Delay, set up plotting
delay = dsp.VariableFractionalDelay;
qpskConstellation = comm.ConstellationDiagram;

% Keep track of the samples being sent
samplesLeft = samplesPerSecond/decimation;
qpskRX = qpskRX(end-samplesLeft*10000+1:end);

% Apply signal delays
for i = 0:300
   t_delay = i/50;
   qpskDelay = delay(qpskRX, t_delay);
   
   % Modified signal
   modifiedQPSK = sum(reshape(qpskDelay, samplesLeft, ...
       length(qpskDelay)/samplesLeft).',2)./samplesLeft;
   
   % Display offsets
   qpskConstellation(modifiedQPSK);
   pause(0.1);

end
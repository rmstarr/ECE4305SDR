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
span = length(data);                % Signal span 
sps = 4;                            % Samples per symbol
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
snr = 5;                           % SNR value, used in AWGN Generation

for i = 1:length(betaQ3)
    %------------------------------------------------------------------
    % Section 1: Transmitted Data, Data w/ Noise, SRRC'ed data
    noisyData = awgn(data, snr);
%     SRRC = rcosdesign(betaQ3(i), span, sps, 'sqrt');
    sqrtCosine = comm.RaisedCosineTransmitFilter('Shape', 'Square root', ...
        'RolloffFactor', betaQ3(i), 'FilterSpanInSymbols', span, ...
        'OutputSamplesPerSymbol', sps);
    
    % Apply a delay and correct with shifts to filter design
    filterDelay = span/(2*sampleRateHz);
    filtSig = sqrtCosine([data; zeros(span/2,1)]);
    filtSig = filtSig(filterDelay*sampleRateHz+1:end);
    
    % Plot of the data
    figure
    subplot(3,1,1)
    stem(data, 'Marker', 'x', 'MarkerEdgeColor', 'k')
    hold on
    plot(noisyData, 'MarkerEdgeColor', 'r')
    plot(filtSig, 'Marker', 'o', 'MarkerEdgeColor', 'b', 'Color', 'blue')
    hold off
    xlabel('Time (s)')
    ylabel('Amplitude')
    title(['Data with Beta value of ', num2str(betaQ3(i))])
    legend('Transmitted Data', 'Received Data with Noise', 'Transmitted SRRC')
    
    %-----------------------------------------------------------------
    % Section 2: Transmitted Data, Received Filter Output, Demodulated
%     demodFiltData = (floor(filtSig/2)*2)+1;
    % Prevent accidental rounding - limit to [-1 1] range
%     demodFiltData(demodFiltData > 1) = 1;
%     demodFiltData(demodFiltData < -1) = -1;


%     % Plot of the data
%     subplot(3,1,2)
%     stem(data, 'Marker', 'x', 'MarkerEdgeColor', 'k')
%     hold on
%     plot(noisyData, 'MarkerEdgeColor', 'r')
%     stem(demodFiltData, 'Marker', 'o', 'MarkerEdgeColor', 'm')
%     hold off
%     legend('Transmitted Data', 'Received Filter Output', 'Demodulated')
%     xlabel('Time (s)')
%     ylabel('Amplitude')
%     title('Data with Beta value of', num2str(betaQ3(i)))

    %-----------------------------------------------------------------
    % Section 3: Transmitted Data, Received Data w/ Noise, Demodulated
    demodNoisyData = (floor(noisyData/2)*2)+1;
    % Prevent accidental rounding - limit to [-1 1] range
    demodNoisyData(demodNoisyData > 1) = 1;
    demodNoisyData(demodNoisyData < -1) = -1;
    
    % Plot of the data
    subplot(3,1,3)
    stem(data, 'Marker', 'x', 'MarkerEdgeColor', 'k')
    hold on
    plot(noisyData, 'MarkerEdgeColor', 'r')
    stem(demodNoisyData, 'Marker', 'o', 'MarkerEdgeColor', 'm')
    hold off
    legend('Transmitted Data', 'Received Data with Noise', 'Demodulated')
    xlabel('Time (s)')
    ylabel('Amplitude')
    
end






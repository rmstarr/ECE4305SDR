% General parameters
sampleRateHz = 5e5;
frameSize = 1024;
visuals = true;

% Receiver setup
Rx = sdrrx('Pluto', 'SamplesPerFrame', 2^10);
Rx.BasebandSampleRate = sampleRateHz;
inputData = Rx();

data = zeros(size(frameSize * 100));

for k = 1:100
    inputData = Rx();
    data((k-1)*frameSize + 1 : k*frameSize) = inputData;
end

for k = 1:length(data)
    d(k) = sqrt((real(data(k))).^2 + (imag(data(k))).^2);
    data(k) = real(data(k))/d(k) + imag(data(k))/d(k);
end

%% Define Communication Object

    fineSync = comm.CarrierSynchronizer('DampingFactor',1/sqrt(2), ...
    'NormalizedLoopBandwidth',0.01, ...
    'SamplesPerSymbol',1, ...
    'Modulation','BPSK');

%% Setup objects
mod = comm.QPSKModulator();
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Input');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'SymbolsToDisplaySource','Property',...
    'SymbolsToDisplay',frameSize/2,...
    'Name','Output');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
ap = dsp.ArrayPlot;ap.ShowGrid = true;
ap.Title = 'Frequency Histogram';ap.XLabel = 'Hz';ap.YLabel = 'Magnitude';
ap.XOffset = -sampleRateHz/2;
ap.SampleIncrement = (sampleRateHz)/(2^10);

cdOut = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPreOut = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');


%% Model of error
% Add frequency offset to baseband signal

% Precalculate constants
K = 1024;
recoveredSig = zeros(size(data));
M = 2; % MPSK: 4 for QPSK, 2 for DBPSK


% Iterations:
for k=1:frameSize:length(data)
    
    timeIndex = (k:k+frameSize-1).';
    
    % Coarse Frequency Compensation:
    FFT = abs(fft(data(timeIndex).^M, 1024));
    [~,actualOffset] = max(FFT);
    actualOffset = actualOffset-1;
    actualOffset = (actualOffset*sampleRateHz)/(M*K);
    adjustment = -1i .*2*pi * actualOffset ./ sampleRateHz;
    freqAdjust = exp(adjustment*timeIndex);
    recoveredSig(timeIndex) = (data(timeIndex)' .* freqAdjust);
    
    
    % Fine Frequency Compensation
%     recoveredSig = recoveredSig';
    rxData = fineSync(recoveredSig');
    
    % Take phase offset, put inside a vector
    % Take differentiation of it
    % Plot it


    if visuals
%         step(cdPre,data(timeIndex));
        step(cdPost,rxData(timeIndex));pause(0.1); %#ok<*UNRCH>
    end

end


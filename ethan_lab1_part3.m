%% Lab 1 Part 2: Fine Frequency Correction

% Debugging flags
visuals = true;

%% General system details
sampleRateHz = 1e6; % Sample rate
samplesPerSymbol = 1;
frameSize = 2^10;
numFrames = 10;
numSamples = numFrames*frameSize; % Samples to simulate

%% Fine Frequency Compensator Variable initialization:

loopBand = 0.05; % Loop bandwidt
lamda = 1 / sqrt(2) ; % Dampening Factor
M = 4; % Constellation Order

theta = loopBand / (M * (lamda + (0.25/lamda)));
delta = 1 + 2*lamda*theta+theta^2;

% Define the PLL Gains:
G1 = (4*lamda*theta / delta) / M;
G2 = ((4/M) * theta^2 / delta) / M;

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

%% Impairments
snr = 15;
frequencyOffsetHz = sampleRateHz*0.02; % Offset in hertz
phaseOffset = 0; % Radians

%% Generate symbols
data = randi([0 3], numSamples, 1);
modulatedData = mod.step(data);

%% Add noise
noisyData = awgn(modulatedData,snr);%,'measured');


%% Define Communication Object

    fineSync = comm.CarrierSynchronizer('DampingFactor',lamda, ...
    'NormalizedLoopBandwidth',loopBand, ...
    'SamplesPerSymbol',samplesPerSymbol, ...
    'Modulation','QPSK');
%% Model of error
% Add frequency offset to baseband signal

% Precalculate constants
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;

Phase = zeros(1:length(numSamples));
offsetData = zeros(size(noisyData));
for k=1:frameSize:numSamples
    
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = noisyData(timeIndex).*freqShift;
    % Fine Frequency Compensation
    [rxData] = fineSync(offsetData);
    [~, phaseOff] = fineSync(offsetData);
    
    % Take phase offset, put inside a vector
    % Take differentiation of it
    % Plot it
    
    Phase(k:k+frameSize-1) = phaseOff(timeIndex);
    if visuals
        step(cdPre,noisyData(timeIndex));
        step(cdPre,offsetData(timeIndex));
        step(cdPost,rxData(timeIndex));pause(0.1); %#ok<*UNRCH>
    end

end
figure;
plot(phaseOff)
estFreqOffset = diff(phaseOff)*sampleRateHz/(2*pi);
rmean = cumsum(estFreqOffset)./(1:length(estFreqOffset))';
plot(rmean)
xlabel('Symbols')
ylabel('Estimated Frequency Offset (Hz)')
title('Estimate of Frequency Offset: damping = 1/sqrt((2), loop BW = 0.05')
grid

    

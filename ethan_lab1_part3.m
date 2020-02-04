%% Lab 1 Part 2: Fine Frequency Correction

% Debugging flags
visuals = true;

%% General system details
sampleRateHz = 1e3; % Sample rate
samplesPerSymbol = 1;
frameSize = 2^10;
numFrames = 300;
numSamples = numFrames*frameSize; % Samples to simulate

%% Setup objects
mod = comm.QPSKModulator();
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'SymbolsToDisplaySource','Property',...
    'SymbolsToDisplay',frameSize/2,...
    'Name','Baseband with Freq Offset');
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
data = randi([0 samplesPerSymbol], numSamples, 1);
modulatedData = mod.step(data);

%% Add noise
noisyData = awgn(modulatedData,snr);%,'measured');

%% Model of error
% Add frequency offset to baseband signal

% Precalculate constants
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;

offsetData = zeros(size(noisyData));
for k=1:frameSize:numSamples
    
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = noisyData(timeIndex).*freqShift;
    
    
    rxData = zeros(size(offsetData));
    for x = 1:1:length(offsetData)
        currentData = offsetData(x);
        rxData(x) = qpsk(currentData);
    end
    
%     fineSync = comm.CarrierSynchronizer('DampingFactor',1/sqrt(2), ...
%     'NormalizedLoopBandwidth',0.01, ...
%     'SamplesPerSymbol',samplesPerSymbol, ...
%     'Modulation','BPSK');
%     rxData = fineSync(offsetData);
    
    % Visualize Error
    if visuals
        step(cdPre,noisyData(timeIndex));step(cdPost,rxData(timeIndex));pause(0.1); %#ok<*UNRCH>
    end
    

    

end



    



% 
% function FFC(offsetData())
% 
% % Set up PLL Constants:
% loopBand = 0.01; % Loop bandwidt
% lamda = 1 / sqrt(2); % Dampening Factor
% M = 2; % Constellation Order
% 
% theta = loopBand / (M * (lamda + (0.25/lamda)));
% delta = 1 + 2*lamda*theta+theta^2;
% 
% % Define the PLL Gains:
% G1 = (4*lamda*theta / delta) / M;
% G2 = ((4/M) * theta^2 / delta) / M;
% display(G1);
% display(G2);
% 
% % Define estimated frequency lock range
% lockRange = 4*(2*pi*sqrt(2)*lamda * loopBand)^2 / (loopBand^3);
% 
% % Loop start of the PLL
% for k = 1:frameSize:numSamples
%    
% % Step One: Phase Rotator:
% 
% 
% 
% 
% % Step Two: Phase Error Detector
% 
% % Step Three: Loop Filter
% 
% % Step Four: Direct Digital Synchronizer
% 
% 
% 
% end
% end
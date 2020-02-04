%% General system details
sampleRateHz = 1e6;
samplesPerSymbol = 1;
frameSize = 2^10;
numFrames = 10;
nSamples = numFrames*frameSize;
DampingFactors = [0.9, 1.3];
NormalizedLoopBandwidth = 0.09;

%% Generate Symbols
order = 4;
data = pskmod(randi([0 order - 1], nSamples, 1), order, 0);  % QPSK

%% Configure LPF and PI
LoopFilter = dsp.IIRFilter('Structure', 'Direct form II transposed', ...
    'Numerator', [1 0], 'Denominator', [1 -1]);
Integrator = dsp.IIRFilter('Structure', 'Direct form II transposed', ...
    'Numerator', [0 1], 'Denominator', [1 -1]);

for DampingFactor = DampingFactors
    % Calculate range estimates
    NormalizedPullInRange = min(1, 2*pi*sqrt(2)*DampingFactor*...
        NormalizedLoopBandwidth);
    MaxFrequencyLockDelay = (4*NormalizedPullInRange^2) / ...
        (NormalizedLoopBandwidth)^3;
    MaxPhaseLockDelay = 1.3/(NormalizedLoopBandwidth);
    
    %% Impairments
    frequencyOffsetHz = sampleRateHz * (NormalizedPullInRange);
    snr = 25;
    noisyData = awgn(data, snr);  % add noise
    
    % Add frequency offset to baseband signal
    freqShift = exp(1j.*2*pi*frequencyOffsetHz./sampleRateHz*(1:nSamples)).';
    offsetData = noisyData.*freqShift;
    
    %% Calculate coefficients for FFC
    PhaseRecoveryLoopBandwidth = NormalizedLoopBandwidth*samplesPerSymbol;
    PhaseRecoveryGain = samplesPerSymbol;
    PhaseErrorDetectorGain = log2(order);
    DigitalSynthesizerGain  = -1;
    theta = PhaseRecoveryLoopBandwidth/...
        ((DampingFactor + 0.25/DampingFactor)*samplesPerSymbol);
    delta = 1 + 2*DampingFactor*theta + theta*theta;
    
    % G1
    ProportionalGain = (4*DampingFactor*theta/delta)/...
        (PhaseErrorDetectorGain*PhaseRecoveryGain);
    
    % G3
    IntegratorGain = (4/samplesPerSymbol*theta*theta/delta)/...
        (PhaseErrorDetectorGain*PhaseRecoveryGain);
    
    %% Correct carrier offset
    output = zeros(size(offsetData));
    Phase = 0;
    previousSample = complex(0);
    LoopFilter.release();
    Integrator.release();
    
    for k = 1:length(offsetData)-1
        % Complex phase shift
        output(k) = offsetData(k+1)*exp(1j*Phase);
        
        % PED
        phErr = sign(real(previousSample)).*imag(previousSample)...
            -sign(imag(previousSample)).*real(previousSample);
        
        % Loop Filter
        loopFiltOut = step(LoopFilter,phErr*IntegratorGain);
        
        % Direct Digital Synthesizer
        DDSOut = step(Integrator,phErr*ProportionalGain + loopFiltOut);
        Phase = DigitalSynthesizerGain * DDSOut;
        previousSample = output(k);
    end
    scatterplot(output(end-1024:end-10));
    title('Data....');
end
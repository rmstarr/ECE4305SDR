function synchronized_data =  qpsk(something)

loopBand = 0.01; % Loop bandwidt
lamda = 1 / sqrt(2); % Dampening Factor
M = 4; % Constellation Order

theta = loopBand / (M * (lamda + (0.25/lamda)));
delta = 1 + 2*lamda*theta+theta^2;

% Define the PLL Gains:
G1 = (4*lamda*theta / delta) / M;
G2 = ((4/M) * theta^2 / delta) / M;
display(G1);
display(G2);

% Define estimated frequency lock range
lockRange = 4*(2*pi*sqrt(2)*lamda * loopBand)^2 / (loopBand^3);

% Initialize FFC Matlab object

fineSync = QPSKFineFrequencyCompensator('ProportionalGain', G1, ...
    'IntegratorGain', G2, 'DigitalSynthesizerGain', -1);


synchronized_data = fineSync(something)
% Assume outputs one number


end

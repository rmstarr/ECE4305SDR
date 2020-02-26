%% CRC Generation

PDULength = 257;                % Max length of PDU (bytes)
CRCLength = 3;                  % Length of CRC (bytes)
bytes2bits = 8;                 % 8 bits per byte

% Make the packet (Preamble, Access Address, PDU, CRC)
preamble = [0 1 0 1 0 1 0 1]';                      
accAddr = 'A8C8F245';                                
accAddrBinary = double(hexToBinaryVector(accAddr))';
randomPDU = randi([0 1], (PDULength)*bytes2bits, 1);

packet = [preamble; accAddrBinary; randomPDU];

% CRC Creation for data packet
CRC_poly = 'z^24 + z^23 + z^18 + z^14 + z^12 + z^8 + 1'; 
crcGen = comm.CRCGenerator('Polynomial', CRC_poly, 'InitialConditions', 0, ...
    'DirectMethod', true);
crcDet = comm.CRCDetector('Polynomial', CRC_poly, 'InitialConditions', 0, ...
    'DirectMethod', true);
fullPacket = crcGen(packet);

%% Cross correlation (Theory)

% Find the preamble (and spacing), given that we know what to look for
preamble2Find = [0 1 0 1 0 1 0 1]';
gapLength = length(fullPacket);  

% Perform cross-correlation, find where preamble is
[corr, lag] = xcorr(fullPacket, preamble2Find);
L = length(corr);
[~, index] = max(corr);      % Determine the index of highest xcorr

% Plot of correlation results
stem(lag, corr);
xlim([0 length(fullPacket)]);
    

%% Using comm.PreambleDetector to Find End of BLE Preamble
tic
% Preamble to find
blePreamble = [0 1 0 1 0 1 0 1]';

% Generate a block of 2112 random data points (everything besides preamble)
randDat = randi([0 1], 2112, 1);

% Make a "packet" of simulated data
packet = [blePreamble; randDat];

% Repeat the data sequence - simulate collection of multiple packets in
% buffer (Pretending to collect 100 packets)
bigPacket = repmat(packet, 100, 1);

% Creation of Preamble Detector Object - find the Preamble from collected
% data (Note: Set to detect each 
prbDet = comm.PreambleDetector(blePreamble, 'Input', 'Bit', 'Detections', 'All');

% Find END of preamble
prbEnd = prbDet(bigPacket);

toc % Done just to see how fast process is

%% Creation of Multiple Packets - Apply Cross Correlation to find Preamble


% Logic:
%   - Take in multiple packets (say, 100 packets)
%   - Take the xcorr of each packet
%   - Save the indices fron which maximum xcorr achieved
%   - As multiple iterations occur, take note of where spikes are. The
%     spikes should be consistent. If there are discrepancies, eliminate
%     the index from contention

% Preamble to find for LE1M and LE2M
preambleLE1M = [0 1 0 1 0 1 0 1]';

% Instantiation of maxval arrays
lastMax = [];
currMax = [];

% Try taking in 100 packets - create new data each time
for iteration = 1:100
    
    % Creation of new data packet
    randomPDU = randi([0 1], (PDULength)*bytes2bits, 1);
    BLEPacket = [preamble; accAddrBinary; randomPDU];

    % Perform cross correlation, find indices or maximum correlation
    corr = xcorr(BLEPacket, preambleLE1M);
    [~, index] = max(corr);
    
    % Set indices of maximum correlation in currMax, then compare to
    % indices in lastMax. Only keep indices that are in both the new and
    % old max arrays
    
    
end

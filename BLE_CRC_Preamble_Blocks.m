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
bleDataPacket = crcGen(packet);    

%% Using comm.PreambleDetector to Find End of BLE Preamble
tic
% Preamble to find
blePreamble = [0 1 0 1 0 1 0 1]';
packets2Collect = 100;

% Repeat the data sequence - simulate collection of multiple packets in
% buffer (Pretending to collect 100 packets)
bigPacket = repmat(bleDataPacket, packets2Collect, 1);

% Creation of Preamble Detector Object - find the Preamble from collected
% data (Note: Set to detect each 
prbDet = comm.PreambleDetector(blePreamble, 'Input', 'Bit', 'Detections', 'First');

% Find END of FIRST preamble
firstPreamble = prbDet(bigPacket);

% Verify that packets are aligned by preambles
packetLength = length(packet);
allPreambles = firstPreamble:packetLength:length(bigPacket);

% Check to verify that all of these are truly preambles (extra)
for i = 1:length(allPreambles)
    preambleCheck = bigPacket(allPreambles(i) - (length(blePreamble) - 1):allPreambles(i));
    if preambleCheck ~= blePreamble
        disp("Error in preamble")
    end
end

toc % Done just to see how fast process is


%% Processing of Data (Once it Has Been Received)

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
buffer = repmat(bleDataPacket, packets2Collect, 1);

% Creation of Preamble Detector Object - find the Preamble from collected
% data (Note: Set to detect each 
prbDet = comm.PreambleDetector(blePreamble, 'Input', 'Bit', 'Detections', 'First');

% Find END of FIRST preamble
firstPreamble = prbDet(buffer);

% Verify that packets are aligned by preambles
packetLength = length(bleDataPacket);
allPreambles = firstPreamble:packetLength:length(buffer);

% Check to verify that all of these are truly preambles (extra)
for i = 1:length(allPreambles)
    preambleCheck = buffer(allPreambles(i) - (length(blePreamble) - 1):allPreambles(i));
    if preambleCheck ~= blePreamble
        disp("Error in preamble")
    end
end

toc % Done just to see how fast process is


%% Processing of Data (Once it Has Been Received)

% This code section follows successful location of the preambles from the
% buffer. With the preambles known, the packets can be "sliced" out of the
% buffer and then broken down further into their specific components
%   - The actual preamble, the access address (need to confirm that the
%     access address matches where we were expecting it to be sent)
%   - The PDU (convert the binary data into strings of "Hello World"
%   - The CRC (once again, check to ensure the CRC matches what was
%     expected)

% Slicing of the preambles
% Sort of already do this in previous section (reproduced below):

% Verify that packets are aligned by preambles
packetLength = length(bleDataPacket);
allPreambles = firstPreamble:packetLength:length(buffer);

% With preambles found and verified, slice out the packets from the buffer
% Need to ensure that we are iterating across a full packet
% Can have incomplete packets at both beginning and at end
packetAdjuster = length(blePreamble) - 1;  % Ensure we start at beginning of preamble

if allPreambles(1) - length(blePreamble) ~= 0  ||  allPreambles(end) + (packetLength - length(preamble)) > length(buffer) 
    buffer = buffer((allPreambles(1) - packetAdjuster):(allPreambles(end)- length(blePreamble)));
end

% Count the number of packets we have from the buffer
numPackets = length(buffer) / packetLength;

% Check to verify that all of these are truly preambles (extra)
for i = 1:length(allPreambles)
    preambleCheck = buffer(allPreambles(i) - (length(blePreamble) - 1):allPreambles(i));
    if preambleCheck ~= blePreamble
        disp("Error in preamble")
    end
end

% With packets adjusted for, slice out each packet
packets = reshape(buffer,(length(buffer)/numPackets), numPackets);

% ----------------------------------------------------------------------%
% Slice up the data - will need to consider PHY Mode used
for pckNum = 1:numPackets
    packetPreamble = packets(1:length(blePreamble), pckNum);
    
    % Ensure the preamble is correct
    if packetPremable ~= blePreamble
        
    end
    
    %
    
end




function [packets, numPackets] = preambleDetect(signal, bleObj)
% Using comm.PreambleDetector to Find End of BLE Preamble

prbDet = comm.PreambleDetector(blePreamble, 'Input', 'Bit', 'Detections', 'First');

% Find END of FIRST preamble
firstPreamble = prbDet(signal);

% Verify that packets are aligned by preambles
packetLength = bleObj.packetLength;
allPreambles = firstPreamble:packetLength:length(signal);
preambleLength = bleObj.PrbLen;
validPreambles = [];
count = 1;
% Check to verify that all of these are truly preambles (extra)
for i = 1:length(allPreambles)
    preambleCheck = signal(allPreambles(i) - (preambleLength - 1):allPreambles(i));
    if preambleCheck == bleObj.blePreamble
        disp("Correct Preamble")
        validPreambles(count) = allPreambles(i);
        count = count + 1;
    end
end


% This code section follows successful location of the preambles from the
% buffer. With the preambles known, the packets can be "sliced" out of the
% buffer and then broken down further into their specific components in
% another function
%   - The actual preamble, the access address (need to confirm that the
%     access address matches where we were expecting it to be sent)
%   - The PDU (convert the binary data into strings of "Hello World"
%   - The CRC (once again, check to ensure the CRC matches what was
%     expected)

% With preambles found and verified, slice out the packets from the buffer
% Need to ensure that we are iterating across a full packet
% Can have incomplete packets at both beginning and at end
packetAdjuster = preambleLength - 1;  % Ensure we start at beginning of preamble

if validPreambles(1) - preambleLength ~= 0  ||  validPreambles(end) + (packetLength - preambleLength) > length(signal) 
    % Cut's off the beginning and end if there's junk on either side.
    newSignal = signal((validPreambles(1) - packetAdjuster):(validPreambles(end)- length(blePreamble)));
    % if the last index of the signal (length of the signal) is exactly equal to
    % the index of the last preamble plus the PDU and access address,
    % process like before but go until the end of the signal
    % This implies that we have a complete packet at the end
    if length(signal) == validPreambles(end) + (packetLength - preambleLength)
          newSignal = signal((validPreambles(1) - packetAdjuster):end);
    end
end

% Count the number of packets we have from the buffer
numPackets = length(newSignal) / packetLength;

% With packets adjusted for, slice out each packet
packets = newSignal;

end
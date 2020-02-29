function [pduPayload, error] = phyRecover(packet, bleObj)

% Assign CRC check object:

% Note: When calling the function, we want the input datastream to only
% have the PDU and the header
crcDet = comm.CRCDetector('Polynomial', bleObj.CRC_poly, 'InitialConditions', 0, ...
    'DirectMethod', true);

currentPacket =  packet;
packetData = currentPacket(1 + bleObj.PreLen: end);
% For non-encoded schemes, this is how the data is broken down
accessAddress = int8(packetData(1:bleParam.AccessAddLen)>0);
decodeData = int8(packetData(1+bleParam.AccessAddLen:end)>0);

if isequal(accessAddress, bleObj.accessAddress)
    % Perform dewhittening of bits
    % NOTE: Look into functions and figure out why they're used
    dewhitenStateLen = 6;
    chanIdxBin = comm.internal.utilities.de2biBase2LeftMSB(bleObj.ChannelIndex,dewhitenStateLen);
    initState = [1 chanIdxBin]; % Initial conditions of shift register
    bits = ble.internal.whiten(decodeData,initState);

    % Now we can extract the data exactly from the dewhittened bits,
    % and find the PDU and CRC.

    % 1. The PDU Length field is in the second byte of the PDU, so we can
    % get that directly. 2. We can convert this binary number to a
    % decimal with the matlab utilities function. 3. This can be
    % converted to bits by multiplying the scalar value by 8

    % PDU lenght changes per packet, and fills with nonsense in the
    % other array indicies

    % This is performed in order to know how much dewhittened
    % information to process. Each packet will have a different PDU
    % length. Knowing this, we can remove the uneccesary data from the
    % end of the array everything we process a packet.

    PDULenField = double(dewhitenedBits(9:16));
    PDULenBytes = comm.internal.utilities.bi2deRightMSB(PDULenField',2);
    PDULenBits = PDULenBytes*8;

    % Check that the length of the dewhitened bits is equal to the
    % length of the PDU, the header and the CRC code. 
    if length(bits) >= (PDULenBits + bleObj.CRCLength + bleObj.HeaderLength)
       % Extract data directly, to a CRC check, and find PER
        extractedPacket = dewhittenedBits(1:PDULenBits + bleObj.CRCLength + bleObj.HeaderLength);
        crcPDUBits = extractedPacket(bleObj.HeaderLength + 1: end);
        %With extracted data, perform CRC check:
        [pduPayload, error] = crcDet(crcPDUBits);
    end
end
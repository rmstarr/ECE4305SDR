function bleObj = configBLEReceiver(phyMode)

% Function returns BLE parameters needed to run the code. This simplifies
% the code in regards to use of certain constants and metrics throughout
% our calculations. 


% NOTE FOR LATER: THE PACKET LENGTH CHANGES DEPENDING ON THE PHY MODE!!!!
% BE SURE TO GO BACK AND CHANGE THE CODE TO VARY THE PACKET SIZE, SINCE IN
% THIS CURRENT VERSION IT'S FIXED TO 2140


% Check over with Robbies Transmitter File
bleObj.Mode = phyMode;
bleObj.AccessAddLen = 32;    % Length of access address
bleObj.SamplesPerSymbol = 8; % Samples per symbol
bleObj.ChannelIndex = 37;    % Channel index value in the range [0,39] Subject to change
bleObj.CRCLength = 24;       % Length of CRC
bleObj.HeaderLength = 16;    % Length of PDU header
bleObj.MaximumPayloadLength = 255*8;  % Maximum payload length as per the standard

% Derive frame length, minimum packet length and symbol rate based on mode
bleObj.sampleRateHz = 1e6;
bleObj.samplesPerSymbol = 8;
bleObj.packetLength = 2120;
bleObj.samplesPerPacket = 2120; % number of bits transferred over one frame

% Gaussian Matched Filtering: Using gaussDesign()
BT = 0.5;
span = 1;
bleObj.filt = gaussdesign(BT,span,bleObj.SamplesPerSymbol);


bleObj.SymbolRate = 1e6;
if strcmp(bleObj.Mode,'LE1M')
    bleObj.PrbLen = 8;
    bleObj.blePreamble = [0 1 0 1 0 1 0 1]';
else
    bleObj.PrbLen = 16;
    bleObj.SymbolRate = 2e6;  % Symbol rate for 'LE2M'
    bleObj.blePreamble = [0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1]';
end

% INSERT DEFINITION FOR PACKET LENGTH





% Access Address of Receiver:
bleObj.accAddHex = 'A8C8F245'; % NOTE: this is address in the example file, 
% Access will need to match the transmitter. 

% Assign access address in binary:
bleObj.AccessAddress = comm.internal.utilities.de2biBase2RightMSB(hex2dec(bleObj.accAddHex),bleObj.AccessAddLen)'; % Access address in binary

% CRC Polynomial for the CRC check in PHY recovery:
bleObj.CRC_poly = 'z^24 + z^23 + z^18 + z^14 + z^12 + z^8 + 1'; 



end
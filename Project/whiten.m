function y = whiten(x,whitenInit)
%whiten Whiten/Dewhitens binary input
%   Y = whiten(X, WHITENINIT) whitens or dewhitens the binary input X, by
%   using the generator polynomial x^7+x^4+1. WHITENINIT is a 7-by-1 binary
%   column vector of numeric type. The same function is used to whiten at
%   the transmitter and dewhiten at the receiver.
%
%   Reference - Bluetooth specifications version 5.0, vol-6, part-B,
%   section-3.2.
%
%   Copyright 2018 The MathWorks, Inc.

%#codegen

inputClass = class(x);
buffSize = min(127,size(x,1));
I = coder.nullcopy(zeros(buffSize,1,inputClass));

% Whitening sequence generated using generator polynomial
for i = 1:buffSize
   pastState7 =  whitenInit(7);
   pastState4 = whitenInit(4);
   I(i) = whitenInit(7);                         % 127-bit whitening sequence
   whitenInit = circshift(whitenInit,1);         % Circular shift
   whitenInit(5) = xor(pastState4,pastState7);   % x^7 xor x^4
end

% Generate a periodic sequence from I and xor with the input
whiteningSeq = repmat(I,ceil(size(x,1)/buffSize),1);
y = cast(xor(x,whiteningSeq(1:size(x,1))),inputClass);

end
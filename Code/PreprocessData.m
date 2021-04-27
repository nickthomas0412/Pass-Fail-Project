function dataOut = PreprocessData(data)
%% This function preprocesses the input data
% 1 - cleans the data with low and high pass filters
% 2 - performs an FFT to extract the amplitude and phase against frequency

% Function inputs:
% data - The timeseries data from the sensor

% Function outputs:
% dataOut - Structure containing the result of the FFT
% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

% Process the data
dt = (data.Time(2) - data.Time(1))/1000;
fs = 1/dt;

% Remove low frequencies below 100 Hz
data.ChannelA = highpass(data.ChannelA,100,fs);

% Reset the time to 0 for the first data point
if data.Time(1) < 0
    data.Time = data.Time + abs(data.Time(1));
else
    data.Time = data.Time - abs(data.Time(1));
end

dataOut.rawSig = data.ChannelA;
dataOut.rawSigTime = data.Time;

% Perform the FFT
y = data.ChannelA;
NFFT = length(y);
Y = fft(y)/NFFT; % N-point complex DFT

dataOut.f = fs/NFFT*(0:(NFFT/2))';

% Calculate the amplitude
P2 = abs(Y);
P1 = P2(1:NFFT/2+1);
P1(2:end-1) = 2*P1(2:end-1);

dataOut.amp = P1;

% Calculate the phase
Ymodified = Y;
threshold = max(P1)*(1/100); % 1% above
Ymodified(abs(Y) < threshold) = 0;

phase2 = atan2(imag(Ymodified),real(Ymodified));
phase1 = phase2(1:NFFT/2+1);

dataOut.phase = phase1;
end

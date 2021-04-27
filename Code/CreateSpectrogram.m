function im = CreateSpectrogram(saveCSV,type,filePath,data)
%% This function parses the CSV data file and creates a spectrogram
% The spectrogram is saved in the same location as the CSV file

% Function inputs:
% saveCSV - Yes or No if the spectrogram should be saved
% type - Training or Test if the data is read from a file or passed in
% filePath - The file path of the CSV file
% data - If a 'Test' then the data is passed in, if not it is read

% Function outputs:
% im - Matrix array of RGB information for the image

% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

%% Extract image data from spectrogram
if type == "Training"
    % Load the data from the CSV file
    [path,file,~] = fileparts(filePath);
    data = readtable(filePath);
else
    path = pwd;
    file = 'temp';
end

% Preprocess the data
dt = (data.Time(2) - data.Time(1))/1000;
fs = 1/dt;

% Remove low frequencies below 100 Hz
data.ChannelA = highpass(data.ChannelA,100,fs);

% Standardise the data 2ms before the impact and have 173ms of data after
try
    noiseThreshold = max(data.ChannelA)*(10/100); % Noise 10% of max measurement
    impactIdxs = find(data.ChannelA >= noiseThreshold); 
    impactIdx = impactIdxs(1) - round(0.002/dt); % Keep data 2ms before impact
    data = data(impactIdx:end,:);
    
    endIdx = round(0.175/dt); % Keep 175ms of data
    data = data(1:endIdx,:);
catch
    % Data is above 1 or not 175ms of data
end

if data.Time(1) < 0
    data.Time = data.Time + abs(data.Time(1));
end

pspectrum(data.ChannelA,fs,"spectrogram");
ylim([0 100]) % Limit to 100 kHz
axis off;
colorbar off;
title("");

newFilePath = fullfile(path,append(file,'.png'));
exportgraphics(gcf,newFilePath,'BackgroundColor','none','Resolution',100);
close

im = imread(newFilePath);

if saveCSV == "Yes"
    % File is already saved
else
    delete(newFilePath);
end

end

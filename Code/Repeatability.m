%% Script to calculate the std and mean of blades
folderPath = '/Users/nickthomas/Documents/University/Year 5/FYP/9 - Code/Blades_impact';
bladeName = 'Blade3_Time';
bladesPath = fullfile(folderPath,bladeName);
freqPeaks = load('freqPeaksLoc').freqPeaks;

files_ds = tabularTextDatastore(bladesPath,'NumHeaderLines',2,...
    'VariableNames',["Time","ChannelA"],...
    'IncludeSubfolders',true,'FileExtensions',{'.csv'},...
    'ReadSize','file');   

% Call the PreprocessData function for the datastore
preprocessedFiles_ds = transform(files_ds,...
    @(data) PreprocessData(data));

ExtractedFeatures_ds = transform(preprocessedFiles_ds,...
    @(data) ExtractFeature(data,freqPeaks));

dataOut = struct2table(readall(ExtractedFeatures_ds));
data = table2array(removevars(dataOut,{'rawSig','rawSigTime','f','amp',...
    'phase','extractedFreqs','ampAtExtractedFreqs'}));

standardDevs = std(data)
means = mean(data,1)
            
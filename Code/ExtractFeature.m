function dataOut = ExtractFeature(data,freqPeaks)
%% This function extracts features from the input signal data

% Function inputs:
% data - data from the preprocessed stage
% freqPeaks - Array of estimated locations of the natural frequency peaks

% Function outputs:
% dataOut - Structure containing the result of preprocessed stage and the
% extracted features
% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

%% Extract Features below 
dataOut = data;

% Identify peaks and therefore natural frequency modes
% More feature selection can be implemented here

if ~isempty(freqPeaks)
    for i = 1:numel(freqPeaks)
        % Cutoff frequencies may need to change from 500 Hz in the future! 
        midFreq = freqPeaks(i) * 1000; % Convert to Hz
        botFreq = midFreq - 500; % Bottom cutoff
        [~,botFreqIdx] = min(abs(data.f - botFreq)); % Bottom cutoff index
        topFreq = midFreq + 500; % Top cutoff
        [~,topFreqIdx] = min(abs(data.f - topFreq)); % Top cutoff index
        [~,maxIdx] = max(data.amp(botFreqIdx:topFreqIdx)); % Index of peak

        % Need -1 as both include the bottom frequency index
        maxFreqIdx = botFreqIdx + maxIdx - 1; 
        extractedFreq(i) = data.f(maxFreqIdx);
        ampAtExtractedFreq(i) = data.amp(maxFreqIdx);

        name = ['Feat',num2str(i)];
        dataOut.(name) = extractedFreq(i);
    end
    
    % All the extracted fequencies in an array for ease of plotting
    dataOut.extractedFreqs = extractedFreq;
    dataOut.ampAtExtractedFreqs = ampAtExtractedFreq;
end

end
function [dataOut,classPred,probability,status] = ...
    RunSingleTest(MLmodel,testType,filePath)
%% This function is called from the Pass_Fail application
% It contains the logic required to perform a single test by calling all
% of the helper functions

% Function inputs:
% MLmodel - Structure containing the machine learning model to be used
% testType - If the test is simulated or using hardware
% filePath - The file path of the simulated file

% Function outputs:
% dataOut - Structure containing all the outputs from the helper functions
% classPred - The predicited classification ('UD' or 'D')
% probability - The probability the blade is 'UD'
% status - The result of the function (any errors)
% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

%% Function begins:
% Construct status struct which is passed through functions and is 
% reported back to the UI
status.error = 0;
status.desc = "";
dataOut = struct();
classPred = "NA";
probability = "NA";

try
% Import Data and process it
    if testType == "Live"
        [data,status] = ImpactTest("No",0,"","");
        if status.error == 1
            % There has been a problem with the oscilloscope
            return
        end

    elseif testType == "Simulated"
        % Import CSV file and run simulated test
        data = readtable(filePath);
    else
        status.error = 1;
        status.desc = "Incorrect Test Type";
    end

    % Call the PreprocessData function
    preprocessedData = PreprocessData(data);

    % Call the ExtractFeature function
    ExtractedFeaturesData = ExtractFeature(preprocessedData,...
        MLmodel.usedFreqPeaks);

    dataOut = ExtractedFeaturesData;
        
    if MLmodel.MLmodelType == "DL"
        Im = CreateSpectrogram("No","Test",filePath,data);
        % Resize the image for 224x224 as that is the model input
        dataTest = imresize(Im,[224 224]);
    else
        % Remove the unused columns
        dataTest = removevars(struct2table(dataOut,'AsArray',true),...
            {'rawSig','rawSigTime','f','amp','phase','extractedFreqs',...
            'ampAtExtractedFreqs'});
    end
    
    % Apply ML
    [classPred,probability] = Classify(MLmodel,dataTest);
    
    status.error = 0;
    status.desc = "";
catch ME
    status.error = 1;
    status.desc = append('RunSingleTest.m: ',ME.message);
end

end

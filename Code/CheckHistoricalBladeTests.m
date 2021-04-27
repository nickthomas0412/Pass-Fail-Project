function [highestIdx,bladeFolderPath] = ...
    CheckHistoricalBladeTests(trainingDataFolderPath,testFileName)
%% This function identifies the current index value of saved files

% Function inputs:
% trainingDataFolderPath - The path to where the training data is kept
% testFileName - The file name of the test blade

% Function outputs:
% highestIdx - Highest index of previous saved tests
% bladeFolderPath - The folder path of the test blade being saved
% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

%% Check to see if there is a folder with the blade name
bladeCondition = string(extractAfter(testFileName,'_'));
if bladeCondition == "UD"
    bladeFolder = "Undamaged";
    folders = dir(fullfile(trainingDataFolderPath,bladeFolder));
else
    bladeFolder = "Damaged";
    folders = dir(fullfile(trainingDataFolderPath,bladeFolder));
end

bladeFolderPath = fullfile(trainingDataFolderPath,bladeFolder,testFileName);

folderExist = strcmpi({folders.name},{testFileName});
if any(folderExist)
    % The folder already exists
    checkFiles = 1;
else
    % Make the folder and set index to 0
    mkdir(bladeFolderPath);
    checkFiles = 0;
    highestIdx = 0;
end
    

%% Check for previous repeats of blade inside the folder
% Check for previous tests with the blade name
if checkFiles == 1
    files = dir(fullfile(trainingDataFolderPath,bladeFolder,testFileName) + "/*.csv");
    filesName = {files.name};

    bladeName = string(extractBefore(filesName,'-'));

    if testFileName(end) == '-'
        testFileName = testFileName(1:end-1);
    end
    
    % Have 1 in the array if there are files already there
    alreadyThere = bladeName == testFileName;

    if any(alreadyThere)
        indexes = str2double(extractBetween(filesName(alreadyThere),'-','.'));
        highestIdx = max(indexes);
    else
        highestIdx = 0;
    end
end

end
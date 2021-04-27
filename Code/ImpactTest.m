function [dataOut,status] = ImpactTest(saveCSV,testIdx,folderPath,...
    testFileName)
%% This function is called from the Pass_Fail application or RunSingleTest
% It contains the logic required to perform an impact, record the impact,
% save the impact to CSV by calling all of the helper functions

% Function inputs:
% saveCSV - Yes or No for if the csv file should be saved
% testIdx - The index that should be appended to the test file name
% folderPath - If the test is simulated or using hardware
% testFileName - The file name of the blade

% Function outputs:
% dataOut - Structure containing all the outputs from the helper functions
% status - The result of the function (any errors)
% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

%% Call functions to conduct the impact and record the data
[ps4000DeviceObj,blockGroupObj,timeIntervalNanoseconds,status] = ...
    ConfigurePS4000();
if status.error == 1
    dataOut = struct();    
    return
end

try
    hammerDropJob = batch(@DropHammer,1); % Parallel job as reading is blocking
    tStart = datetime;
    invoke(blockGroupObj,'runBlock',0); % Blocking

    [numSamples,~,chA] = invoke(blockGroupObj,'getBlockData',0,0,1,0);
    timeNs = double(timeIntervalNanoseconds) * double(0:numSamples - 1);
    timeMs = (timeNs / 1e6)';
    data = table(timeMs,chA,'VariableNames',{'Time','ChannelA'});
    
    % res = fetchOutputs(hammerDropJob);
    
    tEnd = datetime;
    if seconds(diff(datetime([tStart;tEnd]))) > 15
        % The oscilloscope was not trigger, no impact
        status.error = 1;
        status.desc = ['The oscilloscope was not triggered, ',...
            'the threshold may be set too high or there was not an impact'];
        throw(MException('MATLAB:noTrigger','Scope not triggered'));
    end

    % Save file to CSV
    if saveCSV == "Yes"
        filename = fullfile(folderPath,testFileName + "-" + testIdx + ".csv");
        writetable(data,filename)
    end
    
    dataOut = data;
    status.error = 0;
    status.desc = "";
catch ME
    dataOut = struct();    
end

invoke(ps4000DeviceObj,'ps4000Stop');
disconnect(ps4000DeviceObj);
delete(ps4000DeviceObj);

end

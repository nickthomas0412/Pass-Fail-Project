function [ps4000DeviceObj,blockGroupObj,timeIntervalNanoseconds,status] = ...
    ConfigurePS4000()
% This function configures the PS4000 scope ready to record data
% https://www.mathworks.com/matlabcentral/fileexchange/
% 49117-picoscope-4000-series-matlab-generic-instrument-driver
% PS4000_ID_Block_Example as an example

% Function inputs:
% Change timeBaseIndex to change the sampling rate
% Change threshold to change the minimum trigger voltage

% Function outputs:
% ps4000DeviceObj - The oscilloscope object handle
% blockGroupObj - The block data extraction process
% timeIntervalNanoseconds - The sample time step
% status - The result of the function (any errors)

% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

PS4000Config; % Obtain internal values and files required for scope

%% Device connection
if (exist('ps4000DeviceObj', 'var') && ...
        ps4000DeviceObj.isvalid && strcmp(ps4000DeviceObj.status, 'open'))
            
    % Close connection to device
    disconnect(ps4000DeviceObj);
    delete(ps4000DeviceObj);
    
else
    ps4000DeviceObj = struct();
    blockGroupObj = struct();
    timeIntervalNanoseconds = 0;
        
    % Create a device object. Note the device must be plugged in
    try
        % Try to create an icdevice from the driver. This often fails
        ps4000DeviceObj = icdevice('picotech_ps4000_generic.mdd');
    catch ME
        disp(ME.message);
        status.error = 1;
        status.desc = ['Problem connecting to the oscilloscope, ',... 
            'check it is connected correctly and if so power cycle'];
        return
    end
    
    try
        % Try to connect device object to hardware. This often fails
        connect(ps4000DeviceObj);
    catch ME
        disconnect(ps4000DeviceObj);
        delete(ps4000DeviceObj);
        disp(ME.message);
        status.error = 1;
        status.desc = ['Problem connecting to the oscilloscope, ',... 
            'try another USB hole, if all have been tried, restart the computer'];
        return
    end

    try
        %% Set Channels to use
        % Channels       : 1 - 3 (PS4000_CHANNEL_B - PS4000_CHANNEL_D)
        % Enabled        : 0
        % Type           : 1 (DC)
        % Range          : 8 (ps4000Enuminfo.enPS4000Range.PS4000_5V)

        % Turn channel B off as default and only use A
        [Status.setChB] = invoke(ps4000DeviceObj,'ps4000SetChannel',1,0,1,8);

        if (ps4000DeviceObj.channelCount == PicoConstants.QUAD_SCOPE)

            % Turn channel C and D off if 4 channel scope
            [Status.setChC] = invoke(ps4000DeviceObj,'ps4000SetChannel',2,0,1,8,0.0,0);
            [Status.setChD] = invoke(ps4000DeviceObj,'ps4000SetChannel',3,0,1,8,0.0,0);

        end

        %% Specify the sampling rate and maximum number of samples
        % Sampling time step = (timeBaseIndex - 1) / 20,000,000
        % Sampling time step = (5 - 1) / 20,000,000 = 200 ns

        Status.getTimebase2 = PicoStatus.PICO_INVALID_TIMEBASE;
        timeBaseIndex = 5; % 200 ns

        while (Status.getTimebase2 == PicoStatus.PICO_INVALID_TIMEBASE)

            [Status.getTimebase2,timeIntervalNanoseconds,maxSamples] = ...
                invoke(ps4000DeviceObj,'ps4000GetTimebase2',timeBaseIndex, 0);

            if (Status.getTimebase2 == PicoStatus.PICO_OK)
                break;  
            else
                timeBaseIndex = timeBaseIndex + 1; 
            end    

        end

        fprintf('Timebase index: %d, sampling interval: %.1f ns\n',...
            timeBaseIndex,timeIntervalNanoseconds);

        % Configure the device |timebase| property value.
        set(ps4000DeviceObj,'timebase',timeBaseIndex);

        %% Set up the trigger for the impact
        triggerGroupObj = get(ps4000DeviceObj,'Trigger');
        triggerGroupObj = triggerGroupObj(1);

        [Status.setTriggerOff] = invoke(triggerGroupObj,'setTriggerOff');

        % Set device to trigger automatically after 15 seconds 
        % There must be a problem if there is no impact
        set(triggerGroupObj,'autoTriggerMs',15000);
    % 
    %     % Channel     : 0 (ps4000Enuminfo.enPS4000Channel.PS4000_CHANNEL_A)
    %     % Threshold   : 500 (mV)
    %     % Direction   : 2 (ps4000Enuminfo.enPS4000ThresholdDirection.PS4000_RISING)
        threshold = 10;
        [Status.SimpleTrigger] = invoke(triggerGroupObj,...
            'setSimpleTrigger',0,threshold,2);


        %% Set up the block parameters
        blockGroupObj = get(ps4000DeviceObj,'Block');
        blockGroupObj = blockGroupObj(1);

        % Set pre-trigger and post-trigger samples as required - the total of 
        % this should not exceed the value of maxSamples

        numPointsBefore = round(10e-3 / timeIntervalNanoseconds/1e-9); % 10ms before
        numPointsAfter = round(190e-3 / timeIntervalNanoseconds/1e-9); % 190ms after
        set(ps4000DeviceObj,'numPreTriggerSamples',numPointsBefore);
        set(ps4000DeviceObj,'numPostTriggerSamples',numPointsAfter);

        %[Status.runBlock] = invoke(blockGroupObj,'runBlock',0);
        %[numSamples,overflow,chA] = invoke(blockGroupObj,'getBlockData',0,0,1,0);

        %[Status.runBlock] = invoke(ps4000DeviceObj,'ps4000RunBlock', 0);
        %ps4000IsReady
        %ps4000GetValues

    %     timeNs = double(timeIntervalNanoseconds) * double(0:numSamples - 1);
    %     timeMs = (timeNs / 1e6)';
    %     data = table(timeMs,chA,'VariableNames',{'Time','ChannelA'});
    %     plot(timeMs,chA);
    status.error = 0;
    status.desc = '';

    catch ME
        % Disconnect device object from hardware.
        invoke(ps4000DeviceObj,'ps4000Stop');
        disconnect(ps4000DeviceObj);
        delete(ps4000DeviceObj);
    end
end

end
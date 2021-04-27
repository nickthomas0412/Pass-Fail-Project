%% GENERATE PS4000 PROTOTYPE FILES
% Generate prototype (and thunk libraries) for the ps4000 libraries.
% This script should be run from the same directory as the Instrument Driver
% i.e. the win32, win64, glnax64 and maci64 directories should be
% sub-directories. 
% The ps4000Api.h, ps4000Wrap.h and PicoStatus.h files should be in the
% same directory as this file.
%
% Copyright © 2014 - 2017 Pico Technology Ltd. All rights reserved.

% Obtain current directory
ps4000GenPrototypes.currentDir = pwd;

% Find file name
ps4000GenPrototypes.fileName = mfilename('fullpath');

% Only require the path to this file
[ps4000GenPrototypes.pathStr] = fileparts(ps4000GenPrototypes.fileName);

addpath(ps4000GenPrototypes.pathStr);

if (~isequal(ps4000GenPrototypes.currentDir, ps4000GenPrototypes.pathStr))
   
    cd(ps4000GenPrototypes.pathStr);
    
end

% Identify architecture e.g. 'win64'
ps4000GenPrototypes.archStr = computer('arch');

if (exist(fullfile(ps4000GenPrototypes.pathStr, ps4000GenPrototypes.archStr), 'dir') == 0)
   
    mkdir(ps4000GenPrototypes.archStr);
    
end

% Incorporate architecture name into prototype file
ps4000GenPrototypes.ps4000MFileName = strcat('ps4000MFile', '_', ps4000GenPrototypes.archStr);
ps4000GenPrototypes.ps4000WrapMFileName = strcat('ps4000WrapMFile', '_', ps4000GenPrototypes.archStr);

% Change directory into the directory corresponding to the architecture
cd(ps4000GenPrototypes.archStr);

% Generate files according to the operating system

if (ismac())
    
    % Libraries (including wrapper libraries) are stored in the PicopScope
    % 6 App folder.
    
    addpath('/Applications/PicoScope 6.app/Contents/Resources/lib');
    loadlibrary('libps4000.dylib', 'ps4000Api.h', 'mfilename', ps4000GenPrototypes.ps4000MFileName, 'alias', 'ps4000');
    loadlibrary('libps4000Wrap.dylib', 'ps4000Wrap.h', 'mfilename', ps4000GenPrototypes.ps4000WrapMFileName, 'alias', 'ps4000Wrap');
    
elseif (isunix())
	    
    % Edit to specify location of .so files or place .so files in same directory
    addpath('/opt/picoscope/lib/'); 
    
	loadlibrary('libps4000.so', 'ps4000Api.h', 'mfilename', ps4000GenPrototypes.ps4000MFileName, 'alias', 'ps4000');
    loadlibrary('libps4000Wrap.so', 'ps4000Wrap.h', 'mfilename', ps4000GenPrototypes.ps4000WrapMFileName, 'alias', 'ps4000Wrap');
		
elseif (ispc())
    
    % Microsoft Windows operating system
    
    % Set path to dll files if the Pico Technology SDK Installer has been
    % used or place dll files in the folder corresponding to the
    % architecture. Detect if 32-bit version of MATLAB on 64-bit Microsoft
    % Windows.
    
    ps4000GenPrototypes.winSDKInstallPath = '';
    
    if (strcmp(ps4000GenPrototypes.archStr, 'win32') && exist('C:\Program Files (x86)\', 'dir') == 7)
       
        try 
            
            addpath('C:\Program Files (x86)\Pico Technology\SDK\lib\');
            
        catch err
           
            warning('PS4000GeneratePrototypes:DirectoryNotFound', ['Folder C:\Program Files (x86)\Pico Technology\SDK\lib\ not found. '...
                'Please ensure that the location of the library files are on the MATLAB path.']);
            
        end
        
    else
        
        % 32-bit MATLAB on 32-bit Windows or 64-bit MATLAB on 64-bit
        % Windows operating systems
        try 
        
            addpath('C:\Program Files\Pico Technology\SDK\lib\');
            
        catch err
           
            warning('PS4000GeneratePrototypes:DirectoryNotFound', ['Folder C:\Program Files\Pico Technology\SDK\lib\ not found. '...
                'Please ensure that the location of the library files are on the MATLAB path.']);
            
        end
        
    end
    
    [notfound, warnings] = loadlibrary('ps4000.dll', 'ps4000Api.h', 'includepath', 'C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\include\', 'mfilename', ps4000GenPrototypes.ps4000MFileName);
    [notfoundWrap, warningsWrap] = loadlibrary('ps4000Wrap.dll', 'ps4000Wrap.h', 'includepath', 'C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\include\', 'mfilename', ps4000GenPrototypes.ps4000WrapMFileName);
    
    
else
    
    error('PS4000GeneratePrototypes:OperatingSystemNotSupported', 'Operating system not supported - please contact support@picotech.com');
    
end

libfunctionsview('ps4000');
libfunctionsview('ps4000Wrap');

unloadlibrary('ps4000');
unloadlibrary('ps4000Wrap');

% Display files created and change back to directory
disp(ps4000GenPrototypes.archStr)
dir(pwd);
cd(ps4000GenPrototypes.pathStr);

clear ps4000GenPrototypes;
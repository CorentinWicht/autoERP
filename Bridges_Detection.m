% Bridge Detection
% The script permits to check if there is some bridges between electrodes in
% your raw EEG data. It should be execute before Filtering_epoching.m in
% the piepline. 
%
% Input: 
% - the root folder which contain the participant folders with the raw .bdf
% files inside
% - Chose the name of the Excel file which contain the output of processing
%
% Output
% A Excel sheet with the name of EEG file in first column, the number of
% bridge detected in the second and the indices of the bridged electrodes
% for the next ones. 
% If some bridge is detected, one over the two electrodes bridges would need to be
% interpolate at the channel interpolation step of ERP (in the ERPs.m
% script).
%
% This script required the signal processing toolbox of Matlab as well as Microsoft Excel install on Windows.
%
% Michaël Mouthon, 05.06.2020


clear variables; close all

% getting path of the script location
p = matlab.desktop.editor.getActiveFilename;
I_p = strfind(p,'\');
p2 = p(1:I_p(end)-1);

% Path of all needed functions
% addpath(strcat(p2,'\Functions\bdfplugin'));
addpath(strcat(p2,'\Functions\Functions'));
addpath(strcat(p2,'\Functions\eeglab14_1_2b'));

%Specity data folder 
root_folder = uigetdir('title',...
    'Choose the path of your most upper folder containing your RAW EEG files.');
cd(root_folder)
FileList = dir(['**/*.bdf' ]);
nbfile=length(FileList);

%Specify output file's name 
BridgeSummary=cell(nbfile+1, 3);
BridgeSummary(1,:)={'EEG file','count of Bridges', 'channels indicies Bridged'};
fileoutputNameBridge=inputdlg({'How do you want to call the output file (WARNING: consider that if you run several times the script with the same file name, previous result will be overwritten'},'eBridge output file',1,{'eBridge_check.xlsx'});
fileoutputNameBridge=fileoutputNameBridge{1};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Start processing each file separetely
for i=1:nbfile
    FileName = [FileList(i).folder,'\',FileList(i).name];
    
    %import dataset
    EEG = pop_biosig(FileName);
    
    %Check bridge with eBridge
    EB=eBridge(EEG);
    
    %set the result in the outputcell
    BridgeSummary(i+1,1)=cellstr(FileList(i).name);
    BridgeSummary(i+1,2)=num2cell(EB.Bridged.Count);

    %save the channel's indices which are Bridged in the outputcell
    if EB.Bridged.Count>0
        for k=1:EB.Bridged.Count
            BridgeSummary(i+1,2+k)=num2cell(EB.Bridged.Indices(k));
        end
    end
    clear EEG
end

%save the output cell in the root folder
xlswrite(strcat(root_folder,'\', fileoutputNameBridge), BridgeSummary); 
display ('finish');

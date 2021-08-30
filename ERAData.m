%% Preparing data for ERA toolbox


%% Authors

% Author: Corentin Wicht, LNS, 2021
% - corentin.wicht@unifr.ch
% - https://github.com/CorentinWicht

% This work is licensed under a Creative Commons Attribution-NonCommercial
% 4.0 International License (CC BY-NC)
%% --------------------- PRESS F5 -------------------- %%
%% --------------------------------------------------- %%
 clear variables; close all
 warning('off','MATLAB:table:RowsAddedExistingVars')
%% MAIN SCRIPT

% ---------- GET DIRECTORIES
% getting path of the script location
p = matlab.desktop.editor.getActiveFilename;
I_p = strfind(p,'\');
p2 = p(1:I_p(end)-1);

% ---------- SET PATHS
% Path of all needed functions
addpath(strcat(p2,'\Functions\Functions'));
addpath(strcat(p2,'\Functions\eeglab2021.0'));
addpath(genpath(strcat(p2,'\Functions\EEGInterp')));

% Path of most upper folder containing epoched data
root_folder = uigetdir('title',...
    'Enter the path of your most upper folder containing all your EPOCHED data');
cd(root_folder)
FileList = dir('**/*.set');

% Path of the folder where to save the output
save_folder = uigetdir(root_folder,...
    'Enter the path of the folder where you want to save the .csv output');

%%%%%%% Define design
% Default values for the GUI below 
to_display = [{'W';'Condition';'GDTD';'GDTC';'GCTD'} cell(5,2)];

% Table
ScreenSize=get(0,'ScreenSize');
f = figure('Position', [ScreenSize(3)/2-500/2 ScreenSize(4)/2-500/2 500 600]);
p = uitable('Parent', f,'Data',to_display,'ColumnEdit',true(1,size(to_display,2)),'ColumnName',...
    {'Factor','IgnoreFolders','IgnoreFiles'},'CellEditCallBack','DesignList = get(gco,''Data'');');
p.Position = [50 -100 350 400];
uicontrol('Style', 'text', 'Position', [20 350 450 220], 'String',...
        {['DESIGN DEFINITION' newline ''],['The definition of the design needs to be structured in the following way:'...
        newline 'FOR THE FIRST COLUMN (i.e. factor)'...
        newline '1st line = Within (W) or Between-subject (B)'...
        newline '2nd line = Name of the factor'...
        newline '3rd+ lines = Name of the levels'...
        newline ...
        newline 'FOR THE LAST TWO COLUMNS (i.e. data removal)'...
        newline 'The last two columns enables to remove undesired data (e.g. at the level of i) folders or ii) file names'...
        newline '' newline '! THE NAMES MUST BE THE SAME AS YOUR FILES/FOLDERS !']});
    
% Wait for t to close until running the rest of the script
waitfor(p)

% If no modifications to the example in the figure
if ~exist('DesignList','var')
    DesignList = to_display;
end

% Removing files/folders if specified
if nnz(~cellfun('isempty',(DesignList(:,2)))) % folders
    for k=1:sum(~cellfun('isempty',(DesignList(:,2))))
        FileList = FileList(~contains({FileList.folder},DesignList{k,2}));
    end
elseif nnz(~cellfun('isempty',(DesignList(:,3)))) % files
    for k=1:sum(~cellfun('isempty',(DesignList(:,3))))
        FileList = FileList(~contains({FileList.name},DesignList{k,3}));
    end
end

% Sorting according to natural order
[~, NatSortIdx] = natsort({FileList.name});
FileList = FileList(NatSortIdx);

%%%%%%%%%% Define the EEG components of interest
% Default values for the GUI below 
to_display = cell(4,4);

% Define Components and bounds
ScreenSize=get(0,'ScreenSize');
f = figure('Position', [ScreenSize(3)/2-500/2 ScreenSize(4)/2-500/2 600 600]);
p = uitable('Parent', f,'Data',to_display,'ColumnEdit',true(1,size(to_display,2)),'ColumnName',...
    {'Component','Trigger','Bounds (TF)','Electrodes'},'Position',[50 -100 500 400],...
    'CellEditCallBack','CompList = get(gco,''Data'');');
uicontrol('Style', 'text', 'Position', [60 350 450 130], 'String',...
        {['COMPONENTS DEFINITION' newline ''],['The definition of the Period(s) of Interest needs to be structured in the following way:'...
        newline '1st column = Name of the Component (e.g. N2)',...
        newline '2nd column = Name of the trial type/trigger',...
        newline 'To define how to average the values for the POI:'... 
        newline '3rd column = Timings in TF (lower and higher bounds separated by a SPACE)',...
        newline '4th column = Cluster of electrodes']});
% Wait for t to close until running the rest of the script
waitfor(p)

% If no modifications to the example in the figure
if ~exist('DesignList','var')
    CompList = to_display;
end

% Remove empty lines and store data for the current component
EmptIdx = ~cellfun(@(x) isempty(x),CompList(:,1));
CompList = CompList(EmptIdx,:);

%%%%%%%% Prompt (un)blinding
if sum(~cellfun('isempty',(DesignList(:,1))))>3 % if design is specified
    
    % Saving group/conditions for later use
    Levels = DesignList(3:end,1);
    Levels = Levels(~cellfun('isempty',Levels));
    
    % Rename conditions if double-blind
    PromptBlind = questdlg('Would you like to rename the levels (e.g. in case of double-blind design) ?', ...
        'Unblinding','Yes','No','Yes');

    % Save a temporary excel file (first column is filenames)
    Data = horzcat(['FILENAMES';{FileList.name}'],['NEW LEVEL NAMES';cell(length({FileList.name}),1)]);
    xlswrite([save_folder '\IndividualUnblinding.xlsx'],Data)

    % Open excel
    e=actxserver('excel.application');
    eW=e.Workbooks;
    eF=eW.Open([save_folder '\IndividualUnblinding.xlsx']); 
    eS=eF.ActiveSheet;
    e.visible = 1; % If you want Excel visible.

    % Message box stoping code execution
    MessageBox('The code will continue once you press OK','Wait for user input',30,250,70)

    % edit sheet
    try
        eF.Save;
        eF.Close; % close the file
        e.Quit; % close Excel entirely
    catch
        disp('You closed the excel file before clicking OK on the message box.')
    end

    % Load the data and then delete the excel file
    Unblinding = readcell([save_folder '\IndividualUnblinding.xlsx']);
    Unblinding = Unblinding(2:end,:);
end

%% eeglab

eeglab nogui

% set double-precision parameter
pop_editoptions('option_single', 0);
time_start = datestr(now,'ddmmyyyy_HHMM');

%% For each file and condition, we load and merge datasets

% File names
FileNames = {FileList.name}';
FileNames = strrep(FileNames,'.set','');

% Waiting bar ! The epitome of UI !
h = waitbar(0,{'Loading' , ['Progress: ' '0 /' num2str(length(FileList))]});

% Empty matrix
Output = [];

% For each file
for File = 1:length(FileList)
    
    % Clearing the eeglab structures
    clear EEG
    ALLEEG = [];
    
    % Load the dataset
    EEG = pop_loadset('filename',FileList(File).name,'filepath',FileList(File).folder);
    
     % Bad channels interpolation
    if isfield(EEG,'BadChans')    

        % Bad Channels associated to this subject
        to_interp = EEG.BadChans.InterpChans;
        
      % Reintroduce the bad channels data 
        Temp = zeros(EEG.BadChans.nbchan,size(EEG.data,2),size(EEG.data,3)); PosGood = 1; PosBad = 1; 
        for m=1:EEG.BadChans.nbchan
            if ~ismember(m,EEG.BadChans.InterpChans) 
               Temp(m,:,:) = EEG.data(PosGood,:,:); PosGood = PosGood + 1;
%             else
%                 if m~=48 && m~=128 % Special case with reference electrode that requires interpolation
%                     % Restricting channel data length since EEG.data
%                     % size might have changed with artifact rejection
%                     Temp(m,:,:) = EEG.BadChans.data(PosBad,:,1:size(Temp,3));PosBad = PosBad + 1;
%                 end
            end
        end

        % Adjust the EEG structure
        EEG.data = Temp; EEG.chanlocs = EEG.BadChans.chanlocs;
        EEG.nbchan = EEG.BadChans.nbchan;
        EEG = eeg_checkset(EEG);

        % Multiquadratics interpolation
        EEG.data = EEGinterp('MQ',0.05,EEG,to_interp);
    end
    
    % Average referencing Cz
    EEG = average_ref(EEG,EEG.chaninfo.nodatchans);
    
    % Updating the waitbar
    waitbar(File/length(FileList),h,{'Loading' , ['Progress: ' num2str(File) '/' num2str(length(FileList))]})

    % For each component & Trigger
    for Comp = 1:size(CompList,1)
        
        % Finding the trials corresponding to "Trial type/Trigger"
        TrialIdx = strcmpi({EEG.event.type},CompList{Comp,2});
        Epochs = cell2mat({EEG.event.epoch});
        TrialIdx = unique(Epochs(TrialIdx));
        
        % Determining electrodes of interest
        % if provided as numbers
        ElectInt = str2num(CompList{Comp,4});
            
        if isempty(ElectInt) % if provided as electrode labels
            ElectInt = CompList{Comp,4};
            ElectInt = strsplit(ElectInt,' ');
            ElectInt = cellfun(@(x) find(strcmpi({EEG.chanlocs.labels},x)==1),ElectInt);
            ElectInt = sort(ElectInt);
        end
        
        % Averaging the data around Bounds and Electrodes of interest
        EEGTrialDat = squeeze(mean(EEG.data(ElectInt,str2num(CompList{Comp,3}),TrialIdx),[1,2]));
        
        % Storing the single-trial data in the output
        
        % If more than 1 group/condition
        if sum(~cellfun('isempty',(DesignList(:,1))))>3
            if strcmpi(PromptBlind,'Yes') % Unblinding
                FileInfo = [FileNames(File) strcat(CompList(Comp,1),'_',CompList(Comp,2)) Unblinding(File,end)];
                FileInfo = repmat(FileInfo,[length(EEGTrialDat),1]);
                
            else % No unblinding
                GroupInfo = Levels(cellfun(@(x) contains(FileNames(File),x),Levels));
                FileInfo = [FileNames(File) strcat(CompList(Comp,1),'_',CompList(Comp,2)) GroupInfo];
                FileInfo = repmat(FileInfo,[length(EEGTrialDat),1]);
            end
        else
            FileInfo = [FileNames(File) strcat(CompList(Comp,1),'_',...
                CompList(Comp,2))];
            FileInfo = repmat(FileInfo,[length(EEGTrialDat),1]);
        
        end
        Output = [Output; [FileInfo num2cell(EEGTrialDat)]];
    end
end

% Waitbar updating
waitbar(1,h,{'Done !' , ['Progress: ' num2str(length(FileList)) ' /' num2str(length(FileList))]});

% Changing output to table
TabOutput = cell2table(Output);
if sum(~cellfun('isempty',(DesignList(:,1))))>3
    TabOutput.Properties.VariableNames = {'ID', 'Trigger', 'Group', 'Measurement'};
else
    TabOutput.Properties.VariableNames = {'ID', 'Trigger', 'Measurement'};
end

% Saving output as .xlsx
writetable(TabOutput,[save_folder '\Output_' time_start '.xlsx'])

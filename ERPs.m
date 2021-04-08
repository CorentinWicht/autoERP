%% Creation of ERPs on epoched dataset

% This script will permit you to create flexible .eph ERPs from epoched
% data (.set). It will adapt to your condition nomenclature and folder
% structure, so minimum inputs need to be enter to create complexe
% averaging parameters. 
% It will load your datasets and organize them based on your selected parameters.
% Then it will reject artefacts (80 uV threshold) AFTER excluding selected bad
% channels. Averages between selected trials will be computed and selected 
% subjects will have their data interpolated after the averaging.

% Additionally, each time the data jumps of 30uV or more, the whole
% concerned epoch is removed.

% In order to have consistant signal to noise ratio, the same number of
% trials will be fetched for all the ERPs sharing the same subject and 
% condition. This number corresponds to the condition having the lowest 
% amount of trials.

% You will be able to choose between ERPs referenced to the average or to Cz.

% The number of rejected trials at each step will be saved in a .xlsx file


%% ------------ Merging and Averaging rules ---------- %%

% If you specify conditions, files without any detectable condition will be ignored.

% If you decide to not merge, each file in every subfolder will be
% considered independant.

% If you decide to merge and enter conditions, the files in each folder
% sharing the same condition name will be merged together.

% If you decide to merge but do not enter conditions, all files in each
% subfolder will be mergeresampd together.

% If you enter conditions but do not specify trigger names, all the trials
% will be averaged together.

%% Authors

% Hugo Najberg (script, protocol)
% Corentin Wicht (script, protocol)
% Michael Mouthon (protocol)
% Lucas Spierer (protocol)

% If you have questions or want to contribute to this pipeline, feel free 
% to contact hugo.najberg@unifr.ch

%% --------------------- PRESS F5 -------------------- %%
%% --------------------------------------------------- %%
 clear variables; close all
 warning('off','MATLAB:table:RowsAddedExistingVars')
%% ----------------- PARAMETERS ------------- %%

% ---------- GET DIRECTORIES
% getting path of the script location
p = matlab.desktop.editor.getActiveFilename;
I_p = strfind(p,'\');
p2 = p(1:I_p(end)-1);

% ---------- SET PATHS
% Path of all needed functions
addpath(strcat(p2,'\Functions\Functions'));
% addpath(strcat(p2,'\Functions\eeglab14_1_2b'));
addpath(strcat(p2,'\Functions\eeglab2021.0'));
addpath(genpath(strcat(p2,'\Functions\EEGInterp')));

% ---------- PROMPTS
% Merging and interpolation decision
answer = inputdlg({'Do you want to merge datasets ?','Do you already have averaging parameters ?',...
    'Do you want to save average referenced ERPs','Do you want to save ERPs referenced to Cz',['Do you want to save non-averaged epoched data ?'...
    newline '(Required for time-frequency analyses)']},...
    'Settings',1,{'y','n','y','y','n'});

merge_ans = upper(answer{1});
averaging_ans = upper(answer{2});
save_avgref = upper(answer{3});
save_refCz  = upper(answer{4});
save_nonavg = upper(answer{5});


% Suffixes and parameters
PromptSetup = {'Enter the suffix of your epoched data:','Enter the suffixes of your average referenced ERPs',...
    'Enter the suffixes of your ERPs referenced to Cz','Enter the sampling rate:','Artefact Rejection threshold (If empty, not done)'};
PromptValues = {'epoched','avgref','refCz','1024','80'};

% Based on his will, the parameters change
if save_avgref ~= 'Y'
    PromptSetup(2) = [];
    PromptValues(2) = [];    
end
if save_refCz ~= 'Y'
    PromptSetup(end-2) = [];
    PromptValues(end-2) = [];
end

% Displaying the parameters
PromptInputs = inputdlg(PromptSetup,'Inputs to prepare ERPs',1,PromptValues);

% Saving the values
extension = strcat(PromptInputs{1},'.set');
if save_avgref == 'Y'
    suffix_avr = PromptInputs{2};
end
if save_refCz == 'Y'
    suffix_Cz = PromptInputs{end-2};
end
sr = str2double(PromptInputs{end-1});
thr_uV = str2double(PromptInputs{end});


% Path of most upper folder containing epoched data
root_folder = uigetdir('title',...
    'Enter the path of your most upper folder containing all your processed data');
cd(root_folder)
FileList = dir(['**/*' extension]);

% Sorting FileList by natural order
[~,sort_I] = natsort({FileList.name});
FileList = FileList(sort_I);

% Further uigetdir will have now the right path
load_folder = strsplit(root_folder,'\');
load_folder = strrep(join(load_folder(1:end-1)),' ','\');
load_folder = load_folder{:};

% Path of the folder where to save .eph
save_folder = uigetdir(load_folder,...
    'Enter the path of the folder where you want to save your .eph');


%% Specific folder or not ?
PromptAnalyses = questdlg('Would you like to perform the analysis on all your data or on specific folders ?', ...
	'Selection of analysis','All data','Specific folders','All data');

% If user decides to restrict analysis to specified folders
if strcmp(PromptAnalyses,'Specific folders')

    % Retrieve names from the FileList structure
    AllNames=unique({FileList.folder});

    % Removing the consistant path
    to_display = cellfun(@(x) x(length(root_folder)+2:end),AllNames,'UniformOutput',false);

    % Sorting based on the number
    to_display = natsort(to_display);   

    % Matrix to integrate in the following uitable
    to_display = [to_display', repmat({false},[size(AllNames,2) 1])];

     % Select folders on which to apply analyses
    f = figure('Position', [600 300 400 400]);
    p=uitable('Parent', f,'Data',to_display,'ColumnEdit',[false true],'ColumnName',...
        {'Folders', 'Perform ERP ?'},'CellEditCallBack','ERPList = get(gco,''Data'');');
    uicontrol('Style', 'text', 'Position', [20 325 200 50], 'String',...
            {'Folder selection for filtering/epoching','Click on the box of the participants folder you want to perform analyses on'});
    % Wait for t to close until running the rest of the script
    waitfor(p)

    % Stores the files selected for analysis
    ToAnalyse = find(cell2mat(ERPList(:,2)));
    Name_toAnalyse = ERPList(ToAnalyse,1);

    % Recreates a new FileList structure based on selected folders
    FileList = FileList(ismember({FileList.folder},strcat(root_folder,'\',Name_toAnalyse)));
end


%% Averaging parameters

if upper(averaging_ans) ~= "Y"
    %% Opening the previous marker parameters to help them remind their trigger names
    % Open the parameters.mat
    uiopen([load_folder '\Marker_Parameters.mat'])

    % If there was epoching parameters, display them
    if exist('Epoch_Parameters','var')

        % Which condition has the most triggers
        [nrows,~] = cellfun(@size,Epoch_Parameters.newtrigg);
        Lines = max(nrows);

        % if empty condition list, add an empty cell        
        if isempty(Epoch_Parameters.CondList)
            Epoch_Parameters.CondList = {' '};
        end
        
        % Creating empty cells
        DisplayCells = cell([Lines length(Epoch_Parameters.CondList')]);
        
        % Filling the empty cells with the triggers' name
        for f = 1:length(Epoch_Parameters.CondList)
            for g = 1:length(Epoch_Parameters.newtrigg{f})
                TempMarkers = Epoch_Parameters.newtrigg{f}';
                DisplayCells(g,f) = TempMarkers(g);
            end
        end

        % Displaying the triggers' name of each condition
        figure('Position', [100 400 380 420]);
        tt = uitable('Data',DisplayCells,'ColumnName',Epoch_Parameters.CondList);
        uicontrol('Style', 'text', 'Position', [50 330 200 65], 'String',...
            {'REMINDER','This is the triggers name of your epoched dataset'});

    end

    cd(root_folder)

    %% Creating a table to enter the conditions
    
    text = {'Enter the name of your conditions as they appear on the files'' or folders'' name.'};
   
    figure('Position', [500 400 380 420]);
    t = uitable('Data',[{'Cond1'};{'Cond2'};repmat({''},[8 1])],...
        'ColumnEditable',true,'ColumnName',{'Condition name'},'CellEditCallBack','CondList = get(gco,''Data'');');
    uicontrol('Style', 'text', 'Position', [20 320 210 80], 'String',text);

    % Wait for t to close until running the rest of the script
    waitfor(t)

    % Removing empty cells and everything uppercase
    CondList = CondList(~cellfun('isempty',CondList));
    CondList = upper(CondList);       

    %% Asking for each condition which triggers to average

    cond = 0;
    continue_loop = 1;

    while continue_loop == 1   

        cond = cond+1;
        
        % If the CondList is not empty, take the name of the cond
        cond_name = [];
        if ~isempty(CondList)
            cond_name = CondList{cond};         
        end
        
        to_display = [[{'Trigger 1';'Trigger 2'};repmat({''},[18 1])],repmat({''},[20 9])];
        colname = strcat( repmat({'ERP '},[1 10]), cellfun(@num2str,num2cell(1:10),'UniformOutput',false) );
        
        % Table to enter the trigger to average
        figure('Position', [500 400 380 420]);
        t = uitable('Data',to_display,'ColumnEditable',true(1,10),'ColumnName',colname,...
            'CellEditCallBack','ERPtriggList = get(gco,''Data'');');
        uicontrol('Style', 'text', 'Position', [50 330 200 65], 'String',...
            {cond_name,'Enter the exact name of the triggers you want to average together in one column'});

        % Wait for t to close until running the rest of the script
        waitfor(t)

        % Removing empty cell rows and columns
        ERPtriggList(all(cellfun('isempty',ERPtriggList),2),:) = [];
        ERPtriggList(:,(all(cellfun('isempty',ERPtriggList),1))) = [];

        % Appending the cell array
        allERPtriggList{cond} = ERPtriggList;

        if ge(cond,size(CondList,1))
           continue_loop = 0; 
        end
    end
    
    %% Saving the averaging parameters into a structure
    
    Averaging_parameters.CondList = CondList;
    Averaging_parameters.allERPtriggList = allERPtriggList;
    uisave('Averaging_parameters',[load_folder '\Averaging_parameters.mat'])

%% If already set up parameters
else
    % Open the parameters.mat
    uiopen([load_folder '\Averaging_parameters.mat'])

    CondList = Averaging_parameters.CondList;
    allERPtriggList = Averaging_parameters.allERPtriggList;
end


%% Bad Channels Table

SbjList = {}; InterpSbj = 1;
% 
% if interpolation_ans == 'Y'
%     
    % Create a variable with all the channels information
rowname = [{'Fp1(1)'},{'AF7(2)'},{'AF3(3)'},{'F1(4)'},{'F3(5)'},{'F5(6)'},{'F7(7)'},...
    {'FT7(8)'},{'FC5(9)'},{'FC3(10)'},{'FC1(11)'},{'C1(12)'},{'C3(13)'},{'C5(14)'},...
    {'T7(15)'},{'TP7(16)'},{'CP5(17 )'},{'CP3(18)'},{'CP1(19)'},{'P1(20)'},{'P3(21)'},...
    {'P5(22)'},{'P7(23)'},{'P9(24)'},{'PO7(25)'},{'PO3(26)'},{'O1(27)'},{'Iz(28)'},...
    {'Oz(29)'},{'POz(30)'},{'Pz(31)'},{'CPz(32)'},{'Fpz(33)'},{'Fp2(34)'},{'AF8(35)'},...
    {'AF4(36)'},{'AFz(37)'},{'Fz(38)'},{'F2(39)'},{'F4(40)'},{'F6(41)'},{'F8(42)'},...
    {'FT8(43)'},{'FC6(44)'},{'FC4(45)'},{'FC2(46)'},{'FCz(47)'},{'Cz(48)'},{'C2(49)'},{'C4(50)'},...
    {'C6(51)'},{'T8(52)'},{'TP8(53)'},{'CP6(54)'},{'CP4(55)'},{'CP2(56)'},{'P2(57)'},...
    {'P4(58)'},{'P6(59)'},{'P8(60)'},{'P10(61)'},{'PO8(62)'},{'PO4(63)'},{'O2(64)'}];
% 
%     % Removing the '(n)' after the chan label 
%     Index = strfind(rowname,'(');
%     rowname_nonumb = cellfun(@(x,idx) x(1:idx-1),rowname,Index,'UniformOutput',false);
% 
%         
%     if interpolation_param ~= 'Y'
%                             
%         %% Manually enter the channels
%         AllNames = unique({FileList.folder});
%         to_display={};
% 
%         % Removing the consistant path
%         for x = 1:length(AllNames)
%             temp = AllNames{x};
%             to_display{x} = temp(length(root_folder)+2:end);
%         end
% 
%         to_display = [natsort(to_display)', repmat({false},[size(AllNames,2) 1])];
% 
%         % Select folders on which to specify Bad Channels from
%         f = figure('Position', [500 300 380 420]);
%         p=uitable('Parent', f,'Data',to_display,'ColumnEdit',[false true],'ColumnName',...
%             {'Folders', 'Bad Channels ?'},'CellEditCallBack','SbjList_I = get(gco,''Data'');');
%         uicontrol('Style', 'text', 'Position', [20 325 200 50], 'String',...
%                 {'Folder selection for Bad Channels.','Click on the box of the participants folder you want to specify bad channels from.'});
% 
%         % Wait for p to close until running the rest of the script
%         waitfor(p)
% 
%         % Retrieve the selected folder  
%         SbjList = SbjList_I(cell2mat(SbjList_I(:,2)),1);        
% 
%         %% Asking the bad channels for each subject
%         if ~isempty(SbjList)            
% 
%             figure('Position', [500 300 380 420]);
%             t = uitable('Data',repmat({false},[63 length(SbjList)]),'ColumnEditable',true(1,length(SbjList)),...
%                 'Rowname',rowname,'ColumnName',SbjList,'CellEditCallBack','BadChannels = get(gco,''Data'');');
%             uicontrol('Style', 'text', 'Position', [20 325 200 50], 'String',{'Enter the bad channels','Cz does not appear as it is taken as reference.'});
% 
%             % Wait for t to close until running the rest of the script
%             waitfor(t)
% 
%             % Changing the Bad Channels logical arrays into the corresponding row names
%             for x = 1:length(SbjList)       
%                 BadChanLabels_log{x} = rowname([BadChannels{:,x}]);  
%                 BadChanLabels{x} = rowname_nonumb([BadChannels{:,x}]);               
%             end
% 
%             %% saving the epoching parameters into a structure
% 
%             BadChannels_Parameters.Sbj = SbjList;
%             BadChannels_Parameters.Channels = BadChanLabels;
% 
%             uisave('BadChannels_Parameters',[load_folder '\BadChannels_Parameters.mat'])
%         end
%         
%     % If already setup parameters
%     else        
%         % Choose the file
%         [f_BadChannels,p_BadChannels] = uigetfile({'*.*';'*.csv';'*.mat'},...
%             'Select the .csv or .mat file containing the Bad Channels',load_folder);
%         name_f_BadChannels = [p_BadChannels,f_BadChannels];
%         extension_param = split(f_BadChannels,'.');
%         extension_param = extension_param{end};
%         
%         %% Read csv Bad channels file
%         % If a folder with interp parameters exist
%         switch extension_param
%             case 'csv'            
%                 % Load it and convert it to cells
%                 T_BadChannels = readtable([p_BadChannels f_BadChannels],'Delimiter',';','HeaderLines',2);
%                 T_BadChannels = table2cell(T_BadChannels);
% 
%                 % Remove empty col
%                 idx = all(cellfun(@isempty,T_BadChannels),1);
%                 T_BadChannels(:,idx) = [];
% 
%                 % If electrodes labels are letters convert them to numbers
%                 if ischar(T_BadChannels{1,2})
%                     NumT_BadChannels = [T_BadChannels(:,1) repmat({NaN},size(T_BadChannels(:,2:end)))];
%                     for m=1:size(T_BadChannels(:,2:end),1)
%                         for n=1:size(T_BadChannels(:,2:end),2)
%                             if ~isempty(T_BadChannels{m,n+1})
%                                 NumT_BadChannels{m,n+1} = find(ismember(rowname_nonumb,T_BadChannels(m,n+1)));
%                             end
%                         end
%                     end
%                     T_BadChannels = NumT_BadChannels;
%                 end
%                 
%                 % Remove empty rows
%                 idx = all(cellfun(@isnan,T_BadChannels(:,2:end)),2);
%                 T_BadChannels(idx,:) = [];
% 
%                 % Variable attribution to SbjList
%                 SbjList = T_BadChannels(:,1);
% 
%                 % Variable attribution to BadChanLabels
%                 for chan = 1:length(SbjList) % for each non-empty row
%                     temp = [T_BadChannels{chan,2:end}]; % take the values
%                     temp = temp(~isnan(temp)); % remove the nan
%                     BadChanLabels_log{chan} = rowname(temp); % replace them by labels
%                     BadChanLabels{chan} = rowname_nonumb(temp);               
%                 end    
%                 
%             case 'mat'
%                 % Open the parameters.mat
%                 open(name_f_BadChannels)
%                 SbjList = BadChannels_Parameters.Sbj;
%                 BadChanLabels = BadChannels_Parameters.Channels;
%         end
%     end
% end

%% eeglab

eeglab
close all

% set double-precision parameter
pop_editoptions('option_single', 0);
time_start = datestr(now);

% Supercomputer slash inversion and remove spaces
% SbjList = strrep(SbjList,'/','\');
% SbjList = deblank(SbjList);

%% For each file and condition, we load and merge datasets

% List of unique subfolders
allFolderName = unique({FileList.folder});

% If you want to merge
if merge_ans == "Y"        
    % Then your loop is the size of all the unique subfolders
    sbj_high = length(allFolderName);
else
    % If not, your loop is the size of all the different files
    sbj_high = length(FileList);
end

% Creating a table containing information about our future ERPs
NTrials_T = table({},[],[],[],[],[],[]);
NTrials_T.Properties.VariableNames = {'File_Name','N_Trials_before',['N_Rejected_',num2str(thr_uV),'uV'],['p_Rejected_',num2str(thr_uV),'uV'],...
    'N_Rejected_jump30uV','p_Rejected_jump30uV','N_Trials_in_ERP'}; %,'N_Trials_after_resampling'
t_count = 0;

% Waiting bar ! The epitome of UI !
h = waitbar(0,{'Loading' , ['Progress: ' '0 /' num2str(sbj_high)]});

for sbj = 1:sbj_high

    %% Setting up how the datasets need to be merged and averaged
    
    % Clearing the eeglab structures
    clear EEG
    ALLEEG = [];
    
    % SubPath
    SubFPath = FileList(sbj).folder(length(root_folder)+1:end);
    
    % If there is a merge
    if merge_ans == "Y"
        
        % Test for recursive condition name
        for test_cond = 1:size(CondList,1)   
            error_condname(test_cond) = sum(contains(CondList,CondList{test_cond}));
        end
        
        % If it is the case, produce an error
        if sum(error_condname > 1) == 1
            errordlg(['The following condition''s name is recursive with another condition: ' CondList{error_condname > 1}], ...
                'MERGING NOT POSSIBLE')
            error(['ERROR: Merging is not possible in the case of recursive condition''s name. ',...
                'It means that the listed condition has its name inside at least one other condition. ',...
                'To solve this you can write ''_XXX'' instead of ''XXX'' in the table.'])
        elseif sum(error_condname > 1) > 1
            errordlg(['The following conditions'' names are recursive with another condition: ' sprintf('\n %s', CondList{error_condname > 1})], ...
                'MERGING NOT POSSIBLE')
            error(['ERROR: Merging is not possible in the case of recursive conditions'' names. ',...
                'It means that the listed conditions have their names inside at least one other condition. ',...
                'To solve this you can write ''_XXX'' instead of ''XXX'' in the table.']) 
        end

        % Finding the file name for each folder
        FolderName = allFolderName{sbj};
        I_file = find(strcmp({FileList.folder},FolderName));
        same_session = {FileList(I_file).name};
     
        % If conditions were specified
        if ~isempty(CondList)
            
            % Counter
            sbj_count = 0;
            
            % Taking the files of a same session
            newFileList = FileList(I_file);
            
            % For each conditions
            for cond = 1:length(CondList)
                                
                % Updating the waitbar
                name_h = FolderName(length(root_folder)+2:end);
                name_h(name_h == '\') = '/';
                waitbar(sbj/sbj_high,h,{['Merging: ' name_h '   ' 'Condition: ' CondList{cond}] , ['Progress: ' num2str(sbj) '/' num2str(sbj_high)]})
               
                % Clearing the eeglab structures
                clear EEG
                ALLEEG = [];
                
                % Find which file is associated to the first condition
                I_cond = find(contains(upper(same_session),CondList{cond}));
                same_cond = {newFileList(I_cond).name};
                
                % Load and merge the file of the same condition if more
                % than two file for this condition
                if ~isempty(same_cond)
                    
                    % counter for each sbj with each condition
                    sbj_count = sbj_count +1;
                    
                    % Load the dataset
                    EEG = pop_loadset('filename',same_cond,'filepath',FolderName);
                    
                    % If more than two files for one condition in the same 
                    % condition, merge them together
                    if length(same_cond) > 1
                        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'study',0); 
                        ALLEEG = eeg_checkset(ALLEEG, 'makeur'); % making sure event and urevent are identical
                        EEG = pop_mergeset( ALLEEG, 1:length(ALLEEG));
                        EEG.cond_name = CondList{cond};
                        
                        % Everything in one variable
                        allEEG{sbj_count} = EEG;
                        
                    % If only one file for this condition on this session,
                    % just take it as it is
                    else
                        EEG.cond_name = CondList{cond};
                        allEEG{sbj_count} = EEG;
                    end
                end
            end
            
        % If conditions were not specified
        else
            % Updating the waitbar
            name_h = FolderName(length(root_folder)+2:end);
            name_h(name_h == '\') = '/';
            waitbar(sbj/sbj_high,h,{['Merging: ' name_h] , ['Progress: ' num2str(sbj) '/' num2str(sbj_high)]})
        
            % Merging the whole folder
            EEG = pop_loadset('filename',same_session,'filepath',FolderName);
            [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'study',0); 
            ALLEEG = eeg_checkset(ALLEEG, 'makeur'); % making sure event and urevent are identical 
            EEG = pop_mergeset( ALLEEG, 1:length(ALLEEG), 0);
            
            % Everything in one variable
            allEEG = {EEG};
        end
        
    % If there is no merge    
    else        
        % Updating the waitbar
        name_h = FileList(sbj).name(1:end-length(extension));
        name_h(name_h == '_') = ' ';
        waitbar(sbj/sbj_high,h,{['Loading: ' name_h],['Progress: ' num2str(sbj) '/' num2str(sbj_high)]})
        
        % Loading each file
        EEG = pop_loadset('filename',FileList(sbj).name,'filepath',FileList(sbj).folder); % may be redundant with pop_newset
        
        % If Conditions are specified, 
        if ~isempty(CondList)
            
            % Matching each condition string pattern with the one in the file name + subpath:
            % Preallocating array
            Condname_i = zeros([size(CondList,1) 1]);

            % For each condition, see if we find it in the name or subpath
            for i = 1:size(CondList,1)
                Condname_i(i) = contains(upper([SubFPath '\' FileList(sbj).name]),CondList{i});
            end

            % In case of multiple positives, take the lengthier condition name
            [~,I_cond] = max(cellfun('length',CondList) .* Condname_i);
            
            % If there is a detected condition
            if nnz(I_cond)
                % Adding the condition name
                EEG.cond_name = CondList{I_cond};               
                
                % Catching the EEG structure
                allEEG = {EEG};
            end
            
        % If there is no merge and no condition, just take it
        else                                
            allEEG = {EEG};
        end
    end

    %% For each loaded/merged dataset
    
    % It's waitbar time !
    waitbar(sbj/sbj_high,h,{['Computing ERP: ' name_h],['Progress: ' num2str(sbj) '/' num2str(sbj_high)]})

    for i = 1:length(allEEG)

        % Parameters
        EEG = allEEG{i};
        name_session = EEG.filepath(length(root_folder)+2:end);

        %% Detecting the condition

        if ~isempty(CondList)        
            I_cond = find(strcmp(EEG.cond_name,CondList));
        else
            I_cond = 1;
        end
        
        %% Bad channels if the subject is in SbjList

%         to_inspect = 1:EEG.nbchan;
        Interpolation = 0;
        
%         if contains(name_session,SbjList) && ~isempty(SbjList)       
%             
%             % Need to interpolate later ?
%             Interpolation = 1;
% 
%             % Bad Channels associated to this subject
%             I_sbj = find(strcmp(name_session,SbjList));
%             EEG.BadChan = BadChanLabels{I_sbj};
%             to_ignore = [];
% 
%             % Transforming the channels name in eeglab chan num
%             for x = 1:length(EEG.BadChan)
%                 to_ignore(x) = find(ismember(upper({EEG.chanlocs.labels}),upper(EEG.BadChan(x))));
%             end
% 
%             to_inspect(to_ignore) = [];
%         end

        if isfield(EEG,'BadChans')    
            
            % Need to interpolate later ?
            Interpolation = 1;

            % Bad Channels associated to this subject
            to_interp = EEG.BadChans.InterpChans;
                     
            % Store rejected/interp channels for the log
            BadChanLabels_log{InterpSbj} = rowname(to_interp);
            InterpSbj = InterpSbj + 1;

            % Channels on which to apply 80mv threshold
%             to_inspect(to_interp) = [];
            
            % Store list of subjects with interpolation
            FileName = FileList(sbj).name(1:end-length(extension));
            if strcmp(FileName(end),'_') % removing ending character
                SbjList=[SbjList {FileName(1:end-1)}];
            else
                SbjList=[SbjList {FileName}];
            end
            
        end
       
        %% Deleting epochs based on allERPtriggList
        
        % Clearing variables
        clear allERPs types unique_types keptevents
       
        % Event types to average for this condition
        types = allERPtriggList{I_cond};

        % Event types existing inside this EEG structure
        unique_types = unique({EEG.event.type});

        % counter
        counter_ERP = 0; event_epochs = [];

        % If types isn't empty
        if ~isempty(types)

            % Removing the event type that doesn't appear in the EEG structure
            for nrow = 1:size(types,1)
                for ncol = 1:size(types,2)
                   if ~ismember(types{nrow,ncol},unique_types)
                       types{nrow,ncol} = [];
                   end
                end
            end

            % For each types' column
            for n = 1:size(types,2)      

                % Removing the empty line for this column
                corr_types = types(:,n);
                corr_types =  corr_types(~cellfun('isempty',corr_types));

                % If there are still types after that, delete everything except them
                if ~isempty(corr_types)

                    % Appending the counter
                    counter_ERP = counter_ERP +1;

                    % Creating our new EEG structure containing only the selected trials
                    [allERPs{counter_ERP}, event_TEMP] = pop_selectevent(EEG,'type',corr_types,'deleteevents','on');
                    
                    % Find epochs corresponding to each event
                    event_epochs{counter_ERP} = {EEG.event(event_TEMP).epoch}; 
                    
                    % If there are more than one, join them in a string
                    if length(corr_types) > 1
                        allERPs{counter_ERP}.keptevents = cell2mat(join(corr_types,'_'));
                        keptevents{counter_ERP} = cell2mat(join(corr_types,'_'));
                    else
                        allERPs{counter_ERP}.keptevents = cell2mat(corr_types);
                        keptevents{counter_ERP} = cell2mat(corr_types);
                    end
                end
            end

        % If no specified event types to average, just take everything
        else
            allERPs = {EEG};
            keptevents = {'All Triggers'};
        end


        %% Preparation of each data segmentation to average afterwards
        
        % Variables to store in our table afterwards
        n_trials = zeros([1 length(allERPs)]);
        Rem_80uV_N = zeros([1 length(allERPs)]);
        Rem_80uV_p = zeros([1 length(allERPs)]);
        Jump_30uV_N = zeros([1 length(allERPs)]);
        Jump_30uV_p = zeros([1 length(allERPs)]);
        NEpochs = zeros([1 length(allERPs)]);
        
        for x = 1:length(allERPs)
            
            EEG = allERPs{x};
                                      
            % Only keeping the select events in the Badchannels data
            Current_event_epochs = sort(cell2mat(event_epochs{x}));
            if isfield(EEG,'BadChans')
                EEG.BadChans.data = EEG.BadChans.data(:,:,Current_event_epochs);
            end
            % total event before everything is rejected [to store]
            n_trials(x) = size(EEG.data,3); 
            
            %% Interpolation
            if Interpolation
                
                % Reintroduce the bad channels data 
                Temp = zeros(EEG.BadChans.nbchan,size(EEG.data,2),size(EEG.data,3)); PosGood = 1; PosBad = 1; 
                for m=1:EEG.BadChans.nbchan
                    if ~ismember(m,EEG.BadChans.InterpChans) 
                       Temp(m,:,:) = EEG.data(PosGood,:,:); PosGood = PosGood + 1;
                    else
                       % Restricting channel data length since EEG.data
                       % size might have changed with artifact rejection
                        Temp(m,:,:) = EEG.BadChans.data(PosBad,:,:);PosBad = PosBad + 1;

                       % Filling in the missing channel data with zeros (Is this correct?!)
                       %Temp(m,:,:) = zeros(1,size(EEG.data,2),size(EEG.data,3));PosBad = PosBad + 1;
                    end
                end
                
                % Adjust the EEG structure
                EEG.data = Temp; EEG.chanlocs = EEG.BadChans.chanlocs;
                EEG.nbchan = EEG.BadChans.nbchan;
                EEG = eeg_checkset(EEG);
                
                % Multiquadratics (BEST ONE SO FAR)
                EEG.data = EEGinterp('MQ',0.05,EEG,to_interp);
            end
            
            %%   
            if ~isnan(thr_uV)
                
                %% Artefact Rejection
                [EEG,Index] = pop_eegthresh(EEG,1,1:EEG.nbchan,-thr_uV,thr_uV,min(EEG.times)/1000,max(EEG.times)/1000,0,1);
                EEG.rej_trials = Index;

                % How many trials are removed in percent [to store]
                Rem_80uV_N(x) = length(Index);
                Rem_80uV_p(x) = 100*length(Index)/n_trials(x);
                

                %% Removing every epoch that have at least one jump of 30uV from one TF to the second

                % Taking the number of TF
                Id = size(EEG.data,2);

                % If this number is odd
                if mod(Id,2)
                    % Substracting each neighboring element starting from the first
                    Substract1 = abs( EEG.data(:,1:2:Id-1,:) - EEG.data(:,2:2:Id,:) );
                % If this number is even
                else
                    % Same thing but with an even size, otherwise matrices don't match
                    Substract1 = abs( EEG.data(:,1:2:Id,:) - EEG.data(:,2:2:Id,:) );
                end

                % Substracting each neighboring element starting from the second
                Substract2 = abs( EEG.data(:,2:2:Id-1,:) - EEG.data(:,3:2:Id,:) );

                % For each dimmension, is there at least one jump of 30uV ?
                to_remove30 = find( any(any(Substract1 > 30,1)) + any(any(Substract2 > 30,1)) );

                % How many epochs jumped [to store]
                Jump_30uV_N(x) = length(to_remove30);
                Jump_30uV_p(x) = 100*length(to_remove30)/size(EEG.data,3);            

                % Removing the epochs that jumped
                if ~isempty(to_remove30)
                    EEG = pop_selectevent(EEG,'epoch',to_remove30,'invertepochs','on');
                end
                
            end

            %% Putting the cleaned EEG structure inside allERPs again
            NEpochs(x) = size(EEG.data,3); % [to store]
            allERPs{x} = EEG;

        end

        % Computing the minimum of trials between ERP of a same condition,
        % after artefact and jump rejection
%         min_sample = min(NEpochs);

        %% Creating the ERP
        for n = 1:length(allERPs)
            
            % Taking the structure
            EEG = allERPs{n};

            % Duplicating the EEG structure to keep a save file
            EEG_epoched = EEG;
            
            %% Averaging, Interpolation and Re-referencing
            
            % Averaging the data on the third dim
            EEG.data = mean(EEG.data,3);
                        
            % Average referencing Cz
            EEG_avr = average_ref(EEG,EEG.chaninfo.nodatchans);
            
            % Using the transpose to match the .eph format
            ERP_Cz = EEG.data';
            Cz = zeros([size(ERP_Cz,1) 1]);
            ERP_Cz = [ERP_Cz(:,1:47),Cz,ERP_Cz(:,48:63)];
            ERP_avr = EEG_avr.data';
            
            %% Save ERP in .eph format

            % Name by default
            NewPath = save_folder;

            % If a condition was registered, creating a subfolder
            if isfield(allERPs{n},'cond_name')
                NewPath = [NewPath '\' allERPs{n}.cond_name];    
            end

            % If a events were specified, creating a subfolder
            if isfield(allERPs{n},'keptevents')
                NewPath = [NewPath '\' allERPs{n}.keptevents]; 
            end

            % Creating the new save folder
            if ~exist(NewPath, 'dir')
                mkdir(NewPath);
            end

            % If there is no merge, the file name is kept without the extension
            if upper(merge_ans) ~= "Y"

                % Find the extension and remove it
                I_erp = strfind(allERPs{n}.filename,extension);
                name = allERPs{n}.filename(1:I_erp-1);

                % If it ends with an underscore, remove it
                if name(end) == '_'
                    name(end) = [];
                end


            % If there is a merge, the file name becomes the previous subfolder path
            else
                SubPath = allERPs{n}.filepath(length(root_folder)+2:end);
                SubPath(SubPath == '\') = '_';        
                name = SubPath;
            end

            % saving the ERPs
            if save_avgref == 'Y'
                NewName_avr = [NewPath '\' name '_' suffix_avr '.eph'];
                saveeph(NewName_avr,ERP_avr,sr)
            end
            if save_refCz == 'Y'
                NewName_Cz = [NewPath '\' name '_' suffix_Cz '.eph'];
                saveeph(NewName_Cz,ERP_Cz,sr)
            end
            if save_nonavg == 'Y'
                % saving the epoched EEG file
                NewName_nonavg = [NewPath '\' name '_nonavg.set'];
                pop_saveset(EEG_epoched,NewName_nonavg)
            end
            % As a security, if nothing is asked to be saved, save the
            % averaged ref ERPs nonetheless
            if save_avgref ~= 'Y' && save_refCz ~= 'Y' && save_nonavg ~= 'Y'
                NewName_avr = [NewPath '\' name '_avgref.eph'];
                saveeph(NewName_avr,ERP_avr,sr)
            end

            
            % Saving the number of trials after each step into the table
            t_count = t_count +1; % counter for the lines
            name_T = [NewPath '\' name];     % creating a specific name for the table
            name_T(1:length(save_folder)) = []; % erasing the root's path
            NTrials_T(t_count,1) = {name_T}; % file name
            NTrials_T(t_count,2) = {n_trials(n)};
            NTrials_T(t_count,3) = {Rem_80uV_N(n)};
            NTrials_T(t_count,4) = {Rem_80uV_p(n)};
            NTrials_T(t_count,5) = {Jump_30uV_N(n)};
            NTrials_T(t_count,6) = {Jump_30uV_p(n)};
            NTrials_T(t_count,7) = {NEpochs(n)};
%             NTrials_T(t_count,8) = {min_sample};

                                    
        end    
    end
end

% Waitbar updating
waitbar(1,h,{'Done !' , ['Progress: ' num2str(sbj_high) ' /' num2str(sbj_high)]});
time_end = datestr(now);

% Sorting the table by natural order
[~,I] = natsort(NTrials_T.File_Name);
NTrials_T = NTrials_T(I,:);

% Name of exported table file
date_name = datestr(now,'dd-mm-yy_HHMM');
name_table_xlsx = [save_folder '\Ntrials_' date_name '.xlsx'];

% Fixed the error when exporting in xlsx format! 
writetable(NTrials_T,name_table_xlsx)

%% Log

fid = fopen([save_folder '\log_' date_name '.txt'],'w');

% date, starting time, finished time, number of analyzed files
fprintf(fid,'%s\t%s\r\n',['Start : ',time_start],['End: ',time_end]);
fprintf(fid,'%s',[num2str(numel(FileList)) ' files analyzed']);


% Merging condition
fprintf(fid,'\r\n\r\n%s\r\n','------ Merging parameters ------');
if merge_ans == 'Y' && ~isempty(CondList)
    fprintf(fid,'%s\r\n','The files in each subfolder were merged together based on the following condition(s): ');
    fprintf(fid,'\t%s\r\n', CondList{:}); 
elseif merge_ans == 'Y' && isempty(CondList)
    fprintf(fid,'%s\r\n','The files in each subfolder were merged together');   
elseif merge_ans ~= 'Y'
    fprintf(fid,'%s\r\n','No merging was done: all files were loaded independently');
end

% Data cleaning
fprintf(fid,'\r\n%s\r\n','------ Data cleaning ------');
if ~isnan(thr_uV)
    fprintf(fid,'%s\r\n',['A threshold of ' num2str(thr_uV) 'uV was used to detect artefact']);
    fprintf(fid,'%s\r\n','Epochs presenting a jump of at least 30uV from one data point to the other were rejected');
else
    fprintf(fid,'%s','No artefact rejection was computed');
end

% Averaging conditions
fprintf(fid,'\r\n\r\n%s\r\n','------ Triggers selection ------');
if ~isempty(CondList)
    
    for cond = 1:length(CondList)
        fprintf(fid,'%s\r\n',['For the condition ' CondList{cond} ' the following triggers were kept for the ERPs:']);
        
        for trigg = 1:size(allERPtriggList{cond},2)
            nb = length(allERPtriggList{cond}(:,trigg));
            fprintf(fid,'\t%s',[num2str(trigg) ') ']);
            fprintf(fid,'%s', allERPtriggList{cond}{1,trigg});
            fprintf(fid, repmat(' + %s ',[1 nb-1]) , allERPtriggList{cond}{2:end,trigg});
            fprintf(fid,'\r\n');
        end       
    end
else
    for trigg = 1:size(allERPtriggList{1},2)
        nb = length(allERPtriggList{1}(:,trigg));
        fprintf(fid,'\t%s',[num2str(trigg) ') ']);
        fprintf(fid,'%s', allERPtriggList{1}{1,trigg});
        fprintf(fid, repmat(' + %s ',[1 nb-1]) , allERPtriggList{1}{2:end,trigg});
        fprintf(fid,'\r\n');
    end   
end

% Interpolation
fprintf(fid,'\r\n%s\r\n','------ Interpolation parameters ------');
if exist('BadChanLabels_log','var')
    fprintf(fid,'%s\r\n',['Bad Channels were selected for ' num2str(length(SbjList)) ' sessions:'] );
    for sbj = 1:length(SbjList)
       fprintf(fid,'%s - ',SbjList{sbj}); 
       fprintf(fid,'%s ',BadChanLabels_log{sbj}{:});
       fprintf(fid,'\r\n');
    end
    fprintf(fid,'\r\n%s\r\n','Selected bad channels are interpolated before artefact rejection. Because we are working with Cz as the reference, this channel is never interpolated.');
else
    fprintf(fid,'%s\r\n','No interpolation was computed');    
end

% Suffixes
fprintf(fid,'\r\n%s\r\n','------ Saved files ------');
 fprintf(fid,'%s\r\n',['All files were saved with a sampling rate of ' num2str(sr) 'Hz']);
if save_avgref == 'Y'
    fprintf(fid,'%s\r\n',['Averaged referenced ERPs were saved with the suffix ''' suffix_avr '''']);
end
if save_refCz == 'Y'
    fprintf(fid,'%s\r\n',['ERPs referenced to Cz were saved with the suffix ''' suffix_Cz '''']);
end
if save_nonavg == 'Y'
    fprintf(fid,'%s\r\n','Non-averaged epoched datasets were saved with the suffix ''nonavg''');
end
if save_avgref ~= 'Y' && save_refCz ~= 'Y' && save_nonavg ~= 'Y'
    fprintf(fid,'%s\r\n','No data were asked to be saved, so averaged referenced ERPs were still saved with the suffix ''avgref'' as a security nonetheless');
end

fclose(fid);

%% Warning if at least one file had 100% of rejected epoch

if any(Rem_80uV_p == 100)
    count100 = sum(Rem_80uV_p == 100);
    warndlg({strcat(num2str(count100),[" file(s) had 100% of rejected epoch !"]);...
        "On these file(s), the rejection step was ignored.";...
        "Check the Ntrials excel file."})
end

disp('done');
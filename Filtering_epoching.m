%% autoERP 1

%% Filtering, .mrk importation and epoching .bdf or .set
% This script will permit you to filter .bdf or .set data, import new
% markers based on .mrk files and epoching them based on set parameters.

% Each functionality is independant. Meaning you can for example only 
% import .mrk  without filtering and epoching, or only epoching without 
% filtering and importing .mrk.

% If you want to import new triggers based on .mrk, be sure that the .mrk
% files have the exact same name as your data file.

% The output dataset will have the same folder structure than your selected
% root folder. 

%% Authors

% Hugo Najberg (script, protocol)
% Corentin Wicht (script, protocol)


%% --------------------- PRESS F5 -------------------- %%
%% --------------------------------------------------- %%
clear variables; close all
%% ----------------- PARAMETERS ------------- %%

% getting path of the script location
p = matlab.desktop.editor.getActiveFilename;
I_p = strfind(p,'\');
p2 = p(1:I_p(end)-1);


% Path of all needed functions
% addpath(strcat(p2,'\Functions\bdfplugin'));
addpath(strcat(p2,'\Functions\Functions'));
addpath(strcat(p2,'\Functions\eeglab14_1_2b'));


% Ask what they want to do with their data (filtering / mrk importing / epoching)
answer = inputdlg({'Do you want to filter your data ? [Y/N]','Do you want to import .mrk ? [Y/N]',...
    'Do you want to epoch your data ? [Y/N]','Do you already have set up epoching parameters ? [Y/N]'},'Settings',1,{'Y','Y','Y','N'});
FILTER    = upper(answer{1});
ImportMRK = upper(answer{2});
Epoch     = upper(answer{3});
resume    = upper(answer{4});


% Parameters for Loading, filtering and epoching
PromptInstructions = {'Enter the suffix and extension of your data (.bdf or XXX.set):',...
    'Enter the  Suffixe of your new FILTERED dataset:',...
    'Lower edge of the frequency pass band (Hz):','Higher edge of the frequency pass band (Hz)',...
    'Enter the  Suffixe of your new EPOCHED dataset:',...
    'Enter the epoching interval (in ms)',...
    'Enter the sampling rate:', ...
    'How many channels do you work with ?',...
    'Would you add presentation triggers delay (in ms, optional) ?'};

PromptValues = {'.bdf','filtered','0.5','40','epoched','-100 700','1024','64',''};


% Optionnal algorithms decision
PromptAlgoInstruct= {['Would you like to use... [Y/N]' newline,...
    newline 'CleanLine (efficient filtering of sinusoidal noise)'],...
'ASR (interpolation of non-sinusoidal high-variance bursts )',...
'BLINKER (eye blink detection and rejection of epochs containing blinks)',...
'Baseline correction',...
'Enter the interval for baseline correction (in ms). Empty if whole epoch range.'};

PromptAlgoValues = {'Y','Y','Y','Y','-100 700'};
 

% If user doesn't want to filter, remove the associated lines
if FILTER ~= 'Y'
    PromptInstructions(2:4) = [];
    PromptValues(2:4) = [];
    PromptAlgoInstruct(1:2) = [];
    PromptAlgoValues(1:2) = [];
end

% If user doesn't want to epoch, remove the associated lines
if Epoch ~= 'Y'
    PromptInstructions(end-4:end-2) = [];
    PromptValues(end-4:end-2) = [];
    PromptAlgoInstruct(end-2:end) = [];
    PromptAlgoValues(end-2:end) = [];
end

% If user doesn't want to import mrk, remove the associated lines
if ImportMRK ~= 'Y'
    PromptInstructions(end) = [];
    PromptValues(end) = [];
end

% Displaying the final prompts
PromptInputs = inputdlg(PromptInstructions,'Preprocessing parameters',1,PromptValues);
PromptAlgoInputs = inputdlg(PromptAlgoInstruct,'Optionnal algorithms options',1,PromptAlgoValues); 

% Default value for a specific case
PromptRSA = 'No';

% Parameters to save from the prompts
extension = PromptInputs{1};
if FILTER == 'Y' % If filtering
    filtered_suffix = PromptInputs{2};
    low = str2double(PromptInputs{3});
    high = str2double(PromptInputs{4});
    bool_CleanLine = PromptAlgoInputs{1};
    bool_ASR = PromptAlgoInputs{2};
end

if Epoch == 'Y' % If epoching
    epoched_suffix = PromptInputs{end-4};
    interval = str2num(PromptInputs{end-3});
    sr = str2double(PromptInputs{end-2});
    % Conversion from ms to TimeFrames according to sampling rate
    intervalTF = round(interval*sr/1000);
    bool_conderror = 1;
    bool_Blinker = PromptAlgoInputs{end-2};
    bool_Basecorr = PromptAlgoInputs{end-1};
    interval_basecorr = str2num(PromptAlgoInputs{end});
end

% Converting the Error in ms for the log and TF for the structure
if ImportMRK == 'Y'
    PromptChanLoc = PromptInputs{end-1};
    Error_ms = str2num(PromptInputs{end});
    if isempty(Error_ms)
        Error_TF = 0;
        Error_ms = 0;
    else
        Error_TF = round(Error_ms / ((1/sr)*1000));
    end
else
    PromptChanLoc = PromptInputs{end};
end

% Channels location path
if strcmp(PromptChanLoc,'64')
    chanloc_path=(strcat(p2,'\ChanLocs\biosemi64.locs'));
    nbchan = 64;
    ref_chan = 48;
elseif strcmp(PromptChanLoc,'128')
    chanloc_path=(strcat(p2,'\ChanLocs\biosemi128.xyz'));
    nbchan = 128;
    ref_chan = 1;
end


% Path of your upper folder containing your data
root_folder = uigetdir('title',...
    'Choose the path of your most upper folder containing your RAW of Processed data.');
cd(root_folder)
FileList = dir(['**/*' extension]);

% Path of your .mrk files
if strcmp(ImportMRK,'Y')
    mrk_folder = uigetdir('title',...
        'Choose the path of your most upper folder containing your .mrk files');
end



% Path of the folder to save filtered and epoched .set
save_folder = uigetdir('title',...
    'Enter the path of the folder where you want to save your preprocessed files. You can create a new folder if needed.');

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
    f = figure('Position', [125 125 400 400]);
    p=uitable('Parent', f,'Data',to_display,'ColumnEdit',[false true],'ColumnName',...
        {'Folders', 'Perform filtering/epoching ?'},'CellEditCallBack','SbjList = get(gco,''Data'');');
    uicontrol('Style', 'text', 'Position', [20 325 200 50], 'String',...
            {'Folder selection for filtering/epoching','Click on the box of the participants folder you want to perform analyses on'});
    % Wait for t to close until running the rest of the script
    waitfor(p)

    % Stores the files on which to apply IC decomposition
    ToAnalyse=find(cell2mat(SbjList(:,2)));
    Name_toAnalyse = SbjList(ToAnalyse,1);

    % Recreates a new FileList structure based on selected folders
    FileList = FileList(find(ismember({FileList.folder},strcat(root_folder,'\',Name_toAnalyse))));
end

%% Condition and Marker Tables

% If there is an intended epoching
if Epoch == 'Y'
    % If we don't already have epoching parameters
    if resume ~= 'Y'

        % Default CondList
        CondList = {'GNG','NBACK'};

        % Creating a table that asks for the conditions you have
        figure('Position', [500 400 340 450])
        t = uitable('Data',{'GNG';'NBACK';'';'';'';'';'';'';'';'';'';'';'';'';''},...
            'ColumnEditable',true,'ColumnName',{'Condition name'},'CellEditCallBack','CondList = get(gco,''Data'');');
        uicontrol('Style', 'text', 'Position', [20 325 300 100], 'String',...
            {'Enter the code you use to differenciate your task.',...,
            ' ','Empty the cells if no task differenciation.','Close the windows when done.'});

        % Wait for t to close until running the rest of the script
        waitfor(t)

        % Removing empty cells and everything uppercase
        CondList = CondList(~cellfun('isempty',CondList));
        CondList = upper(CondList);

        %% Asking for each condition, the markers, new name if asked and to epoch

        cond = 0;
        continue_loop = 1;

    while continue_loop == 1   

        cond = cond+1;
        MarkerList = [];
        
        to_display = [repmat({''},[200 3]), repmat({false},[200 1])];

        cond_name = [];
        if ~isempty(CondList)
            cond_name = CondList{cond};   
            text_uiCond = {['1) Enter the marker IDs of the ' cond_name ' condition as they appear in the .mrk file'],...
                '2) Enter new names for your markers (optionnal)',...
                '3) Enter the stimulus duration (in ms) (leave empty if you do not want to reject epochs containing eye blinks)',...
                '4) Around which markers do you want to epoch ?', newline, ...
                'Let 1), 2) & 4) empty if you want to epoch around every trigger'};
        else
            text_uiCond = {'1) Enter the marker IDs as they appear in the .mrk file',...
                '2) Enter new names for your markers (optionnal)',...
                '3) Enter the stimulus duration (in ms) (leave empty if you do not want reject epochs containing eye blinks)',...
                '4) Around which markers do you want to epoch ?',newline ...
                'Let 1), 2) & 4) empty if you want to epoch around every trigger'};
        end
        
        % Generate the table
        screensize = get( groot, 'Screensize' );
        figure('Position', [screensize(3)/2-350 screensize(4)/2-300 700 600])
         t = uitable('Data',to_display,'ColumnEditable',[true true true true],...
            'ColumnName',{'Marker ID', 'Renamed Marker','Stim Duration', 'To epoch ?'},'CellEditCallBack','MarkerList = get(gco,''Data'');');
        uicontrol('Style', 'text', 'Position', [100 430 500 150], 'String',text_uiCond);
        t.Position = [50 0 600 400];set (t,'ColumnWidth', {120,120,120,120});
        
        % Wait for t to close until running the rest of the script
        waitfor(t)

        if ~isempty(MarkerList)
            % Removing empty cell rows based on the first column
            trigg_name = MarkerList(~cellfun('isempty', MarkerList(:,1)));
            new_trigg = MarkerList(:,2);
            new_trigg = new_trigg(~cellfun('isempty', MarkerList(:,1)));
            StimDuration = MarkerList(:,3);
            StimDuration = StimDuration(~cellfun('isempty', MarkerList(:,1)));
            to_epoch = MarkerList(:,4);
            to_epoch = to_epoch(~cellfun('isempty', MarkerList(:,1)));

            % Appending the cell array
            alltrigg{cond} = trigg_name;
            allnewtrigg{cond} = new_trigg;
            allStimDuration{cond}  = StimDuration;
            alltoepoch{cond}  = to_epoch;
            
            % Recreate the allnewtrigg vector based on alltrigg
            for k = 1:length(allnewtrigg{cond}) 
                if isempty(allnewtrigg{cond}{k})
                    allnewtrigg{cond}{k} = alltrigg{cond}{k};
                end
            end
            
        else % If no triggers were given
            alltrigg{cond} = [];
            allnewtrigg{cond} = [];
            allStimDuration{cond}  = [];
            alltoepoch{cond}  = [];
        end

        if ge(cond,length(CondList))
           continue_loop = 0; 
        end
    end

        %% saving the epoching parameters into a structure

        Epoch_Parameters.CondList = CondList;
        Epoch_Parameters.newtrigg = allnewtrigg;
        Epoch_Parameters.trigg = alltrigg;
        Epoch_Parameters.StimDuration = allStimDuration;
        Epoch_Parameters.toepoch = alltoepoch;

        uisave('Epoch_Parameters','Marker_Parameters.mat')

    %% If already set up parameters
    else
        % Open the parameters.mat
        uiopen('Marker_Parameters.mat')

        CondList = Epoch_Parameters.CondList;
        allnewtrigg = Epoch_Parameters.newtrigg;
        alltrigg = Epoch_Parameters.trigg;
        allStimDuration = Epoch_Parameters.StimDuration;
        alltoepoch = Epoch_Parameters.toepoch;
    end
end

%% For each subject

% Get time
time_start = datestr(now);

% Run EEGLAB
eeglab
close(gcf)

% set double-precision parameter
pop_editoptions('option_single', 0);

% Epitome of UI
h = waitbar(0,{'Loading' , ['Progress: ' '0 /' num2str(numel(FileList))]});

% Error counting
count_error = 0;
i_load = 0;
StoredRejectEpochs = cell(1,numel(FileList));
Alltrials = cell(1,numel(FileList));

for sbj = 1:numel(FileList)

    %% Name shenanigans
    
    FileName = [FileList(sbj).folder,'\',FileList(sbj).name];
    name_noe = FileList(sbj).name(1:end-length(extension));
    
    if name_noe(end) == '_'
       name_noe(end) = ''; 
    end
    
    SubPath = FileList(sbj).folder(length(root_folder)+1:end);
            
    name_h = name_noe;
    name_h(name_h == '_') = ' ';
    
    NewPath = [save_folder SubPath];
    
    if FILTER == 'Y'
        NewFileNamef = [save_folder SubPath '\' name_noe '_' filtered_suffix '.set'];
    end
    
    if Epoch == 'Y'
        NewFileNamee = [save_folder SubPath '\' name_noe '_' epoched_suffix '.set'];
    end
    
    % Creating the folder
    if ~exist(NewPath, 'dir')
        mkdir(NewPath);
    end
    
    %% Finding resting-state file corresponding to current ERP file ! WIP !
%     if strcmp(PromptRSA,'Yes')
%         WhichRSPos = [];
%         SearchName = strsplit(SubPath,'\');
%         for m=1:numel(SearchName)
%             if ~isempty(SearchName{m})
%                 if sum(contains({RSFileList.name},SearchName{m})>=1) % May contain more than 1 file
%                     WhichRSPos = [WhichRSPos find(contains({RSFileList.name},SearchName{m}))];
%                 end
%             end
%         end
% 
%         % Retrieving the corresponding file
%         WhichRSPos = mode(WhichRSPos); % find the most frequent value in array
%     end

    %% Loading .bdf or .set 
    
    ext = split(extension,'.');
    ext = ext{end};    
    switch ext
        case 'bdf'
            % ERP file
            EEG = pop_biosig(FileName,'channels',1:nbchan);
%             % Resting-state file to feed ASR
%             if strcmp(PromptRSA,'Yes')                
%                 rsEEG = pop_biosig([RSFileList(WhichRSPos).folder '\' ...
%                     RSFileList(WhichRSPos).name],'channels',1:nbchan);
%             end
            
        case 'set'
            % ERP file
            EEG = pop_loadset(FileName);
%             % Resting-state file to feed ASR
%             if strcmp(PromptRSA,'Yes')               
%                 rsEEG = pop_loadset([RSFileList(WhichRSPos).folder '\' ...
%                     RSFileList(WhichRSPos).name]);
%             end
    end
        
    % Waitbar updating
    waitbar(sbj/numel(FileList),h,{name_h , ['Progress: ' num2str(sbj) '/' num2str(numel(FileList))]})
    
    % Si on a des donn�es dans le fichier, alors analyser
    if nnz(size(EEG.data,2))
    
        %% Filtering

        if FILTER == 'Y'
            
            % Editing new channel location
            EEG.data = EEG.data(1:nbchan,:,:);
            EEG.nbchan = nbchan;
            
            % ERP file
            EEG = pop_chanedit(EEG, 'load',{chanloc_path 'filetype' 'autodetect'});
            
            % Re-referencing, because chanedit erase the information
            EEG = pop_reref(EEG,ref_chan);
            
%             if strcmpi(PromptRSA,'Y')
%                 % Resting-state file (may be unnecessary)
%                 rsEEG = pop_chanedit(rsEEG, 'load',{chanloc_path 'filetype' 'autodetect'});
%                 % Resting-state file (may be unnecessary)
%                 rsEEG = pop_reref(rsEEG,ref_chan);
%             end

            % Bandpass filtering (0.5 - 40 by default)
            EEG = pop_eegfiltnew(EEG,'locutoff',low, 'hicutoff',high);

            % Removing sinuosidal noise
            if strcmpi(bool_CleanLine,'Y')
                EEG = pop_cleanline(EEG, 'SignalType','channels',...
                  'LineFrequencies', [ 50 100 ],'ComputeSpectralPower',false);
            end
            
            %% Artifact Subspace Reconstruction
            % ASR : Non-stationary artifacts removal
            if strcmpi(bool_ASR,'Y')
                EEG = clean_rawdata(EEG, -1, -1, -1, -1, 10, -1); 
            end
            
            %% if there is a filtering but no mrk importation
            if (FILTER =='Y') && (ImportMRK ~= 'Y')
                % Saving the filtered data
                pop_saveset(EEG,NewFileNamef)
            end
        end

        %% Import mrk

        % Boolean to act if catching error later on
        mrkname_noerror = 1;

        if ImportMRK == 'Y'

            % opening the .mrk file and capturing its data (trigger type and latency)
            filenameMRK = [mrk_folder SubPath '\' name_noe '.bdf.mrk'];
            delimiter = '\t';
            startRow = 2;
            formatSpec = '%q%q%q%[^\n\r]';
            fileID = fopen(filenameMRK,'r');
            % Trying to scan the file, if it creates an error, we create a log
            % and go to the next file
            try
                dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');                        
                fclose(fileID);
            catch
                mrkname_noerror = 0;
                count_error = count_error +1;
                error_log(count_error+1,1) = {filenameMRK};
            end

            % If no name mismatching
            if mrkname_noerror                        
                % deleting the structure EEG.event
                EEG = rmfield(EEG,{'event','urevent'});

                % Creating the new EEG.event and EEG.urevent structures based on the .mrk data
                for row = 1:length(dataArray{1})
                    EEG.event(row).latency = str2num(cell2mat(dataArray{1}(row)))+Error_TF;
                    EEG.event(row).type    = str2num(cell2mat(dataArray{3}(row)));
                    EEG.urevent(row).latency = str2num(cell2mat(dataArray{1}(row)))+Error_TF;
                    EEG.urevent(row).type    = str2num(cell2mat(dataArray{3}(row)));
                    EEG.event(row).urevent = row;
                end
            end

            % If the user doesn't intend to filter or epoch, save the .set now
            if (FILTER ~='Y') && (Epoch ~='Y')
                NewFileNameMRK = [save_folder SubPath '\' name_noe '_importmrk.set'];
                pop_saveset(EEG,NewFileNameMRK)  

            % if there is a filtering and mrk importation
            elseif FILTER =='Y'
                % Saving the filtered data
                pop_saveset(EEG,NewFileNamef)
            end                  
        end

        %% EPOCHING

        if Epoch == 'Y' && mrkname_noerror
            
            %% Checking for condition naming problem
            % Test if the conditions appear multiple times in the file's name
            if bool_conderror

                % For each named condition, see how many times it appear in the file's name
                error_condname = 0;
                for i = 1:length(CondList)
                    error_condname(i) = length(strfind(upper([SubPath '\' name_noe]),CondList{i}));
                end

                % If the name was seen more than once in the file's name:
                if any(error_condname > 1)
                    if sum(error_condname > 1) == 1
                        text = '\bf\fontsize{10}The following condition''s name appears multiple times in the file''s name: ';
                    elseif sum(error_condname > 1) > 1
                        text = '\bf\fontsize{10}The following conditions'' names appear multiple times in the file''s name: ';
                    end

                    % Displays a modal warning box
                    opts = struct('WindowStyle','modal',... 
                                  'Interpreter','tex'); % modal structure

                    w = warndlg({text, sprintf('%s \n', CondList{error_condname > 1}), ...
                            'It could create condition detection errors.', '\color{red}Are you sure you want to continue epoching ?'}, ...
                            'Condition detection warning', opts); % the warning

                    % The computation is frozen until the OK button is pressed    
                    warning('The epoching will resume after you press "Ok"')
                    uiwait(w); 

                    % The check will not be computed again
                    bool_conderror = 0;
                end   
            end

            %% Checking in which condition is the current file
            
            % Matching each condition string pattern with the one in the file name
            if ~isempty(CondList)
                
                % Preallocating array
                Condname_i = zeros([size(CondList,1) 1]);
                
                % For each condition, see if we find it in the name or subpath
                for i = 1:size(CondList,1)
                    Condname_i(i) = contains(upper([SubPath '\' name_noe]),CondList{i});
                end
                
                % In case of multiple positives, take the lengthier condition name
                [~,I_cond] = max(cellfun('length',CondList) .* Condname_i);
                
            else
                I_cond = 1;
            end

            % If the condition was not found, do not epoch the file
            To_Epoch = 1;
            if ~isempty(CondList)
                if sum(Condname_i) == 0
                    To_Epoch = 0;
                end
            end

            %% Assigning new marker name

            if To_Epoch 

                type = {EEG.event.type};
                Events = alltrigg{I_cond};
                NewMarkers = allnewtrigg{I_cond};

                % For each trigger
                for n = 1:length(type)
                    % Check if the marker shares one value with the the ones entered in the table before
                    if isnumeric(type{n})
                        Index = find(ismember(Events,mat2str(type{n})));
                    else
                        Index = find(ismember(Events,type{n}));
                    end
                    % If yes,
                    if ~isempty(Index) && ~isempty(NewMarkers{Index})
                        % then replace by the new marker name
                        EEG.event(n).type = NewMarkers{Index};
                    else % If no inputed marker found, converts the current marker to a string
                        if isnumeric(type{n})
                            EEG.event(n).type = mat2str(EEG.event(n).type);
                        end
                    end
                end

                %% Assigning which triggers to epoch

                toepoch_i = alltoepoch{I_cond};
                toepoch = {};
                count = 0;

                for n = 1:length(toepoch_i)
                    if toepoch_i{n} == 1
                        count = count+1;
                       % Si pas de newmarker indiqu�, on prend l'ancien ID
                       if ~isempty(NewMarkers{n})
                           toepoch{count} = NewMarkers{n};
                       else
                           toepoch{count} = Events{n};
                       end
                    end
                end

                toepoch = toepoch';

                %% Blinker detection on continuous file
                
                StimDuration = allStimDuration{I_cond};
                
                % This is only applied if stim duration provided
                if any(cellfun(@(x) ~isempty(x),StimDuration)) && ...
                    strcmpi(bool_Blinker,'Y')

                    % Introducing new algorithm for eye blinks detection and
                    % removal using BLINKER:
                    % https://www.ncbi.nlm.nih.gov/pubmed/28217081          
                    Params = checkBlinkerDefaults(struct(), getBlinkerDefaults(EEG));
                    Params.fileName = FileName;
                    SplitFileName = strsplit(FileName,'.');
                    Params.blinkerSaveFile = [pwd '\blinks.mat'];
                    Params.showMaxDistribution = false;
                    Params.verbose = false;
                    Params.fieldList = {'leftBase','rightBase'}; % 'maxFrame', 'leftZero', 'rightZero', 'leftZeroHalfHeight', 'rightZeroHalfHeight'

                    % Run BLINKER algorithm
                    try
                        [EEG, ~, blinks, blinkFits, blinkProperties, ~, ~] = pop_blinker(EEG, Params);
                        % Add the blinks to EEG.event if no error
                        EEG = addBlinkEvents(EEG, blinks, blinkFits, blinkProperties, Params.fieldList);                     
                    end
            
                end
                
                    
                %% Epoching for real              
                EEG = pop_epoch(EEG, toepoch, interval/1000);
                
                %% Last optionnal algorithms (BLINKER / Basecorr)
                
                StimDuration = allStimDuration{I_cond};
                
                % This is only applied if stim duration provided
                if any(cellfun(@(x) ~isempty(x),StimDuration)) && ...
                    strcmpi(bool_Blinker,'Y')

                    % Rejecting epochs containing blinks inside the simulus
                    % duration window
                    type = {EEG.event.type};
                    latency = cell2mat({EEG.event.latency});
                    epochs = cell2mat({EEG.event.epoch});
                    ToReject = [];
                                       
                    for t=1:length(EEG.event)

                        % Check if the marker shares one value with the ones 
                        % entered in the table before
                        Index_NewMarkers = find(ismember(NewMarkers,type{t}));
                        Index_Events = find(ismember(Events,type{t}));
                        Index = [Index_NewMarkers Index_Events]; %take into consideration both col names (old and new markers)
                        
                        % Index of triggers in the same epoch
                        IdxEpochs = epochs == EEG.event(t).epoch;

                        % For each epoch
                        if ~isempty(Index) && nnz(IdxEpochs)>1
        
                            % create an interval inside the stim duration where an eye blink shouldn't be
                            IdxWindow = (EEG.event(t).latency < latency) & (latency <= EEG.event(t).latency+str2double(StimDuration{Index}));
                            IdxWindow = find(IdxWindow); % event(s) inside the interval of interest
                            
                            % for each of these events inside the interval, see if it's about an eye blink (leftbase / rightbase)
                            for nn = 1:length(IdxWindow)
                                if any(ismember(Params.fieldList,type{IdxWindow(nn)}))
                                    ToReject = [ToReject EEG.event(t).epoch]; % append epochs containing blinks
                                    break
                                end
                            end                      
                        end
                    end
                    
                    % Reject using pop_rejepoch the flagged epochs
                    Alltrials{sbj} = EEG.trials;
                    EEGtrialsReject = zeros(1,EEG.trials);
                    EEGtrialsReject(ToReject) = 1;
                    EEG = pop_rejepoch(EEG, EEGtrialsReject ,0);
                    StoredRejectEpochs{sbj} = ToReject;
                    
                    % Remove the remaining events generated by BLINKER (left/rightbase)
                    EEG.event = EEG.event(~ismember({EEG.event.type},Params.fieldList));
                end

                %% Baseline correction
                if strcmpi(bool_Basecorr,'Y')
                    
                    % If the interval for basecorr is outside the epoched time range, shrink the window
                    if interval_basecorr(1) < EEG.times(1) % test lower bound
                        interval_basecorr(1) = EEG.times(1);
                    end
                    if interval_basecorr(end) > EEG.times(end) % test upper bound
                        interval_basecorr(end) = EEG.times(end);
                    end

                    EEG = pop_rmbase(EEG, interval_basecorr);

                end

                %% save epoched .set
                pop_saveset(EEG,NewFileNamee)
            end
        end
    else
        i_load = i_load +1;
        error_load{i_load} = FileName;
    end
end

% Waitbar updating
waitbar(1,h,{'Done !' , ['Progress: ' num2str(numel(FileList)) ' /' num2str(numel(FileList))]});
time_end = datestr(now);

%% Parameters log

% Create a .txt file with
date_name = datestr(now,'dd-mm-yy_HHMM');
fid = fopen([save_folder '\log_' date_name '.txt'],'w');

% date, starting time, finished time, number of analyzed files
fprintf(fid,'%s\t%s\r\n',['Start : ',time_start],['End: ',time_end]);
fprintf(fid,'%s\r\n',[num2str(numel(FileList)) ' files analyzed']);

% Load error
if nnz(i_load)
    fprintf(fid,'\r\n%s\r\n',['No data was found for ', num2str(i_load), ' file(s):']);
    fprintf(fid,'\t%s\r\n', error_load{:});
    fprintf(fid,'\r\n');
end

% filtering parameters
if FILTER == 'Y'
    fprintf(fid,'\r\n%s\r\n','------ Filtering parameters ------');
    fprintf(fid,'%s\r\n%s\r\n',['Files suffix: ',filtered_suffix],['Bandpass filtering: ',mat2str(low),'Hz - ',mat2str(high),'Hz']);
    if strcmpi(bool_CleanLine,'Y')
        fprintf(fid,'%s\r\n','Sinusoidal noise was treated at 50 and 100 Hz with CleanLine.');
    end
    if strcmpi(bool_ASR,'Y')
        fprintf(fid,'%s\r\n','ASR was computed.');
    end
end


% mrk importing success
if ImportMRK == 'Y'
   fprintf(fid,'\r\n%s\r\n','------ .mrk importation ------');
   fprintf(fid,'%s','The mrk files have been imported with success');
   if nnz(count_error)
      fprintf(fid,'%s',[' except for ', num2str(count_error), ' file(s):']);
      fprintf(fid,'\t%s\r\n', error_log{:});
   else
       fprintf(fid,'\r\n');
   end
   
   if nnz(Error_ms)
       fprintf(fid,'%s\r\n',['A delay of ' mat2str(Error_ms) 'ms was taken into account in the trigger display, so ' mat2str(Error_TF) 'TF.']);
   end
end


% epoching parameters
if Epoch == 'Y'
    fprintf(fid,'\r\n%s\r\n','------ Epoching parameters ------');    
    fprintf(fid,'%s\r\n',['Files suffix: ',epoched_suffix]);
    fprintf(fid,'%s%s\r\n',['Epoching intervals in ms: ' mat2str(round(interval,3))],['; in TF: ', mat2str(intervalTF),' with a ', mat2str(sr),' sampling rate']);
    
    if ~isempty(CondList)
        for cond = 1:length(CondList)
            if ~isempty(allnewtrigg{cond})
                fprintf(fid,'\r\n%s\r\n\t',['For the condition ' CondList{cond} ' the following triggers have been used to epoch data:']);
                fprintf(fid,'%s\r\n\t',allnewtrigg{cond}{cell2mat(alltoepoch{cond})});
            else
                fprintf(fid,'\r\n%s\r\n',['For the condition ' CondList{cond} ', epochs have been created around every triggers']);
            end
        end
    elseif isempty(CondList) && ~isempty(allnewtrigg)
        fprintf(fid,'\r\n%s\r\n\t','The following triggers have been used to epoch data:');        
        fprintf(fid,'%s\r\n\t',allnewtrigg{1}{cell2mat(alltoepoch{1})});
    else
        fprintf(fid,'\r\n%s\r\n\t','Epochs have been created around every triggers');        
    end
    
    if strcmpi(bool_Basecorr,'Y')
        if isempty(interval_basecorr)
            fprintf(fid,'\r\n%s\r\n','Baseline correction range: whole window');
        else        
            fprintf(fid,'\r\n%s\r\n',['Baseline correction range: ' mat2str(interval_basecorr) ' (ms).']);
        end
    end
    
    if strcmpi(bool_Blinker,'Y')
        fprintf(fid,'\r\n%s\r\n','------ Eye blinks rejection ------');
        fprintf(fid,'\r\n%s\r\n','This is a summary of the number of epochs that were rejected by the BLINKER algorithm for containing eye blinks during the stimulus presentation.');   
        for k=1:length(FileList)
            if ~isempty(StoredRejectEpochs{k})
                fprintf(fid,'\r\n%s\r\n',sprintf('%d) %s: %d/%d epochs rejected',k,...
                     FileList(k).name,length(StoredRejectEpochs{k}),Alltrials{k}));
            end
        end
    end
    
end

fclose(fid);

%% Error warning
% If the number of mismatch is non-zero
if nnz(count_error)
   
    % Display a warning message
    opts = struct('WindowStyle','modal','Interpreter','tex');
    message = [{['\fontsize{12}' num2str(count_error) ' .mrk file(s) could not be opened.']};{'Check the log for potential name mismatchings.'}];
    warndlg(message,'.mrk Importation Error',opts)
    
end

%% Creation of a table for interpolation channels

if ~strcmp(PromptAnalyses,'Specific folders')
    SubPath_all = unique(cellfun(@(x) x(length(root_folder)+2:end),{FileList(:).folder},'UniformOutput',false));
    SubPath_all = natsort(SubPath_all);

    fid = fopen([save_folder '\to_interpolate.csv'],'w');
    fprintf(fid,'%s;%s\n','Session','Bad Channels');
    fprintf(fid,'%s;','Example');
    fprintf(fid,'%d;',[2,45,46,63]);
    fprintf(fid,'\n');
    fprintf(fid,'%s\n',SubPath_all{:});
    fclose(fid);
end
disp('done');
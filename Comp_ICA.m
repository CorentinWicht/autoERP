%% ICA computation and semi-automatic rejection, channels interpolation

% This script will enable the user to compute ICA on selected files
% (optional). Moreover, the script will allow for visualization and
% rejection of eye-blink artifacts only. Also, the user will be able to
% provide a list of channels to interpolate for each data file.

% Importantly, after running this script you will need to re-run the
% Filtering_epoching.m script on the data you just processed 
% (ICAed and/or channelrejected).

% The output dataset will have the same folder structure than your selected
% root folder.

% /!\ See the guide for practical examples. /!\

%% Authors

% Corentin Wicht(script, protocol)
% Michael Mouthon (protocol)
% Hugo Najberg (script)
% Lucas Spierer (protocol)

% If you have questions or want to contribute to this pipeline, feel free 
% to contact corentin.wicht@unifr.ch

%% TO DO:
% IMPLEMENT A WAY TO DETECT IF EEGLAB PATH AND/OR FILE PATH FOR AMICA
% CONTAIN SPACES! IF THEY DO, AMICA WILL FAIL!!!!

%% --------------------- PRESS F5 -------------------- %%
%% --------------------------------------------------- %%
clear variables; close all
%% ----------------- PARAMETERS ------------- %%

% getting path of the script location
p = matlab.desktop.editor.getActiveFilename;
I_p = strfind(p,'\');
p2 = p(1:I_p(end)-1);

% ICA
PromptICA= questdlg('Would you like to compute ICA (if already done, press NO) ?', ...
	'ICA decomposition','YES','NO','NO');

% ---------- GET DIRECTORIES
% Enter the path of your most upper folder containing your FILTERED
% datasets
if strcmpi(PromptICA,'YES')
    PromptICAAlgo= questdlg(['Which ICA algorithm would you like to use ?:'...
        newline '1) RUNICA (EEGLab default) ' ...
        newline '2) AMICA (Best decomposition)' ...
        newline 'AMICA will require the installation of Mpich 2.1.4 (Windows)'], ...
        'ICA algorithms','RUNICA','AMICA','AMICA');
    
    root_folder = uigetdir('title',...
        'Enter the path of the folder containing your EPOCHED data');
else
    root_folder = uigetdir('title',...
        'Enter the path of your most upper folder containing your non-rejected ICA data');
end

% Enter the path of the folder you want to save your resulting .set
save_folder = uigetdir('title',...
    'Enter the path of the folder you want to save your resulting .set');

% ---------- PROMPTS
% Suffixes
PromptSetup = {'Enter the suffixe of your epoched datasets:',...
    'Enter the suffixe of your data with ICA:',...
    'Enter the suffixe of your new dataset:'};
PromptInputs=inputdlg(PromptSetup,'Inputs to prepare ICA',1,{'epoched','icaED','icaRejected'});
epoched_extension=strcat(PromptInputs{1},'.set');
extension=strcat(PromptInputs{2},'.set');
comp_suffix=PromptInputs{3};

% ---------- SET PATHS
% Path of all needed functions
addpath(genpath(strcat(p2,'\Functions\Functions')));
addpath(strcat(p2,'\Functions\Functions\LBPA40-atlas-2011-04-28'));
addpath(strcat(p2,'\Functions\eeglab2021.0'));

% Installing Mpich 2.4.1 for AMICA algorithm (optional)
if strcmpi(PromptICA,'YES') && strcmpi(PromptICAAlgo, 'AMICA')

    % Retrieve the type of computer
    ComputerType = computer;

    % Determining the number and letters of harddrives
    F = getdrives('-nofloppy');

    % Finding out whether it's already installed or not
    Result = 0;
    
    % For each harddrives
    for k=1:length(F)
        % Check if MPICH2 folder exists (i.e. software is installed)
        if exist([F{k} 'Program Files\MPICH2'],'dir') || ...
                exist([F{k} 'Program Files (x86)\MPICH2'],'dir') 
            Result = 1;
        end
    end

    if ~Result

        % Temporary folder to delete
        mkdir([p2 '\Mpich2_1.4']);

        % AMICA
        % https://sccn.ucsd.edu/~jason/amica_web.html
        % Saving data from web & installing
        % 64 bits
        if str2double(cell2mat(regexp(ComputerType,'\d*','Match')))==64 
            if ~exist([p2 '\Mpich2_1.4\mpich2-1.4-win-x86-64.msi'],'file')
                try
                    % Downloading Mpich2 and storing in folder
                    websave([p2 '\Mpich2_1.4\mpich2-1.4-win-x86-64.msi'],...
                        'http://www.mpich.org/static/downloads/1.4/mpich2-1.4-win-x86-64.msi')
                catch
                    sprintf('ERROR when reading the Mpich2 web certificate. Please restart MATLAB as administrator (right button click)')
                end
            end
            system([p2 '"\Mpich2_1.4\mpich2-1.4-win-x86-64.msi"']);
        
        % 32 bits    
        elseif str2double(cell2mat(regexp(ComputerType,'\d*','Match')))==32 
            if ~exist([p2 '\Mpich2_1.4\mpich2-1.4-win-ia32.msi'],'file')   
                try
                    % Downloading Mpich2 and storing in folder
                    websave([p2 '\Mpich2_1.4\mpich2-1.4-win-ia32.msi'],...
                        'http://www.mpich.org/static/downloads/1.4/mpich2-1.4-win-ia32.msi')
                catch
                    sprintf('ERROR when reading the Mpich2 web certificate. Please restart MATLAB as administrator (right button click)')
                end
            end
            system([p2 '\Mpich2_1.4\mpich2-1.4-win-ia32.msi'])
        end

        % Delete temporary directory and content (Mpich install)
        try
            rmdir([p2 '\Mpich2_1.4'],'s') 
        catch
           warning(['Could not remove the Mpich folder "' [p2 '\Mpich2_1.4'] '" automatically due to administrative rights issue.']) 
        end
    end
end

%% ICA

% Run EEGLAB and change current directory
eeglab
close all
cd(root_folder)

% set double-precision parameter
pop_editoptions('option_single', 0);
time_start = datestr(now);

% Generate folder structure
FileList = dir(['**/*' '.set']);
AllNames = unique({FileList.folder});

% Removing the consistant path
to_display = cellfun(@(x) x(length(root_folder)+2:end),AllNames,'UniformOutput',false);

% Sorting based on the natural number
to_display = natsort(to_display); 

% Matrix to integrate in the following uitable
to_display = [to_display', repmat({false},[size(AllNames,2) 1])];

% Select folders on which to apply ICA
f = figure('Position', [125 125 400 400]);
p = uitable('Parent', f,'Data',to_display,'ColumnEdit',[false true],'ColumnName',...
    {'Folders', 'Include ?'},'CellEditCallBack','SbjList = get(gco,''Data'');');
uicontrol('Style', 'text', 'Position', [20 325 200 50], 'String',...
        {'Folder selection for ICA','Click on the box of the folders you want to include'});
% Wait for t to close until running the rest of the script
waitfor(p)

% Stores the files on which to apply IC decomposition
SbjList = SbjList(find(cell2mat(SbjList(:,2))),1);
    
% Optional computation of ICA (depends on PromptICA response)
if strcmp(PromptICA,'YES')
    
    % Loop applying IC decomposition to each folder
    for Sbj = 1:length(SbjList)
        
        % Initialize EEG/ALLEEG dataset structures with default values
        ALLEEG = eeg_emptyset;
        EEG = eeg_emptyset;
        CURRENTSET = [];
        
        % Get subdirectory information (e.g. sessions name)
        FullPath_toICA = strcat(root_folder,'\',SbjList{Sbj});
        
        % Creating the folder
        ExportPath_toICA = [save_folder,'\',SbjList{Sbj}];
        if ~exist(ExportPath_toICA, 'dir')
            mkdir(ExportPath_toICA);
        end
        
        % Change path according to subdirectory information
        cd(FullPath_toICA)
        ICAFileNames={};
        FileListSubj = dir(['*' epoched_extension]);
                
        % Create names of icaed datasets
        for files = 1:size(FileListSubj,1)
            ICAFileNames(files) = {[FileListSubj(files).name(1:end-length(epoched_extension)),extension]};
        end

        % Loading multiple datasets    
        [ALLEEG EEG] = pop_loadset('filename',{FileListSubj.name},'filepath',FullPath_toICA); 
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG,...
            1:size(FileListSubj,1) ,'retrieve',1:size(FileListSubj,1) ,'study',0);

        % Run ICA
        if strcmpi(PromptICAAlgo, 'RUNICA')
            % Algorithm 1: RUNICA (EEGLab default)
            EEG = pop_runica(EEG, 'extended',1,'interupt','on','concatenate','on','icatype','runica','resave','off');
            
            % Loop for saving the datasets
            for files = 1:size(FileListSubj,1)
                %[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, size(FileListSubj,1) ,'retrieve',files,'study',0); 
                pop_saveset(EEG(files), 'filename',ICAFileNames{files},'filepath',ExportPath_toICA);
            end
        else
            % Merging all datasets 
            
            % PROBLEM HERE: size of eegdata and icaact does not match
            % anymore! What happens with the concatenation? need to
            % investigate !! 
            
            OUTEEG = pop_mergeset(ALLEEG,1:length(ALLEEG),0);
            
            % Reshaping data (taken from pop_runica) 
            % compute total data size
            totalpnts = 0;
            for i = 1:length(ALLEEG)
                totalpnts = totalpnts+ALLEEG(i).pnts*ALLEEG(i).trials;
            end
            OUTEEG.data = zeros(ALLEEG(1).nbchan, totalpnts);
    
            % Recompute data
            cpnts = 1;
            for i = 1:length(ALLEEG)
                tmplen = ALLEEG(i).pnts*ALLEEG(i).trials;
                TMP = eeg_checkset(ALLEEG(i), 'loaddata');
                OUTEEG.data(:,cpnts:cpnts+tmplen-1) = reshape(TMP.data, size(TMP.data,1), size(TMP.data,2)*size(TMP.data,3));
                cpnts = cpnts+tmplen;
            end
            OUTEEG.icaweights = [];
            OUTEEG.trials = 1;
            OUTEEG.pnts   = size(OUTEEG.data,2);
            
            % Check set
            OUTEEG = eeg_checkset(OUTEEG); 
            
            % Algorithm 2: AMICA (Best one so far)
            [W,S,mods] = runamica15(OUTEEG.data,'outdir',[ExportPath_toICA '\AmicaResults\']); 

            % Storing amica results in EEG structure
            % Loop for saving the datasets
            for files = 1:size(FileListSubj,1)
                EEG(files).icaweights = W;
                EEG(files).icasphere = S(1:size(W,1),:);
                EEG(files).icawinv = mods.A(:,:,1);
                EEG(files).mods = mods;
                
                % Recompute the matrix of ICA components activations
                EEG(files) = eeg_checkset(EEG(files), 'loaddata'); % loading the EEG.data matrix
                EEG(files).icaact = (EEG(files).icaweights*EEG(files).icasphere)*EEG(files).data(EEG(files).icachansind,:);
                EEG(files).icaact = reshape(EEG(files).icaact, size(EEG(files).icaact,1), EEG(files).pnts, EEG(files).trials);
                
                % Save the datasets
                pop_saveset(EEG(files), 'filename',ICAFileNames{files},'filepath',ExportPath_toICA);
            end
        end
    end
end

%% For each subject
% Changing the path to root_folder
if strcmp(PromptICA,'YES')
   root_folder = save_folder; 
end
cd(root_folder)
FileList = dir(['**/*' extension]);

% Only keep files inside the selected folders
AllFileList = FileList;
FileList = FileList(contains({FileList.folder},SbjList));
[FolderList,~,NumFiles] = unique({FileList.folder});
FilesCount = accumarray(NumFiles,1);

% Initialize EEG/ALLEEG dataset structures with default values
ALLEEG = eeg_emptyset;
EEG = eeg_emptyset;
CURRENTSET = [];

% Initializing loop for rejected components
CompsToRej = cell(length(FolderList),1);
Sbj=1;

% For each unique folder
for Count = 1:numel(FolderList)
    
    % For each previously concatenated file inside the folder
    for File = 1:FilesCount(Count)    
        %% Setting up the file structures
        FileName = [FileList(Sbj).folder,'\',FileList(Sbj).name];
        SubPath = FileList(Sbj).folder(length(root_folder)+1:end);

        name = FileList(Sbj).name;
        name_noe = name(1:end-length(extension));

        NewPath = [save_folder SubPath];
        I_f = strfind(name,extension);
        NewFullNamec = [NewPath '\' name(1:I_f-1),comp_suffix,'.set'];

        % Creating the folder
        if ~exist(NewPath, 'dir')
            mkdir(NewPath);
        end

        % Loading .set    
        EEG = pop_loadset(FileName);

        % Remove Cz electrode if size ICA is smaller than number of electrodes
        % This can happen if the data were re-referenced in between
        if size(EEG.icaweights,1)<EEG.nbchan
            EEG = pop_select( EEG,'nochannel',{'Cz'});
        end

        %% REJECTING COMPONENTS


        % Only when first file of concatenated sets
        % Otherwise rejection applied to all concatenated sets (same
        % components!)
        if File

            % Initialize the analysis for each data
            Restart=0;

            % Computing automated dipole fitting
            EEG=Automated_DipfitNEW(EEG);

            % ICLabel plugin
            EEG=iclabel(EEG);

            % Retrieve results (pre-select all non-brain components)
            Idx=1;
            for l=1:size(EEG.icaact,1)
                [~,CompType] = max(EEG.etc.ic_classification.ICLabel.classifications(l,:));
                if CompType ~= 1 % Brain component, see EEG.etc.ic_classification.ICLabel.classes
                    CompsToRej{Count}(Idx) = l;
                    Idx = Idx + 1;
                end
            end
            
            % Variance accounted for by each components
            % Taken from pop_prop_extended.m
            for m=1:size(EEG.icaact,1)
                maxsamp = 1e5;
                n_samp = min(maxsamp, EEG.pnts*EEG.trials);
                try
                    samp_ind = randperm(EEG.pnts*EEG.trials, n_samp);
                catch
                    samp_ind = randperm(EEG.pnts*EEG.trials);
                    samp_ind = samp_ind(1:n_samp);
                end
                if ~isempty(EEG.icachansind)
                    icachansind = EEG.icachansind;
                else
                    icachansind = 1:EEG.nbchan;
                end
                icaacttmp = EEG.icaact(m, :, :);
                datavar = mean(var(EEG.data(icachansind, samp_ind), [], 2));
                projvar = mean(var(EEG.data(icachansind, samp_ind) - ...
                EEG.icawinv(:, m) * icaacttmp(1, samp_ind), [], 2));
                PVaf(m,1) = 100 *(1 - projvar/ datavar);
            end

            while Restart<1

                % Visualize the results
                pop_viewprops( EEG, 0, 1:size(EEG.icaact,1),...
                    {'freqrange', [1 60]}, {}, 1, 'ICLabel' )

                 % Move figures all over the screen
                ScreenPos={'northwest','northeast','southeast','southwest'};
                for k=1:length(findobj('type','figure'))        
                    movegui(figure(k),ScreenPos{k})
                end

                % Matrix to integrate in the following uitable
                CompList = repmat({false},[size(EEG.icaact,1) 1]);
                CompList(CompsToRej{Count})={true};
                to_display = [num2cell(1:size(EEG.icaact,1))', CompList];

                % Select components to reject
                Screensize = get( groot, 'Screensize' );
                f = figure('Position', [Screensize(3)/2-200 Screensize(4)/2-200 400 500]);
                p=uitable('Parent', f,'Data',to_display,'ColumnEdit',[false true],'ColumnName',...
                    {'Components', 'REJECTION?'},'CellEditCallBack','CompList = get(gco,''Data'');');
                uicontrol('Style', 'text', 'Position', [0 400 400 80], 'String',...
                        {'SELECTION OF COMPONENTS TO REJECT',...
                        'Click on the box corresponding to the component(s) you want to reject.',...
                        'Components already selected correspond to all non-brain components detected by the algorithm.'});
                % Adding the Clear button
                p=ClearButton(p);

                % Wait for t to close until running the rest of the script
                waitfor(p)

                % Saving the changes
                if nnz(cell2mat(CompList))>0
                    CompsToRej{Count} = find(cell2mat(CompList)~=0)';
                    RemainPfav = sum(PVaf)-sum(PVaf(CompsToRej{Count}));
                else
                    CompsToRej{Count} = find(cell2mat(Response)==1)';
                end

                % close all figures
                close all

                % Reject the marked components and save the new dataset
                if ~isempty(CompsToRej{Count})

                    % Removing components
                    TEMPEEG = pop_subcomp( EEG, CompsToRej{Count}, 0);

                    % Visual check before/after interpolation
                    try
                        vis_artifacts(TEMPEEG,EEG);    
                    catch
                       eegplot(EEG.data, 'data2',TEMPEEG.data, 'color','off') 
                    end

                    % Wait Bar 
                    Fig=msgbox(['Take time to visualize the difference before and after IC rejection!'... 
                            newline 'THE CODE WILL CONTINUE ONCE YOU PRESS OK' ...
                            newline newline sprintf('! Currently you are keeping %s%% of the data !',...
                            num2str(round(RemainPfav,2)))],'WAIT','warn'); 
                    uiwait(Fig);
                    close all
                end

                % Check to be sure of rejection
                PromptSureRejICA = inputdlg(['Are you sure you want to reject to following components? '...
                    newline 'If yes, press OK'....
                    newline 'If not, press CANCEL and the code will restart!'],...
                    'Components to reject',5,{num2str(CompsToRej{Count})});

                % Restarts the loop if user pressed "Cancel"
                if ~isempty(PromptSureRejICA)
                    % Ends the loop 
                    Restart = 1;
                end

                % Close all figures
                close all
            end  
        end
        
        % Increment subject's files count
        Sbj = Sbj + 1;
        
        % Removing the component(s) of the data
        if ~isempty(CompsToRej{Count})
            EEG = pop_subcomp(EEG, CompsToRej{Count},0);
            pop_saveset(EEG, NewFullNamec);
            sprintf('Exporting ICA rejected dataset for file : %s',[name(1:I_f-1),comp_suffix,'.set'])
        end
    end
end

% Record timing of end of processing
time_end = datestr(now);

%% Log
username=getenv('USERNAME');

% Creating the log file
date_name = datestr(now,'dd-mm-yy_HHMM');
fid = fopen([save_folder '\ICAlog_' date_name '.txt'],'w');

% date, starting time, finished time, number of analyzed files
fprintf(fid,'%s\t%s\r\n',['Start : ',time_start],['End: ',time_end]);
fprintf(fid,'\r\n%s\r\n',['Windows username : ' username]);
fprintf(fid,'\r\n%s',[num2str(numel(FileList)) ' file(s) for which IC were rejected, out of ' num2str(numel(AllFileList)) ' file(s)']); 

% List of Files on which ICA was computed
fprintf(fid,'\r\n\r\n%s\r\n','------ ICA REJECTION SUMMARY ------');
fprintf(fid,'%s\r\n','You will find below the list of components rejected for each folders containing the concatenated ICA decomposition datasets:');

for k=1:length(FolderList)
    fprintf(fid,'\r\n%d) %s',k,[FolderList{k}]);
    fprintf(fid,'\r\nComponent(s): %s\r\n',num2str(CompsToRej{k,:}));
end

% Closing the file
fclose(fid);
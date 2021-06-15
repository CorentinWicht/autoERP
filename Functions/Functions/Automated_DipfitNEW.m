function EEG = Automated_DipfitNEW(EEG)
            
% This function performs automated Dipoles Fitting (DIPFIT2) 
% while locating the dipoles in LBPA40 Atlas. 

% Usage:
%    >> EEG= Automated_Dipfit(EEG)

% Inputs:
%   EEG       = EEG dataset structure

% Outputs:
%   EEG       - Updated EEG structure

% Author: Corentin Wicht, LCNS, 2018

%-------------------------------------------------------------------------%
% DIFPIT
%-------------------------------------------------------------------------%

% Need to use MNI template to match the ATLAS coordinates! 
DipFitPath=backslash(strcat(strrep(which('eeglab'),'eeglab.m',''),'plugins\dipfit\'));

%  Calculate the invidivualized transform parameters of elect locations
EEG=pop_chanedit(EEG,'lookup',strcat(DipFitPath,'standard_BEM\\elec\\standard_1005.elc')); 

% Setting DipFit models and preferences
EEG = pop_dipfit_settings(EEG, 'hdmfile',...
    strcat(DipFitPath,'standard_BEM\\standard_vol.mat'),...
    'coordformat','MNI','mrifile',strcat(DipFitPath,'standard_BEM\\standard_mri.mat'),... 
    'chanfile',strcat(DipFitPath,'standard_BEM\\elec\\standard_1005.elc'),...
    'coord_transform',[0 0 0 0 0 -1.5708 1 1 1],'chansel',1:EEG.nbchan); 

% Automated dipole fitting of selected components
EEG = pop_multifit(EEG, 1:length(EEG.reject.gcompreject) ,'threshold',15,...
    'dipplot','off','dipoles',2,'plotopt',{'normlen' 'on'},'rmout','on');
% 0.15 parameter is based on: Wyczesany, Grzybowski, & Kaiser, 2015 + Ferdek et al. 2016 + Hammon et al. 2008

close gcf

end
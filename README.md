# autoERP2.0
This is an updated version of the original [autoERP](https://github.com/HugoNjb/autoERP) developed by Hugo Najberg.

LNS automated Matlab scripts for pre-processing raw EEG signal into filtered epoched data (Filtering_epoching.m), performing Independent Components Analyses (ICA) (Comp_ICA.m), and computing ERPs after interpolation and artefacts rejection (ERPs.m).

**⚠️ Currently only compatible with raw .bdf (BioSemi) and .set files with 64 channels**

## Description:
Flexible and adaptable to all designs and folder trees.

All steps can be skiped. All default values can be modified.

A log is generated after each run to explain what was done to the files.

For more information on how to get started, please refer to the **[Wiki user manual](https://github.com/CorentinWicht/autoERP2.0/wiki/User-manual)**.

**Script order and details:**


### 1) Filter_epoching.m
This script filters, imports marker files (.mrk) and epochs .bdf or .set files.
You can create and save your epoching parameters in a .mat file to re-load them in a future use of this script.

Filtering pipeling:
1. Re-referencing
2. Bandpass filtering
3. Removing sinusoidal noise (CleanLine)
4. Detecting blinks (Blinker)
5. Non-sinusoidal noise filtering (ASR)
6. Removing the blinks detected in 4.
7. Applying baseline correction

At the end of the epoching process, a to_interpolate.xlsx file is generated. \
You can write in it the bad channels that will have to be interpolated and load them during the ERPs script. \
**Do not erase the first example line of the to_interpolate.xlsx file.**


### 2) comp_ICA.m (optional)
This script will automatically computed ICA on all the loaded files and will prompt the user to select the components that should be rejected for each of the files. 
The components rejection graphical interface is based on the [ICLabel](https://sccn.ucsd.edu/wiki/ICLabel) display. 


### 3) ERPs.m

1. Interpolate the bad channels
2. Reject epochs containings artifacts while ignoring the bad channels: 80uV threshold criterion and 30uV jumps
3. Compute the ERP based on averaging parameters 
4. Compute the average reference or reference to Cz

You can create and save your averaging parameters to re-load them in a future use of this script.
If no merging condition and no events are given, each file will be averaged over all its epochs.
At the end of the run, a file named Ntrials.xlsx is generated. It contains the number of epochs at the start, deleted during artifacts rejection, and in the final ERPs.

## Dependencies
| PLUGINS | Description |
| ------ | ------ |
| [EEGLAB v2021.0](https://github.com/sccn/eeglab) | Main software that manages most of the preprocessing and analyses toolboxes described in the table below |
| [BLINKER v1.1.2](http://vislab.github.io/EEG-Blinks/) | BLINKER  is an automated pipeline for detecting eye blinks in EEG and calculating various properties of these blinks | 
| [CleanLine v2.0](https://github.com/sccn/cleanline) | This plugin adaptively estimates and removes sinusoidal (e.g. line) noise from your ICA components or scalp channels using multi-tapering and a Thompson F-statistic |
| [Clean_rawdata v2.3](https://github.com/sccn/clean_rawdata)| This plugin is used solely for the vis_artifacts.m function for the ICA script |
|[ICLabel v1.3](https://github.com/sccn/ICLabel)|An automatic EEG independent component classifer plugin |
|[EEGInterp](https://d-nb.info/1175873608/34)| Homemade function to compute multiquadric interpolation based on radial basis function |

Isolated functions:
* [saveeph](https://sites.google.com/site/cartoolcommunity/files)
* [natsort](https://ch.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort)

The dependencies are already included in the Functions folder and loaded automatically.

## Changes from autoERP to autoERP2.0
1. EEGLAB and its plugins have been updated and any compatibility issue has been addressed. 
2. The to-be-interpolated electrodes are now removed before running CleanLine and ASR pre-processing algorithms (to avoid injecting high-amplitude noise and compromising the algorithms efficiency).
3. The GUI offers the possibility to define boundary triggers (e.g. Beginning and End) to remove portions of the EEG recording which may be useless (e.g. break between blocks of trials). Again, the principle is to avoid injecting noisy data (e.g. muscle movements) into the pre-processing algorithms.

## Authors
[**Hugo Najberg**](https://www3.unifr.ch/med/spierer/en/group/team/people/194247/8d66b)\
*SNSF PhD student*\
*hugo.najberg@unifr.ch, hugo.najberg@gmail.com*\
*[Laboratory for Neurorehabilitation Science](https://www3.unifr.ch/med/spierer/en/)*\
*University of Fribourg, Switzerland*

[**Corentin Wicht**](https://www.researchgate.net/profile/Wicht_Corentin)\
*SNSF Doc.CH PhD student*\
*corentin.wicht@unifr.ch, corentinw.lcns@gmail.com*\
*[Laboratory for Neurorehabilitation Science](https://www3.unifr.ch/med/spierer/en/)*\
*University of Fribourg, Switzerland*

## Cite the repository
C.A. Wicht, H. Najberg,, autoERP2.0, (2021), GitHub repository https://github.com/HugoNjb/autoERP \
[![DOI] XXX NEED TO CREATE A DOI! 

## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/">Creative Commons Attribution-NonCommercial 4.0 International License</a>.

See the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments: 
[PD Dr. Lucas Spierer](https://www.researchgate.net/profile/Lucas_Spierer) from the University of Fribourg provided substantial support and advices regarding theoretical conceptualization as well as access to the workplace and the infrastructure required to successfully complete the project. Additionally, [Dr. Michael Mouthon](https://www3.unifr.ch/med/fr/section/personnel/all/people/3229/6a825) and [Dr. Michael De Pretto](https://www3.unifr.ch/med/fr/section/personnel/all/people/117251/7303f) provided substantial advice on the pre-processing pipeline, ergonomy and testing.

## Fundings
This project was supported by a grant from the Velux Foundation (Grant #1078 to LS); from the Swiss National Science Foundation (Grant #320030_175469 to LS); and from the Research Pool of the University of Fribourg to PD Dr. Lucas Spierer.

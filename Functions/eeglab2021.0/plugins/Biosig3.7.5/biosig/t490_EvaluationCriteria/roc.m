function [argout1,argout2,argout3] = roc(d, c, varargin);
% ROC plots receiver operator curve and computes derived statistics.
%   computes the ROC curve, and a number of derived paramaters include
%   AUC, optimal threshold values, corresponding confusion matrices, etc.
%
% Remark: if the sample values in d are not unique, there is a certain
%   ambiguity in the results; the results may vary depending on
%   on the ordering of the samples. Usually, this is only an issue,
%   if the number of unique data value is much smaller than the total
%   number of samples.
%
% Tratitionally, ROC was defined in the "Biosig for Octave and matlab"
%   toolbox, later an ROC function became available in Matlab's NNET
%   (Deep Learning) toolbox with a different usage interface.
%   Therfore, there different usage-styles.
%
% Usage (traditional/biosig style):
%   RES = roc(d, c);
%   RES = roc(d1, d0);
%   RES = roc(...);
%
%   RES = roc(...,'flag_plot');
%   RES = roc(..., s);
%	plot ROC curve, including suggested thresholds
%       In order to speed up the plotting, no more than 10000 data
%       points are displayed. If you need more, you need to change
%       the source code).
%
% Usage style compatible with matlab's roc implementation:
%   [TPR, FPR, THRESHOLDS] = ROC(targets, outputs)
%        matlab-style interface for compatibiliy with Matlab's ROC implementation;
%        Note that the input arguments are reversed;
%        targets correspond to c, and outputs correspond to d.
%
% INPUT:
% d	DATA,
% c	CLASS, vector with 0 and 1
% d1	DATA of class 1
% d2	DATA of class 0
% s	line style (as used in plot)
% targets  DATA, when using matlab-style ROC
% outputs  CLASS when using matlab-style ROC
%
% OUTPUT:
%   TPR   true positive rate
%   FPR   false positive rate
%   THRESHOLDS  corresponding Threshold values
%   ACC     accuracy
%   AUC     area under ROC curve
%   Yi	  max(SEN+SPEC-1), Youden index
%   c	  TH(c) is the threshold that maximizes Yi
%
%   RES is a structure and provides many more results
%       including optimum threshold values, correpinding confusion matrices, etc.
%   RES.THRESHOLD.FPR returns the threshold value to obtain
%	the given FPR rate.
%   RES.THRESHOLD.{maxYI,maxACC,maxKAPPA,maxMCC,maxMI,maxF1,maxPHI} return the
%	threshold obtained from maximum Youden Index (YI), Accuracy, Cohen's Kappa [3],
%       Matthews correlation coefficient [2] (also known as Phi coefficient [1]),
%       Mutual information, and F1 score [4], resp.
%   RES.TH([RES.THRESHOLD.maxYIix, RES.THRESHOLD.maxACCix, RES.THRESHOLD.maxKAPPAix,
%             RES.THRESHOLD.maxMCCix, RES.THRESHOLD.maxMIix, RES.THRESHOLD.maxF1ix])
%       return the optimal threshold for the respective measure.
%   RES.H_kappa: confusion matrix when Threshold of maximum Kappa is applied.
%   RES.H_{yi,acc,kappa,mcc,mi,f1,phi}: confusion matrix when threshold of
%       optimum {...} is applied.
%
% see also: AUC, PLOT, ROC
%
% References:
% [0] https://en.wikipedia.org/wiki/ROC_curve
% [1] https://en.wikipedia.org/wiki/Phi_coefficient
% [2] https://en.wikipedia.org/wiki/Matthews_correlation_coefficient
% [3] https://en.wikipedia.org/wiki/Cohen%27s_kappa
% [4] https://en.wikipedia.org/wiki/F1_score
% [5] A. Schlögl, J. Kronegg, J.E. Huggins, S. G. Mason;
%     Evaluation criteria in BCI research.
%     (Eds.) G. Dornhege, J.R. Millan, T. Hinterberger, D.J. McFarland, K.-R.Müller;
%     Towards Brain-Computer Interfacing, MIT Press, 2007, p.327-342

%	Copyright (c) 1997-2003,2005,2007,2010,2011,2016-2019 Alois Schloegl <alois.schloegl@gmail.com>
%	This is part of the BIOSIG-toolbox http://biosig.sf.net/
%
% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Library General Public
% License as published by the Free Software Foundation; either
% version 3 of the License, or (at your option) any later version.
%
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% Library General Public License for more details.
%
% You should have received a copy of the GNU Library General Public
% License along with this library; if not, write to the
% Free Software Foundation, Inc., 59 Temple Place - Suite 330,
% Boston, MA  02111-1307, USA.
%

if all(size(d)==size(c)) && all(all((c==1) | (c==0) | isnan(c))),
        MODE='biosig_traditional';
elseif ( all(all( (d==1) | (d==0) )) && all(size(c)==size(d)) )
        MODE='matlab_style';
elseif ( (size(d,2)==1) && (size(c,2)==1) ),
        MODE='biosig_2class';
else
        error('can not identify input data style')
end


if strcmp(MODE,'matlab_style')
        warning('matlab style is not fully compatible yet');
        % Matlab's roc functions seems to add (in certain circumstances) some weird
        % 0 and 1 in its 'outputs' data (see thresholds). This seems wrong.
        % We do not aim for bug-compatibility but for correctness.
        % Therefore, this does not provide the exact same results.

        [thresholds,I] = sort(c,2);
        x = d(I);

        tpr = 1-cumsum(x==1,2)./sum(x==1,2);
        fpr = 1-cumsum(x==0,2)./sum(x==0,2);
        tpr = tpr(:,end:-1:1);
        fpr = fpr(:,end:-1:1);
        thresholds = thresholds(:,end:-1:1);
        if size(c,1)>1,
                tpr=num2cell(tpr,2);
                fpr=num2cell(fpr,2);
                thresholds=num2cell(thresholds,2);
        end;
        argout1 = tpr;
        argout2 = fpr;
        argout3 = thresholds;
        return;

elseif strcmp(MODE,'biosig_2class')
        d=d(:);
        c=c(:);
        d2=c;
        c=[ones(size(d));zeros(size(d2))];
        d=[d;d2];
        fprintf(2,'Warning ROC: XXX\n')
elseif strcmp(MODE,'biosig_traditional')
        d=d(:);
        c=c(:);
	ix = ~any(isnan([d,c]),2);
	c = c(ix);
	d = d(ix);
end;

% handle (ignore) NaN's
c = c(~isnan(d));
d = d(~isnan(d));

plot_args={'-'};
flag_plot_args = 1;
thFPR = NaN;

FLAG_DISPLAY=0;
for k=1:length(varargin)
	arg = varargin{k};
	if strcmp(arg,'FPR')
		flag_plot_args = 0;
		thFPR = varargin{k+1};
	end;
	if strcmp(arg,'flag_display') || strcmp(arg,'flag_plot')
		FLAG_DISPLAY=1;
	end
	if flag_plot_args,
		plot_args{k} = arg;
	end
end;

[D,I] = sort(d);
x = c(I);

FNR = cumsum(x==1)./sum(x==1);
TPR = 1-FNR;

TNR = cumsum(x==0)./sum(x==0);
FPR = 1-TNR;

FN = cumsum(x==1);
TP = sum(x==1)-FN;

TN = cumsum(x==0);
FP = sum(x==0)-TN;

RES.PPV = TP./(TP+FP);
RES.NPV = TN./(TN+FN);

SEN = TP./(TP+FN);
SPEC= TN./(TN+FP);
ACC = (TP+TN)./(TP+TN+FP+FN);

% SEN = [FN TP TN FP SEN SPEC ACC D];

%%% compute Cohen's kappa coefficient
N = size(d,1);

%H = [TP,FN;FP,TN];
p_i = [TP+FP,FN+TN];%sum(H,1);
pi_ = [TP+FN,FP+TN];%sum(H,2)';
pe  = sum(p_i.*pi_,2)/(N*N);  % estimate of change agreement
kap = (ACC - pe) ./ (1 - pe);
mcc = (TP .* TN - FN .* FP) ./ sqrt(prod( [p_i, pi_], 2));

% mutual information
pxi = pi_/N;                       % p(x_i)
pyj = p_i/N;                       % p(y_j)
log2pji = ([TP,FN,FP,TN]/N).*log2([TP,FN,FP,TN]./[p_i,p_i]);

% replace sumskipnan in order to avoid dependency on NaN-toolbox
% RES.MI = -sumskipnan(pyj.*log2(pyj),2) + sumskipnan(log2pji,2);
tmp1 = pyj.*log2(pyj);
tmp2 = log2pji;
tmp1(isnan(tmp1))=0;
tmp2(isnan(tmp2))=0;
RES.MI = -sum(tmp1,2) + sum(tmp2,2);

% area under the ROC curve
RES.AUC = -diff(FPR)' * (TPR(1:end-1)+TPR(2:end))/2;

% Youden index
YI = SEN + SPEC - 1;

RES.YI    = YI;
RES.ACC   = ACC;
RES.KAPPA = kap;
RES.MCC   = mcc;
RES.TH    = D;
RES.F1    = 2*TP./(2*TP+FP+FN);

RES.SEN = SEN;
RES.SPEC = SPEC;
RES.TP = TP;
RES.FP = FP;
RES.FN = FN;
RES.TN = TN;
RES.TPR = TPR;
RES.FPR = FPR;
RES.FNR = FNR;
RES.TNR = TNR;
RES.LRP = TPR./FPR;
RES.LRN = FNR./TNR;

% find optimal threshold
[tmp,ix] = max(SEN+SPEC-1);
RES.THRESHOLD.maxYI   = D(ix);
RES.THRESHOLD.maxYIix = ix;
RES.H_yi = [TN(ix),FN(ix);FP(ix),TP(ix)];

[RES.maxKAPPA,ix] = max(kap);
RES.THRESHOLD.maxKAPPA = D(ix);
RES.THRESHOLD.maxKAPPAix = ix;
RES.H_kappa = [TN(ix),FN(ix);FP(ix),TP(ix)];

[RES.maxMCC,ix] = max(mcc);
RES.THRESHOLD.maxMCC = D(ix);
RES.THRESHOLD.maxMCCix = ix;
RES.H_mcc = [TN(ix),FN(ix);FP(ix),TP(ix)];

[RES.maxMI,ix] = max(RES.MI);
RES.THRESHOLD.maxMI = D(ix);
RES.THRESHOLD.maxMIix = ix;
RES.H_mi = [TN(ix),FN(ix);FP(ix),TP(ix)];

[tmp,ix] = max(ACC);
RES.THRESHOLD.maxACC = D(ix);
RES.THRESHOLD.maxACCix = ix;
RES.H_acc = [TN(ix),FN(ix);FP(ix),TP(ix)];

[tmp,ix] = max(RES.F1);
RES.THRESHOLD.maxF1 = D(ix);
RES.THRESHOLD.maxF1ix = ix;
RES.H_f1 = [TN(ix),FN(ix);FP(ix),TP(ix)];

RES.THRESHOLD.FPR = NaN;
if ~isnan(thFPR)
	ix = max(1,min(N,round((1-thFPR)*N)));
	RES.THRESHOLD.FPR = D(ix);
	RES.THRESHOLD.FPRix = ix;
	RES.H_fpr = [TN(ix),FN(ix);FP(ix),TP(ix)];
end;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  display only 10000 points at most.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if FLAG_DISPLAY,
	len = length(FPR);
	delta = max(1,floor(len/5000));
	ix = [1:delta:len-1,len];

	ix0 = RES.THRESHOLD.maxKAPPAix;
	ix1 = RES.THRESHOLD.maxYIix ;
	ix2 = RES.THRESHOLD.maxMCCix;
	ix3 = RES.THRESHOLD.maxMIix;
	ix4 = RES.THRESHOLD.maxACCix;
	ix5 = RES.THRESHOLD.maxF1ix;

	plot(FPR(ix)*100,TPR(ix)*100, FPR(ix0)*100, TPR(ix0)*100,'ok', FPR(ix1)*100, TPR(ix1)*100, 'xb', FPR(ix2)*100, TPR(ix2)*100, 'xg', FPR(ix3)*100, TPR(ix3)*100, 'xr', FPR(ix4)*100, TPR(ix4)*100, 'xc', FPR(ix5)*100, TPR(ix5)*100, 'xm');
	ylabel('TPR [%]');xlabel('FPR [%]');
	legend({'ROC','maxKappa','maxYoudenIndex','maxMCC','maxMI','maxACC','maxF1'},'location','southeast');

	%ylabel('Sensitivity (true positive ratio) [%]');
	%xlabel('1-Specificity (false positive ratio) [%]');
end;

argout1=RES;
argout2=RES.FPR;
argout3=D;

%%% here are examples of strange results observed in Matlab's roc version
%%! [tpr1,fpr1,thresholds1] = roc([0,1,1,1,0,0,0],-[0.5:7]-4);


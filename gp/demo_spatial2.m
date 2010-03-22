%DEMO_SPATIAL4    Demonstration for a disease mapping problem with Gaussian
%                 process prior and negative binomial observation model
%
%    Description
%    The disease mapping problem consist of a data with number of death 
%    cases, Y, and background population, N, appointed to co-ordinates, X.
%    The goal is to find a relative risk surface, which describes if the 
%    number of death cases in certain areas is lower or higher than expected.
%    The data consists of the heart attacks in Finland from 1996-2000 aggregated 
%    into 20kmx20km lattice cells.
%
%    The model is constructed as follows:
%
%    The number of death cases Y_i in area i is assumed to satisfy
%
%         Y_i ~ Neg-Bin(Y_i| d, E_i * r_i)
%
%    where E_i is the expected number of deaths (see Vanhatalo and Vehtari (2007), 
%    how E_i is evaluated) at area i, r_i is the relative risk and d is the dispersion 
%    parameter coverning the variance.
%
%    We place a zero mean Gaussian process prior for log(R), R = [r_1, r_2,...,r_n], 
%    which implies that at the observed input locations latent values, f, have prior
%
%         f = log(R) ~ N(0, K),
%
%    where K is the covariance matrix, whose elements are given as 
%    K_ij = k(x_i, x_j | th). The function k(x_i, x_j | th) is covariance 
%    function and th its parameters, hyperparameters.  We place a hyperprior for
%    hyperparameters, p(th).
%
%    The inference is conducted first with EP, and then via MCMC. We sample from 
%    the full posterior p(f, th| data) by alternating the sampling from the 
%    conditional posteriors p(f | th, data) and p(th | f, data). 
%
%    See also  DEMO_REGRESSION1, DEMO_CLASSIFIC1, DEMO_SPATIAL1

% Copyright (c) 2008-2010 Jarno Vanhatalo

% This software is distributed under the GNU General Public 
% License (version 2 or later); please refer to the file 
% License.txt, included with the software, for details.


% =====================================
% 3) PIC model
% =====================================

% load the data
S = which('demo_spatial2');
L = strrep(S,'demo_spatial2.m','demos/spatial.mat');
load(L)

% Now we have loaded the following parameters
% xx = co-ordinates 
% yy = number of deaths
% ye = the expexted number of deaths

% Set the inducing inputs in a regular grid.
% Set_PIC returns the induving inputs and blockindeces for PIC. It also plots the 
% data points, inducing inputs and blocks.
dims = [1    60     1    35];
[trindex, Xu] = set_PIC(xx, dims, 6, 'corners+1xside', 1);

[n,nin] = size(xx);

% Create the covariance functions
gpcf1 = gpcf_matern32('init', 'lengthScale', 5, 'magnSigma2', 0.05);
pl = prior_t('init');
pm = prior_t('init', 's2', 0.3);
gpcf1 = gpcf_matern32('set', gpcf1, 'lengthScale_prior', pl, 'magnSigma2_prior', pm);

% Create the likelihood structure
likelih = likelih_negbin('init', yy, ye, 10);
param = 'covariance+likelihood'

% Create the PIC GP data structure
gp = gp_init('init', 'FIC', likelih, {gpcf1}, [], 'X_u', Xu, 'jitterSigma2', 0.001); 
gp = gp_init('set', gp, 'blocks', trindex);

% Set the approximate inference method to EP
gp = gp_init('set', gp, 'latent_method', {'EP', xx, yy, param});
%gp = gp_init('set', gp, 'latent_method', {'Laplace', xx, yy, param});

w=gp_pak(gp, param);      % pack the hyperparameters into one vector
fe=str2fun('gpep_e');     % create a function handle to negative log posterior
fg=str2fun('gpep_g');     % create a function handle to gradient of negative log posterior

% set the options for scg2
opt = scg2_opt;
opt.tolfun = 1e-3;
opt.tolx = 1e-3;
opt.display = 1;

% do the optimization and set the optimized hyperparameter values back to the gp structure
w=scg2(fe, w, opt, fg, gp, xx, yy, param);
gp = gp_unpak(gp,w,param);

% make prediction to the data points
[Ef, Varf] = ep_pred(gp, xx, yy, xx, param, [], trindex);

% Define help parameters for plotting
xxii=sub2ind([60 35],xx(:,2),xx(:,1));
[X1,X2]=meshgrid(1:35,1:60);

% Plot the figures
% In the results it should be noticed that:
% - there is much more people living in the south than in the north. 
%   This results in rather high variance in the north
% - The eastern Finland is known to be worse than western Finland in 
%   heart diseases also from other studies.
% - PIC has fixed the oversmoothness present in FIC
figure
G=repmat(NaN,size(X1));
G(xxii)=exp(Ef);
pcolor(X1,X2,G),shading flat
colormap(mapcolor(G)),colorbar
set(gca, 'Clim', [0.6    1.5])
axis equal
axis([0 35 0 60])
title('Posterior median of the relative risk, PIC')

figure
G=repmat(NaN,size(X1));
G(xxii)=(exp(Varf) - 1).*exp(2*Ef+Varf);
pcolor(X1,X2,G),shading flat
colormap(mapcolor(G)),colorbar
set(gca, 'Clim', [0.005    0.03])
axis equal
axis([0 35 0 60])
title('Posterior variance of the relative risk, PIC')

% the MAP estimate of the hyperparameters in kilometers. Notice that the 
% co-ordinates in the data are not in kilometers. x=1 corresponds to 20km 
% in real life
S3 = sprintf('lengt-scale: %.3f, magnSigma2: %.3f, disper: %.3f \n', gp.cf{1}.lengthScale, gp.cf{1}.magnSigma2, gp.likelih.disper)

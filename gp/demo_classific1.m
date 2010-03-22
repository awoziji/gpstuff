function demo_classific1
%DEMO_CLAASIFIC1    Classification problem demonstration for 2 classes via MCMC
%
%      Description
%      The demonstration program is based on synthetic two 
%      class data used by B.D. Ripley (Pattern Regocnition and
%      Neural Networks, 1996}. The data consists of 2-dimensional
%      vectors that are divided into two classes, labeled 0 or 1.
%      Each class has a bimodal distribution generated from equal
%      mixtures of Gaussian distributions with identical covariance
%      matrices. A Bayesian aproach is used to find the decision
%      line and predict the classes of new data points.
%
%      The probability of y being one is assumed to be 
%
%            p(y=1|f) = 1 / (1+exp(-f))
%
%      The latent values f are given a zero mean Gaussian process prior.
%      This implies that at the observed input locations latent values 
%      have prior 
%
%         f ~ N(0, K),
%
%      where K is the covariance matrix, whose elements are given as 
%      K_ij = k(x_i, x_j | th). The function k(x_i, x_j | th) is covariance 
%      function and th its parameters, hyperparameters. 
% 
%      Here we use MCMC methods to find the posterior of the latent values and 
%      hyperparameters. With these we can make predictions on the class 
%      probability of future observations. See Neal (1996) for the detailed 
%      treatment of the MCMC samplers.

% Copyright (c) 2008-2010 Jarno Vanhatalo

% This software is distributed under the GNU General Public 
% License (version 2 or later); please refer to the file 
% License.txt, included with the software, for details.

% This demonstration is based on the dataset used in the book Pattern Recognition and
% Neural Networks by B.D. Ripley (1996) Cambridge University Press ISBN 0 521
% 46986 7

%========================================================
% data analysis with full GP model
%========================================================

S = which('demo_classific1');
L = strrep(S,'demo_classific1.m','demos/synth.tr');
x=load(L);
y=x(:,end);
y = 2.*y-1;
x(:,end)=[];
[n, nin] = size(x);

% Create covariance functions
gpcf1 = gpcf_sexp('init', 'lengthScale', [0.9 0.9], 'magnSigma2', 10);

% Set the prior for the parameters of covariance functions 
pl = prior_unif('init');
gpcf1 = gpcf_sexp('set', gpcf1, 'lengthScale_prior', pl,'magnSigma2_prior', pl); %

% Create the likelihood structure
likelih = likelih_probit('init', y);
%likelih = likelih_logit('init', y);

% Create the GP data structure
gp = gp_init('init', 'FULL', likelih, {gpcf1}, [],'jitterSigma2', 1);


% ------- Laplace approximation --------

% Set the approximate inference method
gp = gp_init('set', gp, 'latent_method', {'Laplace', x, y, 'covariance'});

fe=str2fun('gpla_e');
fg=str2fun('gpla_g');
n=length(y);
opt = scg2_opt;
opt.tolfun = 1e-3;
opt.tolx = 1e-3;
opt.display = 1;
opt.maxiter = 20;

% do scaled conjugate gradient optimization 
w=gp_pak(gp, 'covariance');
[w, opt, flog]=scg2(fe, w, opt, fg, gp, x, y, 'covariance');
gp=gp_unpak(gp,w, 'covariance');

% Print some figures that show results
% First create data for predictions
xt1=repmat(linspace(min(x(:,1)),max(x(:,1)),20)',1,20);
xt2=repmat(linspace(min(x(:,2)),max(x(:,2)),20)',1,20)';
xstar=[xt1(:) xt2(:)];

% make the prediction
[Ef_la, Varf_la, Ey_la, Vary_la, p1_la] = la_pred(gp, x, y, xstar, 'covariance', [], [], ones(size(xstar,1),1) );

figure, hold on;
n_pred=size(xstar,1);
h1=pcolor(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_la,20,20))
set(h1, 'edgealpha', 0), set(h1, 'facecolor', 'interp')
colormap(repmat(linspace(1,0,64)', 1, 3).*repmat(ones(1,3), 64,1))
axis([-inf inf -inf inf]), %axis off
plot(x(y==-1,1),x(y==-1,2),'o', 'markersize', 8, 'linewidth', 2);
plot(x(y==1,1),x(y==1,2),'rx', 'markersize', 8, 'linewidth', 2);
set(gcf, 'color', 'w'), title('predictive probability and training cases with Laplace', 'fontsize', 14)

% visualise predictive probability  p(ystar = 1) with contours
figure, hold on
[cs,h]=contour(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_la,20,20),[0.025 0.25 0.5 0.75 0.975], 'linewidth', 3);
text_handle = clabel(cs,h);
set(text_handle,'BackgroundColor',[1 1 .6],'Edgecolor',[.7 .7 .7],'linewidth', 2, 'fontsize',14)
c1=[linspace(0,1,64)' 0*ones(64,1) linspace(1,0,64)'];
colormap(c1)
plot(x(y==1,1), x(y==1,2), 'rx', 'markersize', 8, 'linewidth', 2),
plot(x(y==-1,1), x(y==-1,2), 'bo', 'markersize', 8, 'linewidth', 2)
plot(xstar(:,1), xstar(:,2), 'k.'), axis([-inf inf -inf inf]), %axis off
set(gcf, 'color', 'w'), title('predictive probability contours with Laplace', 'fontsize', 14)


% ------- Expectation propagation --------

% Set the approximate inference method
gp = gp_init('set', gp, 'latent_method', {'EP', x, y, 'covariance'});

w = gp_pak(gp, 'covariance');
fe=str2fun('gpep_e');
fg=str2fun('gpep_g');
n=length(y);
opt = scg2_opt;
opt.tolfun = 1e-3;
opt.tolx = 1e-3;
opt.display = 1;

% do scaled conjugate gradient optimization 
w=gp_pak(gp, 'covariance');
[w, opt, flog]=scg2(fe, w, opt, fg, gp, x, y, 'covariance');
gp=gp_unpak(gp,w, 'covariance');

% make the prediction
[Ef_ep, Varf_ep, Ey_ep, Vary_ep, p1_ep] = ep_pred(gp, x, y, xstar, 'covariance', [], [], ones(size(xstar,1),1) );

figure, hold on;
n_pred=size(xstar,1);
h1=pcolor(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_ep,20,20))
set(h1, 'edgealpha', 0), set(h1, 'facecolor', 'interp')
colormap(repmat(linspace(1,0,64)', 1, 3).*repmat(ones(1,3), 64,1))
axis([-inf inf -inf inf]), %axis off
plot(x(y==-1,1),x(y==-1,2),'o', 'markersize', 8, 'linewidth', 2);
plot(x(y==1,1),x(y==1,2),'rx', 'markersize', 8, 'linewidth', 2);
set(gcf, 'color', 'w'), title('predictive probability and training cases with EP', 'fontsize', 14)

% visualise predictive probability  p(ystar = 1) with contours
figure, hold on
[cs,h]=contour(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_ep,20,20),[0.025 0.25 0.5 0.75 0.975], 'linewidth', 3);
text_handle = clabel(cs,h);
set(text_handle,'BackgroundColor',[1 1 .6],'Edgecolor',[.7 .7 .7],'linewidth', 2, 'fontsize',14)
c1=[linspace(0,1,64)' 0*ones(64,1) linspace(1,0,64)'];
colormap(c1)
plot(x(y==1,1), x(y==1,2), 'rx', 'markersize', 8, 'linewidth', 2),
plot(x(y==-1,1), x(y==-1,2), 'bo', 'markersize', 8, 'linewidth', 2)
plot(xstar(:,1), xstar(:,2), 'k.'), axis([-inf inf -inf inf]), %axis off
set(gcf, 'color', 'w'), title('predictive probability contours with EP', 'fontsize', 14)


% ------- MCMC ---------------
% Set the approximate inference method
gp = gp_init('set', gp, 'latent_method', {'MCMC', zeros(size(y))', @scaled_mh});

% Set the parameters for MCMC...
opt=gp_mcopt;
opt.repeat=15;
opt.nsamples=1;
opt.hmc_opt.steps=10;
opt.hmc_opt.stepadj=0.1;
opt.hmc_opt.nsamples=1;
opt.latent_opt.display=0;
opt.latent_opt.repeat = 20;
opt.latent_opt.sample_latent_scale = 0.5;
hmc2('state', sum(100*clock))
[r,g,rstate1]=gp_mc(opt, gp, x, y);

% Set the sampling options
opt.nsamples=400;
opt.repeat=1;
opt.hmc_opt.steps=4;
opt.hmc_opt.stepadj=0.02;
opt.latent_opt.repeat = 5;
hmc2('state', sum(100*clock));

% Sample 
[rgp,g,rstate2]=gp_mc(opt, gp, x, y, r);

% Make predictions
[Ef_mc, Varf_mc, Ey_mc, Vary_mc, p1_mc] = mc_pred(rgp, x, y, xstar, [], [], ones(size(xstar,1),1) );
p1_mc = mean(p1_mc,2);
%p1 = mean(squeeze(logsig(mc_pred(rr, x, rr.latentValues', xstar))),2);

figure, hold on;
n_pred=size(xstar,1);
h1=pcolor(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_mc,20,20))
set(h1, 'edgealpha', 0), set(h1, 'facecolor', 'interp')
colormap(repmat(linspace(1,0,64)', 1, 3).*repmat(ones(1,3), 64,1))
axis([-inf inf -inf inf]), %axis off
plot(x(y==-1,1),x(y==-1,2),'o', 'markersize', 8, 'linewidth', 2);
plot(x(y==1,1),x(y==1,2),'rx', 'markersize', 8, 'linewidth', 2);
set(gcf, 'color', 'w'), title('predictive probability and training cases with MCMC', 'fontsize', 14)

% visualise predictive probability  p(ystar = 1) with contours
figure, hold on
[cs,h]=contour(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_mc,20,20),[0.025 0.25 0.5 0.75 0.975], 'linewidth', 3);
text_handle = clabel(cs,h);
set(text_handle,'BackgroundColor',[1 1 .6],'Edgecolor',[.7 .7 .7],'linewidth', 2, 'fontsize',14)
c1=[linspace(0,1,64)' 0*ones(64,1) linspace(1,0,64)'];
colormap(c1)
plot(x(y==1,1), x(y==1,2), 'rx', 'markersize', 8, 'linewidth', 2),
plot(x(y==-1,1), x(y==-1,2), 'bo', 'markersize', 8, 'linewidth', 2)
plot(xstar(:,1), xstar(:,2), 'k.'), axis([-inf inf -inf inf]), %axis off
set(gcf, 'color', 'w'), title('predictive probability contours with MCMC', 'fontsize', 14)


% compare MCMC, Laplace and EP results for two latent variables
apu1 = 123; apu2 = 340;
%apu1 = randpick(1:400);  apu2 = randpick(1:400);
sf = Ef_mc(apu1,:);
sf2 = Ef_mc(apu2,:);

figure
subplot(1,2,1)
[N,X] = hist(sf);
hist(sf)
hold on
x_in = min(sf)-2:0.1:max(sf)+4;
ff = normpdf(x_in, Ef_la(apu1), sqrt(Varf_la(apu1)));
plot(x_in, max(N)/max(ff)*ff, 'g', 'lineWidth', 2)
ff = normpdf(x_in, Ef_ep(apu1), sqrt(Varf_ep(apu1)));
plot(x_in, max(N)/max(ff)*ff, 'r', 'lineWidth', 2)
ylim([0 105])
set(gca, 'Ytick', [])
title(sprintf('p(f|D) at input location (%.1f, %.1f)', xstar(apu1,1), xstar(apu1,2)));
xlim([-15 5])

subplot(1,2,2)
[N,X] = hist(sf2);
hist(sf2)
hold on
x_in = min(sf2)-2:0.1:max(sf2)+2;
ff = normpdf(x_in, Ef_la(apu2), sqrt(Varf_la(apu2)));
plot(x_in, max(N)/max(ff)*ff, 'g', 'lineWidth', 2)
ff = normpdf(x_in, Ef_ep(apu2), sqrt(Varf_ep(apu2)));
plot(x_in, max(N)/max(ff)*ff, 'r', 'lineWidth', 2)
ylim([0 105])
set(gca, 'Ytick', [])
title(sprintf('p(f|D) at input location (%.1f, %.1f)', xstar(apu2,1), xstar(apu2,2)));
xlim([-2 10])







% $$$ 
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'pos',[15 14 7 5])
% $$$ set(gcf,'paperunits',get(gcf,'units'))
% $$$ set(gcf,'paperpos',get(gcf,'pos'))
% $$$ 
% $$$ print -depsc2 /proj/bayes/jpvanhat/software/doc/GPstuffDoc/pics/demo_classific1_figHist.eps




% $$$ figure, hold on
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'DefaultAxesPosition',[0.1  0.17   0.92   0.85]);
% $$$ set(gcf,'DefaultAxesFontSize',8)   %6 8
% $$$ set(gcf,'DefaultTextFontSize',8)   %6 8
% $$$ 
% $$$ [cs,h]=contour(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_la,20,20),[0.025 0.25 0.5 0.75 0.975], 'linewidth', 2);
% $$$ c1=[linspace(0,1,64)' 0*ones(64,1) linspace(1,0,64)'];
% $$$ colormap(c1)
% $$$ plot(x(y==1,1), x(y==1,2), 'rx', 'markersize', 6, 'linewidth', 1.5),
% $$$ plot(x(y==-1,1), x(y==-1,2), 'bo', 'markersize', 6, 'linewidth', 1.5)
% $$$ %plot(xstar(:,1), xstar(:,2), 'k.'), axis([-inf inf -inf inf]), %axis off
% $$$ set(gcf, 'color', 'w')
% $$$ 
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'pos',[15 14 5 4])
% $$$ set(gcf,'paperunits',get(gcf,'units'))
% $$$ set(gcf,'paperpos',get(gcf,'pos'))
% $$$ 
% $$$ print -depsc2 /proj/bayes/jpvanhat/software/doc/GPstuffDoc/pics/demo_classific1_figLA.eps
% $$$ 
% $$$ figure, hold on
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'DefaultAxesPosition',[0.1  0.17   0.92   0.85]);
% $$$ set(gcf,'DefaultAxesFontSize',8)   %6 8
% $$$ set(gcf,'DefaultTextFontSize',8)   %6 8
% $$$ 
% $$$ [cs,h]=contour(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_ep,20,20),[0.025 0.25 0.5 0.75 0.975], 'linewidth', 2);
% $$$ c1=[linspace(0,1,64)' 0*ones(64,1) linspace(1,0,64)'];
% $$$ colormap(c1)
% $$$ plot(x(y==1,1), x(y==1,2), 'rx', 'markersize', 6, 'linewidth', 1.5),
% $$$ plot(x(y==-1,1), x(y==-1,2), 'bo', 'markersize', 6, 'linewidth', 1.5)
% $$$ %plot(xstar(:,1), xstar(:,2), 'k.'), axis([-inf inf -inf inf]), %axis off
% $$$ set(gcf, 'color', 'w')
% $$$ 
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'pos',[15 14 5 4])
% $$$ set(gcf,'paperunits',get(gcf,'units'))
% $$$ set(gcf,'paperpos',get(gcf,'pos'))
% $$$ 
% $$$ print -depsc2 /proj/bayes/jpvanhat/software/doc/GPstuffDoc/pics/demo_classific1_figEP.eps
% $$$ 
% $$$ figure, hold on
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'DefaultAxesPosition',[0.1  0.17   0.92   0.85]);
% $$$ set(gcf,'DefaultAxesFontSize',8)   %6 8
% $$$ set(gcf,'DefaultTextFontSize',8)   %6 8
% $$$ 
% $$$ [cs,h]=contour(reshape(xstar(:,1),20,20),reshape(xstar(:,2),20,20),reshape(p1_mc,20,20),[0.025 0.25 0.5 0.75 0.975], 'linewidth', 2);
% $$$ c1=[linspace(0,1,64)' 0*ones(64,1) linspace(1,0,64)'];
% $$$ colormap(c1)
% $$$ plot(x(y==1,1), x(y==1,2), 'rx', 'markersize', 6, 'linewidth', 1.5),
% $$$ plot(x(y==-1,1), x(y==-1,2), 'bo', 'markersize', 6, 'linewidth', 1.5)
% $$$ %plot(xstar(:,1), xstar(:,2), 'k.'), axis([-inf inf -inf inf]), %axis off
% $$$ set(gcf, 'color', 'w')
% $$$ 
% $$$ set(gcf,'units','centimeters');
% $$$ set(gcf,'pos',[15 14 5 4])
% $$$ set(gcf,'paperunits',get(gcf,'units'))
% $$$ set(gcf,'paperpos',get(gcf,'pos'))
% $$$ 
% $$$ print -depsc2 /proj/bayes/jpvanhat/software/doc/GPstuffDoc/pics/demo_classific1_figMCMC.eps

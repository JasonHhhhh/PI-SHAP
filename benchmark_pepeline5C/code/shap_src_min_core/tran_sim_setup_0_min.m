function par = tran_sim_setup_0_min(par, cc0)
[~, c] = size(cc0);
par.tr.cc0 = cc0;
par.tr.m.N = c - 2;

GN = par.tr.m.GN;

[par.tr.m.x, par.tr.m.D] = foDc_min(par.tr.m.N);
[par.tr.m.x, par.tr.m.w] = fonodes_min(par.tr.m.N);
par.tr.m.t = (-par.tr.m.x + 1) * par.tr.m.Ts / 2;
par.tr.m.N1 = par.tr.m.N + 1;
par.tr.m.tk = par.tr.m.t(1:par.tr.m.N1);
par.tr.m.xk = par.tr.m.x(1:par.tr.m.N1);
par.tr.tt0 = [0:par.tr.m.N1]' * par.tr.c.T / par.tr.m.N1;
par.tr.fd0 = zeros(GN, c);

sim = par.sim;

gall = par.tr.n0.phys_node;
gunique = unique(gall);
gallind = zeros(size(gall));
guniqueind = zeros(size(gunique));
for j = 1:length(gallind)
    gallind(j) = find(par.tr.m.fn == gall(j));
end
for j = 1:length(guniqueind)
    guniqueind(j) = find(par.tr.m.fn == gunique(j));
end
gtod = sparse(length(guniqueind), length(gall));
for j = 1:length(guniqueind)
    gtod(j,:) = (gallind == guniqueind(j));
end

par.tr.m.gtod = gtod;
sim.m.cc0 = par.tr.cc0;
sim.m.Yd = sim.m.Yq;
sim.m.Yd(1:length(sim.m.fn),:) = par.tr.m.Yq(1:length(par.tr.m.fn),:);
sim.m.Ygd = interp1qr(par.tr.tt0, par.tr.fd0(1:length(par.tr.m.gd),:)', par.tr.m.xd')';
sim.m.Ygs = interp1qr(par.tr.tt0, par.tr.fd0(length(par.tr.m.gd)+1:length(par.tr.m.gall),:)', par.tr.m.xd')';
sim.m.Yf = interp1qr(par.tr.tt0, par.tr.fd0', par.tr.m.xd')';
sim.m.Yd(par.tr.m.guniqueind,:) = sim.m.Yd(par.tr.m.guniqueind,:) + par.tr.m.gtod * sim.m.Yf;
sim.m.Yd1 = mean(sim.m.Yd, 2);

sim.m.Ys = par.tr.m.Pslack;
sim.m.xd = par.tr.m.xd;
sim.m.N = par.tr.m.N;
sim.m.t = par.tr.m.t;
sim.m.x = par.tr.m.x;
sim.m.N1 = par.tr.m.N1;

sim.tstep = sim.c.T / sim.solsteps;
sim.startupgrid = [0:sim.tstep / sim.c.Tsc:sim.m.Ts * sim.startup];
sim.periodgrid = [0:sim.tstep / sim.c.Tsc:sim.m.Ts];
sim.cyclesgrid = [0:sim.tstep / sim.c.Tsc:(sim.nperiods - 1) * sim.m.Ts];

par.sim = sim;
end

function [x, D] = foDc_min(N)
x = -([0:N+1]' - (N+1) / 2) / ((N+1) / 2);
D = eye(N+1) - diag(ones(N,1), -1);
D(1, N+1) = -1;
D = -D * (N / 2);
end

function [x, w] = fonodes_min(N)
x = -([0:N+1]' - (N+1) / 2) / ((N+1) / 2);
w = ones(N+1, 1) / (N / 2);
end

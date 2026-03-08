function []=gas_out_plots_nofd(par)

out=par.out; mfolder=out.mfolder;sim=par.sim;
tr=par.tr; 
psi_to_pascal=tr.c.psi_to_pascal;
mpa_to_psi=1000000/psi_to_pascal;
tr.c.mpa_to_psi=mpa_to_psi;
mmscfd_to_kgps=tr.c.mmscfd_to_kgps;
hp_to_watt=745.7;
if(par.out.doZ==1), b1=tr.c.b1; b2=tr.c.b2; end


if(par.out.plotlarge==1), 
    plotpos=[20,100,1600,860]; paperpos=[0 0 1600 860]; papersize=[1600 860]; else
    plotpos=[20,400,1200,400]; paperpos=[0 0 1200 400]; papersize=[1200 400]; end

if(par.out.plotmarketflowlims==1)
    %fixed gas withdrawals, bounds on flexible demands and supplies
    f1=figure(1); clf
    set(f1,'position',plotpos,'Color',[1 1 1]);
    subaxis(1,2,1,'MarginLeft',0.05,'SpacingHoriz',0.05), 
    plot(out.td,out.dbase(:,out.guniqueind),'LineWidth',3), axis('tight'), xlabel('Time(h)')
    if(par.out.units==1), title('Flux on demand node (kg/s)','fontweight','bold'), else
        title('Baseline Gas Withdrawals (kg/s)','fontweight','bold'), end
    if(length(out.guniqueind)<20), legend(num2str(out.gunique),'Location','SouthEast'), end
    subaxis(1,2,2,'MarginLeft',0.05,'SpacingHoriz',0.05), 
    % 进口压力
    in_p=par.sim.m.Pslack*par.sim.c.psc/1000000;
    plot(out.td,in_p,'LineWidth',3), axis('tight'), xlabel('Time(h)')
    if(par.out.units==1), title('Pressure on source node (MPa)','fontweight','bold'), else
        title('Baseline Gas Withdrawals (kg/s)','fontweight','bold'), end
    if(length(out.guniqueind)<20), legend(num2str(out.gunique),'Location','SouthEast'), end


end

if(par.out.dosim==1)
if(par.out.plotsim==1)
    %simulation plot
    f6=figure(6);
    set(f6,'position',[20,400,800,400],'Color',[1 1 1]);
    subplot(2,1,1), plot(out.tt,out.ppsim), axis('tight'), xlabel('time (hours)')
    if(par.out.units==1), title('Simulation Solution Nodal Pressures (psi)','fontweight','bold'), else
        title('Simulation Solution Nodal Pressures (MPa)','fontweight','bold'), end   
    subplot(2,1,2), plot(out.tt,out.qqsim), axis('tight'), xlabel('time (hours)')
    if(par.out.units==1), title('Simulation Solution Flows (mmscfd)','fontweight','bold'), else
        title('Simulation Solution Flows (kg/s)','fontweight','bold'), end
    if(par.out.plotpdf==1)
    set(gcf,'PaperPositionMode', 'manual','PaperUnits','points', ...
        'Paperposition',paperpos), set(gcf, 'PaperSize', papersize)
    eval(['print -dpdf ' mfolder '\6sim.pdf']), end
    if(par.out.ploteps==1)
    set(gcf,'PaperPositionMode','auto')
    eval(['print -depsc ' mfolder '\6sim.eps']), end
end

end

if(par.out.plotcomps==1)
%compression ratios, discharge pressure setpoints, compressor power
    f9=figure(9); clf
    set(f9,'position',plotpos,'Color',[1 1 1]);
    subaxis(1,3,1,'MarginLeft',0.05,'SpacingHoriz',0.05), 
    plot(out.tt,sim.cc,'LineWidth',3), axis('tight'), xlabel('hours')
    legend(num2str([1:out.n0.nc]'),'Location','SouthEast'), 
    title('Compression Ratios','FontWeight','bold'), 
    subaxis(1,3,2,'SpacingHoriz',0.05), 
    plot(out.tt,out.csetsim,'LineWidth',3), axis('tight'), xlabel('hours')
    legend(num2str([1:out.n0.nc]'),'Location','SouthEast'), 
    if(par.out.units==1), title('Discharge Pressure Setpoints (psi)','FontWeight','bold'), else
        title('Discharge Pressure Setpoints (MPa)','FontWeight','bold'), end
    subaxis(1,3,3,'MarginRight',0.05,'SpacingHoriz',0.05), 
    plot(out.tt,out.cpowsim/1000,'LineWidth',3), axis('tight'), 
    xlabel('hours'), legend(num2str([1:out.n0.nc]')), 
    title('Compressor Power (1000 hp)','FontWeight','bold'),
    if(par.out.plotpdf==1)
    set(gcf,'PaperPositionMode', 'manual','PaperUnits','points', ...
        'Paperposition',paperpos), set(gcf, 'PaperSize', papersize)
    eval(['print -dpdf ' mfolder '\9comps.pdf']), end
    if(par.out.ploteps==1)
    set(gcf,'PaperPositionMode','auto')
    eval(['print -depsc ' mfolder '\9comps.eps']), end
end

% 
% if(par.out.plotpipemass==1)
%     %optimization plot
%     f13=figure(13);
%     set(f13,'position',[20,400,800,400],'Color',[1 1 1]);
%     plot(out.tt0,out.pipe_mass_0), axis('tight'), xlabel('time (hours)')
%     if(par.out.units==1), title('Optimization Solution Mass in Pipe (mmscf)','fontweight','bold'), else
%         title('Optimization Solution Mass in Pipe (kg)','fontweight','bold'), end   
%     if(par.out.plotpdf==1)
%     set(gcf,'PaperPositionMode', 'manual','PaperUnits','points', ...
%         'Paperposition',paperpos), set(gcf, 'PaperSize', papersize)
%     eval(['print -dpdf ' mfolder '\5opt.pdf']), end
%     if(par.out.ploteps==1)
%     set(gcf,'PaperPositionMode','auto')
%     eval(['print -depsc ' mfolder '\13mass.eps']), end
% end

if(par.out.plotnetwork==1)
    f14=figure(14); clf
    plotpos=[20,100,800,800]; paperpos=[0 0 800 800]; papersize=[800 800];
    set(f14,'position',plotpos,'Color',[1 1 1]);
    gas_model_plotter_new(out.n0);
    if(par.out.plotpdf==1)
    set(gcf,'PaperPositionMode', 'manual','PaperUnits','points', ...
        'Paperposition',paperpos), set(gcf, 'PaperSize', papersize)
    eval(['print -dpdf ' mfolder '\13network.pdf']), end
    if(par.out.ploteps==1)
    set(gcf,'PaperPositionMode','auto')
    eval(['print -depsc ' mfolder '\14network.eps']), end
end


%par.out=out;
%par.tr=tr;

%% backup
% %simulation pressure minus minimum
% f4=figure(4);
% set(f4,'position',[20,400,800,400],'Color',[1 1 1]);
% subplot(2,1,1), plot(tt/3600,pp-kron(ones(length(tt),1),par.n.p_min'/1000000)), 
% title('pressure minus minimum (MPa)')
% hold on, plot([tt(1)/3600 tt(end)/3600],[0 0])
% subplot(2,1,2), plot(tt/3600,qq), title('flow (kg/s)')

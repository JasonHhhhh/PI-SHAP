m=1;
unit={'Compressor Cost(kw)','Storage Mass (kg/s)','Scaled flux variance'};
name={'compressor cost','storage mass','flux variance'};
yrange={[2.1e+9,2.35e+9],[3.45e+4,3.55e+4],[0.04,0.058]};
ls=1;
% 载入数据
% 指标数据
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_0126.mat');
x_all=SHAPtree_data_0126.x_all;
cost=SHAPtree_data_0126.cost;
mass=SHAPtree_data_0126.mass;
var=SHAPtree_data_0126.var;
ms={cost,mass,var};
metric=ms{m};
m_sum = sum(metric,2);
% MC索引
ids_res_ay=load(['data\model_mine\ids_res_ay_0126' '.mat']);
ids_ref_ay=load(['data\model_mine\ids_ref_ay_0126' '.mat']);
ids_rand_ay=load(['data\model_mine\ids_rand_ay_0126' '.mat']);
ids_ref=squeeze(ids_ref_ay.ids_ref_ay(m,ls,:));
ids_res=squeeze(ids_res_ay.ids_res_ay(m,ls,:));
ids_rand_cell=squeeze(ids_rand_ay.ids_rand_ay(m,ls,:));
m_res_ref = m_sum(ids_ref);
m_res = sort(m_sum(ids_res));
m_rand=zeros(100,10);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    m_rand0 = m_sum(ids_rand);
    m_rand(i_mc,:)=sort(m_rand0);
end
% 
m_rand_mean=mean(m_rand)';
r_ay= (m_res-m_rand_mean)./(m_rand_mean);
ratio = mean(r_ay);
disp(['m is '  num2str(m) '; ls is '  num2str(ls) '; ratio is '  num2str(ratio*100)])
c=[m_rand_mean m_res m_res_ref];

res=metric(ids_res,:);
ref=metric(ids_ref,:);
rand=zeros(100,289);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    rand0 = metric(ids_rand,:);
    rand(i_mc,:)=sort(mean(rand0',2));
end
rand_mean = mean(rand',2);
res=mean(res',2);
ref=mean(ref',2);
cc=[rand_mean res ref];

plotpos=[20,20,1100,450];
xx_ids=linspace(1,289,25);
mm=cc(xx_ids,:);
xx_plot=0:24;
f1=figure(1); clf
set(f1,'position',plotpos,'Color',[1 1 1]);
subaxis(1,2,1,'MarginLeft',0.1,'SpacingHoriz',0.1), 
bar(c), axis('tight'), xlabel('Samples'),ylabel(unit{m}),ylim(yrange{m})
title('Comparison on top10 ranking samples','fontweight','bold')
legend('Random top10 samples','DN-SHAP top10 samples','Reference samples');

subaxis(1,2,2,'MarginLeft',0.1,'SpacingHoriz',0.1), 
plot(xx_plot,mm,'LineWidth',2); axis('tight'), xlabel('Time(h)'),ylabel(unit{m})
title(['Comparison on metric of ' name{m}],'fontweight','bold')
legend('Random top10 samples','DN-SHAP top10 samples','Reference samples');

b=2;
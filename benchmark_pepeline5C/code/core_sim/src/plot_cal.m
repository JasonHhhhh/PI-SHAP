m=1;
unit={'Compressor Cost(kw)','Storage Mass (kg/s)','Scaled flux variance'};
name={'compressor cost','storage mass','flux variance'};
yrange={[2.1e+9,2.6e+9],[2.5e+4,3.8e+4],[0.04,0.07]};
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


ids_ref1_ay=load(['data\model_mine\ids_ref1_ay' '.mat']);
ids_ref2_ay=load(['data\model_mine\ids_ref2_ay' '.mat']);
ids_ref3_ay=load(['data\model_mine\ids_ref3_ay' '.mat']);
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_ref1.mat');
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_ref2.mat');
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_ref3.mat');

x_all=SHAPtree_data_ref1.x_all;
cost=SHAPtree_data_ref1.cost;
mass=SHAPtree_data_ref1.mass;
var=SHAPtree_data_ref1.var;
ms={cost,mass,var};
metric1=ms{m};
m_sum = sum(metric1,2);
ids_rand_cell=squeeze(ids_ref1_ay.ids_ref1_ay);
m_ref1=zeros(100,10);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    m_rand0 = m_sum(ids_rand);
    m_ref1(i_mc,:)=sort(m_rand0);
end
rand=zeros(100,289);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    rand0 = metric1(ids_rand,:);
    rand(i_mc,:)=sort(mean(rand0',2));
end
ref1_mean = mean(rand',2);


x_all=SHAPtree_data_ref2.x_all;
cost=SHAPtree_data_ref2.cost;
mass=SHAPtree_data_ref2.mass;
var=SHAPtree_data_ref2.var;
ms={cost,mass,var};
metric2=ms{m};
m_sum = sum(metric2,2);
ids_rand_cell=squeeze(ids_ref2_ay.ids_ref2_ay);
m_ref2=zeros(100,10);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    m_rand0 = m_sum(ids_rand);
    m_ref2(i_mc,:)=sort(m_rand0);
end
rand=zeros(100,289);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    rand0 = metric2(ids_rand,:);
    rand(i_mc,:)=sort(mean(rand0',2));
end
ref2_mean = mean(rand',2);


x_all=SHAPtree_data_ref3.x_all;
cost=SHAPtree_data_ref3.cost;
mass=SHAPtree_data_ref3.mass;
var=SHAPtree_data_ref3.var;
ms={cost,mass,var};
metric3=ms{m};
m_sum = sum(metric3,2);
ids_rand_cell=squeeze(ids_ref3_ay.ids_ref3_ay);
m_ref3=zeros(100,10);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    m_rand0 = m_sum(ids_rand);
    m_ref3(i_mc,:)=sort(m_rand0);
end
rand=zeros(100,289);
for i_mc=1:100
    ids_rand=ids_rand_cell{i_mc};
    rand0 = metric3(ids_rand,:);
    rand(i_mc,:)=sort(mean(rand0',2));
end
ref3_mean = mean(rand',2);

% 
m_rand_mean=mean(m_rand)';
r_ay= (m_res-m_rand_mean)./(m_rand_mean);
ratio = mean(r_ay);

m_ref1_mean=mean(m_ref1)';
r_ay1= (m_res-m_ref1_mean)./(m_ref1_mean);
ratio1 = mean(r_ay1);
m_ref2_mean=mean(m_ref2)';
r_ay2= (m_res-m_ref2_mean)./(m_ref2_mean);
ratio2 = mean(r_ay2);
m_ref3_mean=mean(m_ref3)';
r_ay3= (m_res-m_ref3_mean)./(m_ref3_mean);
ratio3 = mean(r_ay3);
disp(['m is '  num2str(m) '; ls is '  num2str(ls) '; ratio is '  num2str(ratio*100)])
disp(['m is '  num2str(m) '; ls is '  num2str(ls) '; ratio is '  num2str(ratio1*100)])
disp(['m is '  num2str(m) '; ls is '  num2str(ls) '; ratio is '  num2str(ratio2*100)])
disp(['m is '  num2str(m) '; ls is '  num2str(ls) '; ratio is '  num2str(ratio3*100)])
c=[m_rand_mean m_res m_ref1_mean m_ref2_mean m_ref3_mean];

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

cc=[rand_mean res ref1_mean ref2_mean ref3_mean];

plotpos=[20,20,1100,450];
xx_ids=linspace(1,289,25);
mm=cc(xx_ids,:);
xx_plot=0:24;
f1=figure(1); clf
set(f1,'position',plotpos,'Color',[1 1 1]);
subaxis(1,2,1,'MarginLeft',0.1,'SpacingHoriz',0.1), 
bar(c), axis('tight'), xlabel('Samples'),ylabel(unit{m}),ylim(yrange{m})
title('Comparison on top10 ranking samples','fontweight','bold')
legend('Random top10 samples','DN-SHAP top10 samples','Reference samples 1','Reference samples 2','Reference samples 3');

subaxis(1,2,2,'MarginLeft',0.1,'SpacingHoriz',0.1), 
plot(xx_plot,mm,'LineWidth',2); axis('tight'), xlabel('Time(h)'),ylabel(unit{m})
title(['Comparison on metric of ' name{m}],'fontweight','bold')
legend('Random top10 samples','DN-SHAP top10 samples','Reference samples 1','Reference samples 2','Reference samples 3');


b=2;
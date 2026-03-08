load('src\SHAPtree_data_0126_1000.mat');
load('src\SHAPtree_data_base.mat');
% 数据准备
shap_cost_base=squeeze(SHAPtree_data_base.shap_cost(1,:,:));
shap_mass_base=squeeze(SHAPtree_data_base.shap_mass(1,:,:));
shap_var_base=squeeze(SHAPtree_data_base.shap_var(1,:,:));

% 减去
shap_cost_base0=zeros(1,25,4);
shap_mass_base0=zeros(1,25,4);
shap_var_base0=zeros(1,25,4);
shap_cost_base0(1,:,:)=shap_cost_base;
shap_mass_base0(1,:,:)=shap_mass_base;
shap_var_base0(1,:,:)=shap_var_base;
shap_cost=SHAPtree_data_0126.shap_cost-shap_cost_base0;
shap_mass=SHAPtree_data_0126.shap_mass-shap_mass_base0;
shap_var=SHAPtree_data_0126.shap_var-shap_var_base0;
shap_cost0=shap_cost(:,:,:)./sum(shap_cost, 2);% w
shap_mass0=shap_mass(:,:,:)./sum(shap_mass, 2); % kgps
shap_var0=shap_var(:,:,:)./sum(shap_var, 2);% kgps/s
x_all=SHAPtree_data_0126.x_all;

% 求和
shap_cost00=sum(shap_cost0, 3);% w
shap_mass00=sum(shap_mass0, 3); % kgps
shap_var00=sum(shap_var0, 3);% kgps/s

x_all(all(isnan(shap_var00), 2),:,:) = [];
shap_cost00(all(isnan(shap_cost00), 2),:) = [];
shap_mass00(all(isnan(shap_mass00), 2),:) = [];
shap_var00(all(isnan(shap_var00), 2),:) = [];

% shap_error(all(isnan(shap_error), 2),:) = [];

% 一定全为正值 因为都是指标
shap_cost_add=sum(shap_cost00, 2);% w
shap_mass_add=sum(shap_mass00, 2); % kgps
shap_var_add=sum(shap_var00, 2);% kgps/s

% 
shap_cost_norm=shap_cost00;
shap_mass_norm=shap_mass00;
shap_var_norm=shap_var00;

% 25个求和为1；有正有负

% 画个SHAP值的示意图
jj=100;
t=0:24;
% f1=figure(1); clf
% set(f1,'Color',[1 1 1]);
% 
% subaxis(3,1,1), 
% bar(shap_cost_norm(jj,:),'green'), axis('tight'), 
% title('DN-SHAP values for metric A','Fontweight','bold')
% 
% subaxis(3,1,2), 
% bar(shap_mass_norm(jj,:),'blue'), axis('tight'),
% title('DN-SHAP values for metric B','FontWeight','bold')
% 
% subaxis(3,1,3), 
% bar(shap_var_norm(jj,:),'yellow'), axis('tight'), xlabel('Time(h)'),
% title('DN-SHAP values for metric C','FontWeight','bold')

% 出路label 2 4 6 8
[m,~] =size(shap_cost00);
shap_cost_label8 = cell(m,24);
shap_mass_label8 = cell(m,24);
shap_var_label8 = cell(m,24);
% 8  
for i=1:m
    for j=1:24
        if (shap_cost_norm(i,j)>=0) && (shap_cost_norm(i,j)<10)
            shap_cost_label8{i,j}='1';
        elseif (shap_cost_norm(i,j)>=10) && (shap_cost_norm(i,j)<20)
            shap_cost_label8{i,j}='2';
        elseif (shap_cost_norm(i,j)>=20) && (shap_cost_norm(i,j)<30)
            shap_cost_label8{i,j}='3';
        elseif (shap_cost_norm(i,j)>=30)
            shap_cost_label8{i,j}='4';
        elseif (shap_cost_norm(i,j)>=-10) && (shap_cost_norm(i,j)<0)
            shap_cost_label8{i,j}='-1';
        elseif (shap_cost_norm(i,j)>=-20) && (shap_cost_norm(i,j)<-10)
            shap_cost_label8{i,j}='-2';
        elseif (shap_cost_norm(i,j)>=-30) && (shap_cost_norm(i,j)<-20)
            shap_cost_label8{i,j}='-3';
        elseif (shap_cost_norm(i,j)<-30)
            shap_cost_label8{i,j}='-4';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_mass_norm(i,j)>=0) && (shap_mass_norm(i,j)<200)
            shap_mass_label8{i,j}='1';
        elseif (shap_mass_norm(i,j)>=200) && (shap_mass_norm(i,j)<500)
            shap_mass_label8{i,j}='2';
        elseif (shap_mass_norm(i,j)>=500) && (shap_mass_norm(i,j)<800)
            shap_mass_label8{i,j}='3';
        elseif (shap_mass_norm(i,j)>=800)
            shap_mass_label8{i,j}='4';
        elseif (shap_mass_norm(i,j)>=-200) && (shap_mass_norm(i,j)<0)
            shap_mass_label8{i,j}='-1';
        elseif (shap_mass_norm(i,j)>=-500) && (shap_mass_norm(i,j)<-200)
            shap_mass_label8{i,j}='-2';
        elseif (shap_mass_norm(i,j)>=-800) && (shap_mass_norm(i,j)<-500)
            shap_mass_label8{i,j}='-3';
        elseif (shap_mass_norm(i,j)<-800)
            shap_mass_label8{i,j}='-4';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_var_norm(i,j)>=0) && (shap_var_norm(i,j)<1)
            shap_var_label8{i,j}='1';
        elseif (shap_var_norm(i,j)>=1) && (shap_var_norm(i,j)<2.5)
            shap_var_label8{i,j}='2';
        elseif (shap_var_norm(i,j)>=2.5) && (shap_var_norm(i,j)<4)
            shap_var_label8{i,j}='3';
        elseif (shap_var_norm(i,j)>=4)
            shap_var_label8{i,j}='4';
        elseif (shap_var_norm(i,j)>=-1) && (shap_var_norm(i,j)<0)
            shap_var_label8{i,j}='-1';
        elseif (shap_var_norm(i,j)>=-2.5) && (shap_var_norm(i,j)<-1)
            shap_var_label8{i,j}='-2';
        elseif (shap_var_norm(i,j)>=-4) && (shap_var_norm(i,j)<-2.5)
            shap_var_label8{i,j}='-3';
        elseif (shap_var_norm(i,j)<-4)
            shap_var_label8{i,j}='-4';
        end
    end
end
label8={shap_cost_label8,shap_var_label8,shap_var_label8};


shap_cost_label6 = cell(m,24);
shap_mass_label6 = cell(m,24);
shap_var_label6 = cell(m,24);
% 6 
for i=1:m
    for j=1:24
        if (shap_cost_norm(i,j)>=0) && (shap_cost_norm(i,j)<10)
            shap_cost_label6{i,j}='1';
        elseif (shap_cost_norm(i,j)>=10) && (shap_cost_norm(i,j)<20)
            shap_cost_label6{i,j}='2';
        elseif (shap_cost_norm(i,j)>=20) 
            shap_cost_label6{i,j}='3';
        elseif (shap_cost_norm(i,j)>=-10) && (shap_cost_norm(i,j)<0)
            shap_cost_label6{i,j}='-1';
        elseif (shap_cost_norm(i,j)>=-20) && (shap_cost_norm(i,j)<-10)
            shap_cost_label6{i,j}='-2';
        else
            shap_cost_label6{i,j}='-3';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_mass_norm(i,j)>=0) && (shap_mass_norm(i,j)<200)
            shap_mass_label6{i,j}='1';
        elseif (shap_mass_norm(i,j)>=200) && (shap_mass_norm(i,j)<500)
            shap_mass_label6{i,j}='2';
        elseif (shap_mass_norm(i,j)>=500)
            shap_mass_label6{i,j}='3';
        elseif (shap_mass_norm(i,j)>=-200) && (shap_mass_norm(i,j)<0)
            shap_mass_label6{i,j}='-1';
        elseif (shap_mass_norm(i,j)>=-500) && (shap_mass_norm(i,j)<-200)
            shap_mass_label6{i,j}='-2';
        else
            shap_mass_label6{i,j}='-3';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_var_norm(i,j)>=0) && (shap_var_norm(i,j)<1)
            shap_var_label6{i,j}='1';
        elseif (shap_var_norm(i,j)>=1) && (shap_var_norm(i,j)<2.5)
            shap_var_label6{i,j}='2';
        elseif (shap_var_norm(i,j)>=2.5)
            shap_var_label6{i,j}='3';
        elseif (shap_var_norm(i,j)>=-1) && (shap_var_norm(i,j)<0)
            shap_var_label6{i,j}='-1';
        elseif (shap_var_norm(i,j)>=-2.5) && (shap_var_norm(i,j)<-1)
            shap_var_label6{i,j}='-2';
        else
            shap_var_label6{i,j}='-3';
        end
    end
end

label6={shap_cost_label6,shap_mass_label6,shap_var_label6};
% 4 
shap_cost_label4 = cell(m,24);
shap_mass_label4 = cell(m,24);
shap_var_label4 = cell(m,24);
for i=1:m
    for j=1:24
        if (shap_cost_norm(i,j)>=0) && (shap_cost_norm(i,j)<10)
            shap_cost_label4{i,j}='1';
        elseif (shap_cost_norm(i,j)>=10)
            shap_cost_label4{i,j}='2';
        elseif (shap_cost_norm(i,j)>=-10) && (shap_cost_norm(i,j)<0)
            shap_cost_label4{i,j}='-1';
        else
            shap_cost_label4{i,j}='-2';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_mass_norm(i,j)>=0) && (shap_mass_norm(i,j)<200)
            shap_mass_label4{i,j}='1';
        elseif (shap_mass_norm(i,j)>=200)
            shap_mass_label4{i,j}='2';
        elseif (shap_mass_norm(i,j)>=-200) && (shap_mass_norm(i,j)<0)
            shap_mass_label4{i,j}='-1';
        else
            shap_mass_label4{i,j}='-2';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_var_norm(i,j)>=0) && (shap_var_norm(i,j)<1)
            shap_var_label4{i,j}='1';
        elseif (shap_var_norm(i,j)>=1)
            shap_var_label4{i,j}='2';
        elseif (shap_var_norm(i,j)>=-1) && (shap_var_norm(i,j)<0)
            shap_var_label4{i,j}='-1';
        else
            shap_var_label4{i,j}='-2';
        end
    end
end

label4={shap_cost_label4,shap_mass_label4,shap_var_label4};

% 处理X dX
% 2
shap_cost_label2 = cell(m,24);
shap_mass_label2 = cell(m,24);
shap_var_label2 = cell(m,24);
for i=1:m
    for j=1:24
        if (shap_cost_norm(i,j)>=0) 
            shap_cost_label2{i,j}='1';
        else
            shap_cost_label2{i,j}='-1';
        end
    end
end

for i=1:m
    for j=1:24
        if (shap_var_norm(i,j)>=0) 
            shap_var_label2{i,j}='1';
        else
            shap_var_label2{i,j}='-1';

        end
    end
end

for i=1:m
    for j=1:24
        if (shap_mass_norm(i,j)>=0)
            shap_mass_label2{i,j}='1';
        else
            shap_mass_label2{i,j}='-1';
        end
    end
end
label2={shap_cost_label2,shap_mass_label2,shap_var_label2};

% 处理X dX
identity_x = x_all(:,1:end-1,:);
diff_x = zeros(size(identity_x));
for i=1:m
    for j=1:4
        x=x_all(i,:,j);
        diff0_x=diff(x);
        diff_x(i,:,j)=diff0_x';
    end
end


diff_x = diff_x.*240;
a=squeeze(diff_x(1,:,:));
% identity_x = normalize(identity_x);
label_2468={label8};
% 24个决策树 先看cost
for iiii=1:4
    label_all =label_2468{iiii};
    for v=1:3
        labels=label_all{v};
        error=zeros(24,1);
        n_leaf=zeros(24,1);
        for i=1:24
            X=squeeze(cat(3,identity_x(:,i,:),diff_x(:,i,:)));
            Y=labels(:,i);
            % %     CV搜索最优叶子结点个数
            leafs = linspace(2,100,20);
            rng('default')
            N = numel(leafs);
            err = zeros(N,1);
            for n=1:N
                t = fitctree(X,Y,'CrossVal','On',...
                    'MinLeaf',leafs(n));
                err(n) = kfoldLoss(t);
            end
%                         figure
%                         plot(leafs,err);
%                         xlabel('Min Leaf Size');
%                         ylabel('cross-validated error');
            [min_error,min_id]=min(err);
            tree = fitctree(X,Y,'MinLeaf',leafs(min_id));
            [~,~,~,bestlevel] = cvLoss(tree,...
                'SubTrees','All','TreeSize','min');
            tree = prune(tree,'Level',bestlevel);
            n_leaf(i)=leafs(min_id);
            error(i)=min_error;
            disp(['saving' 'data\model_mine\ctree_' num2str(i) '_m' num2str(v) '_ls' num2str(iiii) '.mat........'])
            save(['data\model_mine\ctree1000_' num2str(i) '_m' num2str(v) '_ls' num2str(iiii) '.mat'],'tree')

        end
        save(['data\model_mine\error1000' '_m' num2str(v) '_ls' num2str(iiii) '.mat'],'error')
        save(['data\model_mine\nleaf1000' '_m' num2str(v) '_ls' num2str(iiii) '.mat'],'n_leaf')
    end
end





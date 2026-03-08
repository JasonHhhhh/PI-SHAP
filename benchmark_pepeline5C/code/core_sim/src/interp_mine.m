function yi = interp_mine(x,y,xi)
% Size of 'x' and 'y'
y = full(y);
m = size(x,1);
n = size(y,2);
m_new = size(xi,1);
yi = zeros(m_new,n);
for i=1:n % 每个因变量
    yi(:,i)=interp1(x,y(:,i),xi);
end
yi=sparse(yi);
end
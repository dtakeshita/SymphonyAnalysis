function Ind = getThresCross(V,th,dir, varargin)
%dir 1 = up, -1 = down
if nargin > 3
    ubd = varargin{1};
else
    ubd = Inf;
end

Vorig = V(1:end-1);
Vshift = V(2:end);

if dir>0
    ubd = abs(ubd);
    Ind = find(Vorig<th & Vshift>=th & Vshift < ubd) + 1;
else
    ubd = -abs(ubd);
    Ind = find(Vorig>=th & Vshift<th & Vshift>=ubd) + 1;
end



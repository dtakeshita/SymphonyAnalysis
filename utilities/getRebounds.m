function r = getRebounds(peaks_ind,trace,searchInterval, varargin)
%get rebound as fraction of peak amplitude
if nargin >=4
    flipped = varargin{1};
else
    flipped = false;
end

%trace = abs(trace);
peaks = trace(peaks_ind);
r = zeros(size(peaks));

for i=1:length(peaks)
   endPoint = min(peaks_ind(i)+searchInterval,length(trace));
   nextMin = getPeaks(trace(peaks_ind(i):endPoint),-1);
   if isempty(nextMin), nextMin = peaks(i); 
   else nextMin = nextMin(1); end
   %Greg  
   nextMax = getPeaks(trace(peaks_ind(i):endPoint),1);
   if isempty(nextMax), nextMax = 0; 
   else nextMax = nextMax(1); end
   
   %DT-If signal is flipped, look for positive peak backward, rather than
   %forward (assuming negative peak appears first in a spike)
   if flipped
       startPoint = max(peaks_ind(i)-searchInterval,1);
       nextMax = getPeaks(trace(startPoint:peaks_ind(i)),1);
   else
        nextMax = getPeaks(trace(peaks_ind(i):endPoint),1);
   end
   if isempty(nextMax), nextMax = 0; 
   else
       if flipped
           nextMax = nextMax(end);
       else
           nextMax = nextMax(1);
       end
   end
   
      %DT-take the time window for max both forward and backward in
      %time-but, this also causes a problem...
%    startPoint = max(peaks_ind(i)-searchInterval,1);
%    x_L = startPoint:peaks_ind(i); x_R = peaks_ind(i):endPoint;
%    [max_L, idx_L] = getPeaks(trace(x_L),1);
%    [max_R, idx_R] = getPeaks(trace(x_R),1);
%    if isempty(max_L) && isempty(max_R)
%        nextMax = 0;
%    elseif  ~isempty(max_L) && ~isempty(max_R)
%        del_idx_L = length(x_L)-idx_L(end);
%        del_idx_R = idx_R(1)-1;
%        if del_idx_L == del_idx_R
%            nextMax = max(max_L(end),max_R(1));
%        elseif del_idx_L < del_idx_R
%            nextMax = max_L(end);
%        else
%            nextMax = max_R(1);
%        end
%    elseif ~isempty(max_L)
%        nextMax = max_L(end);
%    elseif ~isempty(max_R)
%        nextMax = max_R(1); 
%    end

   if nextMin<peaks(i) %not the real spike min
       r(i) = 0;
   else
       r(i) = nextMax; 
   end
end

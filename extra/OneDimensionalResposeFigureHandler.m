% Property Descriptions:
%
% LineColor (ColorSpec)
%   Color of the mean response line. The default is blue.

classdef OneDimensionalResposeFigureHandler < FigureHandler
    
    properties (Constant)
        figureType = '1D Response'
    end
    
    properties
        deviceName
        lineColor
        stimStart %data point
        stimEnd %data point
        paramVals = []
        responseMean = []
        responseVals = {}
        responseN = []
        responseSEM = []
        responseType %only for whole-cell for now, spikes are always just counted minus baseline
        responseUnits
        mode
        epochParam
        plotType
        plotHandle
        
        %analysis params
        lowPassFreq
        spikeThreshold
        spikeDetectorMode        
    end
    
    methods
        
        function obj = OneDimensionalResposeFigureHandler(protocolPlugin, deviceName, varargin)           
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParamValue('LineColor', 'b', @(x)ischar(x) || isvector(x));
            ip.addParamValue('StartTime', 0, @(x)isnumeric(x));
            ip.addParamValue('EndTime', 0, @(x)isnumeric(x));
            ip.addParamValue('Mode', 'Cell attached', @(x)ischar(x));
            ip.addParamValue('EpochParam', '', @(x)ischar(x));
            ip.addParamValue('ResponseType', '', @(x)ischar(x));   
            ip.addParamValue('PlotType', 'Linear', @(x)ischar(x)); 
            ip.addParamValue('LowPassFreq', 100, @(x)isnumeric(x));
            ip.addParamValue('SpikeThreshold', 10, @(x)isnumeric(x));
            ip.addParamValue('SpikeDetectorMode', 'Stdev', @(x)ischar(x));
            
            % Allow deviceName to be an optional parameter.
            % inputParser.addOptional does not fully work with string variables.
            if nargin > 1 && any(strcmp(deviceName, ip.Parameters))
                varargin = [deviceName varargin];
                deviceName = [];
            end
            if nargin == 1
                deviceName = [];
            end
            
            ip.parse(varargin{:});
            
            obj = obj@FigureHandler(protocolPlugin, ip.Unmatched);
            obj.deviceName = deviceName;
            obj.lineColor = ip.Results.LineColor;
            obj.stimStart = round(ip.Results.StartTime);
            obj.stimEnd = round(ip.Results.EndTime);
            obj.mode = ip.Results.Mode;
            obj.epochParam = ip.Results.EpochParam;
            obj.responseType = ip.Results.ResponseType;
            obj.plotType = ip.Results.PlotType;
            obj.lowPassFreq = ip.Results.LowPassFreq;
            obj.spikeThreshold = ip.Results.SpikeThreshold;
            obj.spikeDetectorMode = ip.Results.SpikeDetectorMode;
            
            %set default response type
            if strcmp(obj.mode, 'Cell attached') && isempty(obj.responseType)
                obj.responseType = 'Spike count';
            elseif strcmp(obj.mode, 'Whole cell') && isempty(obj.responseType)
                obj.responseType = 'Charge';
            end
            
            if ~isempty(obj.deviceName)
                set(obj.figureHandle, 'Name', [obj.protocolPlugin.displayName ': ' obj.deviceName ' ' obj.figureType]);
            end 
 
            xlabel(obj.axesHandle(), 'sec');
            set(obj.axesHandle(), 'XTickMode', 'auto');

            %remove menubar
            set(obj.figureHandle, 'MenuBar', 'none');
            %make room for labels
            set(obj.axesHandle(), 'Position',[0.14 0.18 0.72 0.72])
            
            obj.resetPlots();
        end
        
        
        function handleEpoch(obj, epoch)
            %focus on correct figure
            set(0, 'CurrentFigure', obj.figureHandle);
            
            if isempty(obj.deviceName)
                % Use the first device response found if no device name is specified.
                [c, sampleRate, units] = epoch.response();
            else
                [responseData, sampleRate, units] = epoch.response(obj.deviceName);
            end
            
            if strcmp(obj.mode, 'Cell attached')
                %getSpikes
                if strcmp(obj.spikeDetectorMode, 'Simple threshold')
                    responseData = responseData - mean(responseData);                    
                    sp = getThresCross(responseData,obj.spikeThreshold,sign(obj.spikeThreshold));
                else
                    spikeResults = SpikeDetector_simple(responseData,1./sampleRate, obj.spikeThreshold);
                    sp = spikeResults.sp;
                end
                switch obj.responseType
                    case 'Spike count'
                        %count spikes in stimulus interval
                        spikeCount = length(find(sp>=obj.stimStart & sp<obj.stimEnd));
                        %subtract baseline
                        baselineSpikes = length(find(sp<obj.stimStart));
                        stimIntervalLen = obj.stimEnd - obj.stimStart;
                        responseVal = spikeCount - baselineSpikes*stimIntervalLen/obj.stimStart;
                        obj.responseUnits = 'spikes (norm)';
                    case 'CycleAvgF1'
                        stimLen = obj.stimEnd - obj.stimStart; %samples
                        stimSpikes = sp(sp>=obj.stimStart & sp<obj.stimEnd) - obj.stimStart; %offset to start of stim
                        binWidth = 10; %ms
                        %get bins
                        samplesPerMS = sampleRate/1E3;
                        samplesPerBin = binWidth*samplesPerMS;
                        bins = 0:samplesPerBin:stimLen;
                        
                        %compute PSTH for this epoch
                        spCount = histc(sp,bins);
                        if isempty(spCount)
                            spCount = zeros(1,length(bins));
                        end
                        
                        %convert to Hz
                        spCount = spCount / (binWidth*1E-3);
                        
                        freq = epoch.getParameter('frequency');                        
                        cyclePts = floor(sampleRate/samplesPerBin/freq);
                        numCycles = floor(length(spCount) / cyclePts);

                        % Get the average cycle.
                        cycles = zeros(numCycles, cyclePts);
                        for j = 1 : numCycles
                            index = round(((j-1)*cyclePts + (1 : floor(cyclePts))));
                            cycles(j,:) =  spCount(index);
                        end
                        % Take the mean.
                        avgCycle = mean(cycles,1);
                        
                        % Do the FFT.
                        ft = fft(avgCycle);
                        
                        % Pull out the F1 amplitude.
                        responseVal = abs(ft(2))/length(ft)*2;
                        obj.responseUnits = 'Spike rate^2/Hz'; %??? 
                end
               
            else
                stimData = responseData(obj.stimStart:obj.stimEnd);
                baselineData = responseData(1:obj.stimStart-1);
                stimIntervalLen = obj.stimEnd - obj.stimStart;
                switch obj.responseType
                    case 'Peak current'
                        stimData = stimData - mean(baselineData);
                        stimData = LowPassFilter(stimData,obj.lowPassFreq,1/sampleRate);
                        responseVal = max(abs(max(stimData)), abs(min(stimData)));
                        obj.responseUnits = 'pA';
                    case 'Charge'                        
                        responseVal = sum(stimData - mean(baselineData)) * stimIntervalLen / sampleRate;
                        obj.responseUnits = 'pC';
                    case 'CycleAvgF1'
                        stimData = stimData - mean(baselineData);
                        freq = epoch.getParameter('frequency');                        
                        cyclePts = floor(sampleRate/freq);
                        numCycles = floor(length(stimData) / cyclePts);

                        % Get the average cycle.
                        cycles = zeros(numCycles, cyclePts);
                        for j = 1 : numCycles
                            index = round(((j-1)*cyclePts + (1 : floor(cyclePts))));
                            cycles(j,:) =  stimData(index);
                        end
                        % Take the mean.
                        avgCycle = mean(cycles,1);
                        
                        % Do the FFT.
                        ft = fft(avgCycle);
                        
                        % Pull out the F1 amplitude.
                        responseVal = abs(ft(2))/length(ft)*2;
                        obj.responseUnits = 'pA^2/Hz'; %? I'm not sure this is scaled correctly for these units
                end
            end
            
            %add data to the appropriate mean structure
            paramVal = epoch.getParameter(obj.epochParam);
            ind = find(obj.paramVals == paramVal);
            if isempty(ind) %first epoch of this value
               ind = length(obj.paramVals)+1;
               obj.paramVals(ind) = paramVal;
               obj.responseMean(ind) = responseVal;
               obj.responseN(ind) = 1;
               obj.responseVals{ind} = responseVal;
               obj.responseSEM(ind) = 0;
            else
               obj.responseN(ind) = obj.responseN(ind) + 1;
               obj.responseVals{ind} = [obj.responseVals{ind}, responseVal];
               obj.responseMean(ind) = mean(obj.responseVals{ind});
               obj.responseSEM(ind) = std(obj.responseVals{ind})./sqrt(obj.responseN(ind));
            end
                        
            %make plots
            switch obj.plotType 
                case 'Linear'
                    obj.plotHandle = errorbar(obj.axesHandle(), obj.paramVals, obj.responseMean, obj.responseSEM, 'Color', obj.lineColor);
                case 'Polar'
                    %degrees to radians
                    obj.plotHandle = polarerror(obj.paramVals.*pi/180, obj.responseMean, obj.responseSEM);
                    set(obj.plotHandle(1),'Color', obj.lineColor);
                    set(obj.plotHandle(2),'Color', obj.lineColor);
                    set(obj.plotHandle(1),'Parent',obj.axesHandle());
                    set(obj.plotHandle(2),'Parent',obj.axesHandle());
                case 'LogX'
                    obj.plotHandle = errorbar(obj.axesHandle(), obj.paramVals, obj.responseMean, obj.responseSEM, 'Color', obj.lineColor);
                    set(obj.axesHandle,'xscale','log');
                case 'LogY'
                    obj.plotHandle = errorbar(obj.axesHandle(), obj.paramVals, obj.responseMean, obj.responseSEM, 'Color', obj.lineColor);
                    set(obj.axesHandle,'yscale','log');
                case 'LogLog'
                    obj.plotHandle = errorbar(obj.axesHandle(), obj.paramVals, obj.responseMean, obj.responseSEM, 'Color', obj.lineColor);
                    set(obj.axesHandle,'xscale','log');
                    set(obj.axesHandle,'yscale','log');
            end
            
            title(obj.axesHandle, [obj.epochParam ' vs. response']);
            if ~strcmp(obj.plotType, 'Polar')
                xlabel(obj.axesHandle, obj.epochParam);
                ylabel(obj.axesHandle, obj.responseUnits);
            end
        end
        
        function saveFigureData(obj,fname)
            data.paramVals = obj.paramVals;
            data.responseMean = obj.responseMean;
            data.responseVals = obj.responseVals;
            data.responseN = obj.responseN;
            data.responseSEM = obj.responseSEM;
            data.mode = obj.mode;
            data.epochParam = obj.epochParam;
            data.responseUnits = obj.responseUnits;
            data.responseType = obj.responseType;
            data.plotType = obj.plotType;
            data.lowPassFreq = obj.lowPassFreq;
            data.spikeThreshold = obj.spikeThreshold;
            data.spikeDetectorMode = obj.spikeDetectorMode;
            data.startTime = obj.stimStart;
            data.endTime = obj.stimEnd;
            save(fname,'data');
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.plotHandle = [];
            obj.paramVals = [];
            obj.responseMean = [];
            obj.responseVals = {};
            obj.responseN = [];
            obj.responseSEM = [];
        end
        
    end
    
end
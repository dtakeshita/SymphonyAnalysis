classdef EpochData < handle
    
    properties
        attributes %map for attributes from data file
        parentCell %parent cell
    end
    
    properties (Hidden)
        dataLinks
    end
    
    methods
        
        function loadParams(obj, h5group, fname)
            obj.attributes = mapAttributes(h5group, fname);
        end
        
        function addDataLinks(obj, responseGroups)
            L = length(responseGroups);
            obj.dataLinks = containers.Map;
            
            for i=1:L
                h5Name = responseGroups(i).Name;
                delimInd = strfind(h5Name, '/');
                streamName = h5Name(delimInd(end)+1:end);
                streamLink = [h5Name, '/data'];
                obj.dataLinks(streamName) = streamLink;
            end
            
        end
        
        function plotData(obj, streamName, ax)
            if nargin < 3
                ax = gca;
            end
            if nargin < 2
                streamName = 'Amplifier_Ch1';
            end
            [data, xvals, units] = obj.getData(streamName);
            if ~isempty(data)
                stimLen = obj.get('stimTime')*1E-3; %s
                
                plot(ax, xvals, data);
                if ~isempty(stimLen)
                    hold(ax, 'on');
                    startLine = line('Xdata', [0 0], 'Ydata', get(ax, 'ylim'), ...
                        'Color', 'k', 'LineStyle', '--');
                    endLine = line('Xdata', [stimLen stimLen], 'Ydata', get(ax, 'ylim'), ...
                        'Color', 'k', 'LineStyle', '--');
                    set(startLine, 'Parent', ax);
                    set(endLine, 'Parent', ax);
                end
                xlabel(ax, 'Time (s)');
                ylabel(ax, units);
                hold(ax, 'off');
            end
        end
        %% Added by DT
        function vals = get2(obj,paraName)
            nobj = numel(obj);
            %obtain the size of object
            flag_numeric = false;
            if isnumeric(get(obj(1),paraName)) && length(get(obj(1),paraName))==1
                vals = zeros(size(obj));
                flag_numeric = true;
            else
                vals = cell(size(obj));
            end
            for n=1:nobj
                if flag_numeric
                    vals(n) = get(obj(n),paraName);
                else
                    vals{n} = get(obj(n),paraName);
                end
            end
        end
        %% DT
        
        function val = get(obj, paramName)
            if ~obj.attributes.isKey(paramName)
                %disp(['Error: ' paramName ' not found']);
                val = nan;
            else
                val = obj.attributes(paramName);
            end
        end
        
        function detectSpikes(obj, params, streamName)
            if nargin < 3
                streamName = 'Amplifier_Ch1';
            end
            data = obj.getData(streamName);
            
            cellAttached = false;
            if strcmp(streamName, 'Amplifier_Ch1')
                if strcmp(obj.get('ampMode'), 'Cell attached')
                    cellAttached = true;
                end
            elseif strcmp(streamName, 'Amplifier_Ch2')
                if strcmp(obj.get('amp2Mode'), 'Cell attached')
                    cellAttached = true;
                end
            else
                disp(['Error in detectSpikes: unknown stream name ' streamName]);
            end
            
            if cellAttached
                %getSpikes
                if strcmp(params.spikeDetectorMode, 'Simple threshold')
                    data = data - mean(data);
                    sp = getThresCross(data,params.spikeThreshold,sign(params.spikeThreshold));
                else
                    sampleRate = obj.get('sampleRate');
                    spikeResults = SpikeDetector_simple(data, 1./sampleRate, obj.spikeThreshold);
                    sp = spikeResults.sp;
                end
                
                
                if strcmp(streamName, 'Amplifier_Ch1')
                    obj.attributes('spikes_ch1') = sp;
                else
                    obj.attributes('spikes_ch2') = sp;
                end
            end
        end
        
        function [spikeTimes, timeAxis] = getSpikes(obj, streamName)
            if nargin < 2
                streamName = 'Amplifier_Ch1';
            end
            spikeTimes = nan;
            if strcmp(streamName, 'Amplifier_Ch1')
                spikeTimes = obj.get('spikes_ch1');
            elseif strcmp(streamName, 'Amplifier_Ch2')
                spikeTimes = obj.get('spikes_ch2');
            end
            
            sampleRate = obj.get('sampleRate');
            dataPoints = length(obj.getData(streamName));
            stimStart = obj.get('preTime')*1E-3; %s
            if isnan(stimStart)
                stimStart = 0;
            end
            timeAxis = (0:1/sampleRate:dataPoints/sampleRate) - stimStart;
        end
        
        function [data, xvals, units] = getData(obj, streamName)
            global RAW_DATA_FOLDER;
            if nargin < 2
                streamName = 'Amplifier_Ch1';
            end
            if ~obj.dataLinks.isKey(streamName)
                %disp(['Error: no data found for ' streamName]);
                data = [];
                xvals = [];
                units = '';
            else
                temp = h5read(fullfile(RAW_DATA_FOLDER, [obj.parentCell.savedFileName '.h5']),obj.dataLinks(streamName));
                data = temp.quantity;
                units = deblank(temp.unit(:,1)');
                sampleRate = obj.get('sampleRate');
                %temp hack
                if ischar(obj.get('preTime'))
                    obj.attributes('preTime') = str2double(obj.get('preTime'));
                end
                stimStart = obj.get('preTime')*1E-3; %s
                if isnan(stimStart)
                    stimStart = 0;
                end
                xvals = (1:length(data)) / sampleRate - stimStart;
            end
        end
        
        function display(obj)
            displayAttributeMap(obj.attributes)
        end
        
    end
end
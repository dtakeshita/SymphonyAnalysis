classdef SpikeDetectorGUI < handle
    properties
        fig
        handles
        mode
        threshold
        upperBound
        spikeTimes
        data
        cellData
        epochInd
        jumpToEpochInd
        curEpochInd
        sampleRate
        streamName
    end
    
    methods
        function obj = SpikeDetectorGUI(cellData, epochInd, params, streamName)
            if nargin < 4
                obj.streamName = 'Amplifier_Ch1';
            else
                obj.streamName = streamName;
            end
            
            obj.cellData = cellData;
            obj.epochInd = epochInd;
            obj.mode = params.spikeDetectorMode;
            obj.threshold = params.spikeThreshold;
            obj.upperBound = params.spikeUpperBound;
            obj.curEpochInd = 1;
            obj.jumpToEpochInd = length(cellData.epochs);
            
            obj.buildUI();
            obj.loadData();
            obj.updateSpikeTimes();
            obj.updateUI();
        end
        
        function buildUI(obj)
            bounds = screenBounds;
            obj.fig = figure( ...
                'Name',         ['Spike Detector: Epoch ' num2str(obj.epochInd(obj.curEpochInd))], ...
                'NumberTitle',  'off', ...
                'ToolBar',      'none',...
                'Menubar',      'none', ...
                'Position', [0 0.4*bounds(4), 0.75*bounds(3), 0.25*bounds(4)], ...
                'KeyPressFcn',@(uiobj,evt)obj.keyHandler(evt));
            %set(obj.fig,'toolbar','figure');
            addZoomButtons(obj.fig);
            L_main = uiextras.VBox('Parent', obj.fig);
            L_info = uiextras.HBox('Parent', L_main, ...
                'Spacing', 10);
            detectorModeText = uicontrol('Parent', L_info, ...
                'Style', 'text', ...
                'String', 'Spike detector mode');
            obj.handles.detectorModeMenu = uicontrol('Parent', L_info, ...
                'Style', 'popupmenu', ...
                'String', {'Standard deviations above noise', 'Simple threshold'}, ...
                'Callback', @(uiobj, evt)obj.updateSpikeTimes());%clustering option may be added later
            if strcmp(obj.mode, 'Stdev')
                set(obj.handles.detectorModeMenu, 'value', 1);
            else
                set(obj.handles.detectorModeMenu, 'value', 2);
            end
            thresholdText = uicontrol('Parent', L_info, ...
                'Style', 'text', ...
                'String', 'Threshold: ');
            obj.handles.thresholdEdit = uicontrol('Parent', L_info, ...
                'Style', 'edit', ...
                'String', num2str(obj.threshold), ...
                'Callback', @(uiobj, evt)obj.updateSpikeTimes());
            upperBoundText = uicontrol('Parent', L_info, ...
                'Style', 'text', ...
                'String', 'Upper bound: ');
            obj.handles.upperBoundEdit = uicontrol('Parent', L_info, ...
                'Style', 'edit', ...
                'String', num2str(obj.upperBound), ...
                'Callback', @(uiobj, evt)obj.updateSpikeTimes());
            jumpToEpochText =  uicontrol('Parent', L_info, ...
                'Style', 'text', ...
                'String', 'Jump to: ');
            obj.handles.jumpToEpochEdit = uicontrol('Parent', L_info, ...
                'Style', 'edit', ...
                'String', num2str(obj.jumpToEpochInd), ...
                'Callback', @(uiobj, evt)obj.jumpTo());
            obj.handles.reDetectButton = uicontrol('Parent', L_info, ...
                'Style', 'pushbutton', ...
                'String', 'Re-detect spikes', ...
                'Callback', @(uiobj, evt)obj.updateSpikeTimes());
            obj.handles.applyToTheRestButton = uicontrol('Parent', L_info, ...
                'Style', 'pushbutton', ...
                'String', 'Apply to later epochs', ...
                'Callback', @(uiobj, evt)obj.updateLaterSpikeTimes());
            obj.handles.applyToAllButton = uicontrol('Parent', L_info, ...
                'Style', 'pushbutton', ...
                'String', 'Apply to all epochs', ...
                'Callback', @(uiobj, evt)obj.updateAllSpikeTimes());
            set(L_info, 'Sizes', [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]);
            obj.handles.ax = axes('Parent', L_main, ...
                'ButtonDownFcn', @axisZoomCallback);
            set(L_main, 'Sizes', [40, -1]);
        end
        
        function updateSpikeTimes(obj)
            cellAttached = false;
            if strcmp(obj.streamName, 'Amplifier_Ch1')
                if strcmp(obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('ampMode'), 'Cell attached')
                    cellAttached = true;
                end
            elseif strcmp(obj.streamName, 'Amplifier_Ch2')
                if strcmp(obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('amp2Mode'), 'Cell attached')
                    cellAttached = true;
                end
            else
                disp(['Error in detectSpikes: unknown stream name ' streamName]);
            end
            
            if cellAttached
                ind = get(obj.handles.detectorModeMenu, 'value');
                s = get(obj.handles.detectorModeMenu, 'String');
                obj.mode = s{ind};
                obj.threshold = str2double(get(obj.handles.thresholdEdit, 'String'));
                obj.upperBound = str2double(get(obj.handles.upperBoundEdit, 'String'));
                
                if strcmp(obj.mode, 'Simple threshold')
                    obj.spikeTimes = getThresCross(obj.data,obj.threshold,sign(obj.threshold),obj.upperBound);
                elseif strcmp(obj.mode, 'Standard deviations above noise')
                    spikeResults = SpikeDetector_simple(obj.data, 1./obj.sampleRate, obj.threshold,obj.upperBound);
                    obj.spikeTimes = spikeResults.sp;
                elseif strcmp(obj.mode,'clustering')
                    %% implement clustreing??-Probably need to go through all the epochs
                    doClustering(obj);
                    %updateAllSpikeTimes(obj);
                end
                
                if strcmp(obj.streamName, 'Amplifier_Ch1')
                    obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).attributes('spikes_ch1') = obj.spikeTimes;
                else
                    obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).attributes('spikes_ch2') = obj.spikeTimes;
                end
            else
                obj.spikeTimes = [];
            end
            %remove double-counted spikes
            if  length(obj.spikeTimes) >= 2
                ISItest = diff(obj.spikeTimes);
                obj.spikeTimes = obj.spikeTimes([(ISItest > 0.0015) true]);
            end
            saveAndSyncCellData(obj.cellData) %save cellData file
            zoomed = true;%keep zoomed
            obj.updateUI(zoomed);
        end
        
        function updateLaterSpikeTimes(obj)
            epochInd_st = obj.curEpochInd;
            updateAllSpikeTimes(obj, epochInd_st);
        end
        
        function updateAllSpikeTimes(obj,varargin)
            if nargin >=2
                epochInd_st = varargin{1};
            else
                epochInd_st=1;
            end
            ind = get(obj.handles.detectorModeMenu, 'value');
            s = get(obj.handles.detectorModeMenu, 'String');
            obj.mode = s{ind};
            obj.threshold = str2double(get(obj.handles.thresholdEdit, 'String'));
            
            set(obj.fig, 'Name', 'Busy...');
            drawnow;            
            for i=epochInd_st:length(obj.epochInd)
                cellAttached = false;
                if strcmp(obj.streamName, 'Amplifier_Ch1')
                    if strcmp(obj.cellData.epochs(obj.epochInd(i)).get('ampMode'), 'Cell attached')
                        cellAttached = true;
                    end
                elseif strcmp(obj.streamName, 'Amplifier_Ch2')
                    if strcmp(obj.cellData.epochs(obj.epochInd(i)).get('amp2Mode'), 'Cell attached')
                        cellAttached = true;
                    end
                else
                    disp(['Error in detectSpikes: unknown stream name ' streamName]);
                end
                
                if cellAttached
                    data = obj.cellData.epochs(obj.epochInd(i)).getData(obj.streamName);
                    data = data - mean(data);
                    data = data';
                    
                    if strcmp(obj.mode, 'Simple threshold')
                        spikeTimes = getThresCross(data,obj.threshold,sign(obj.threshold));
                    elseif strcmp(obj.mode, 'Standard deviations above noise')
                        spikeResults = SpikeDetector_simple(data, 1./obj.sampleRate, obj.threshold);
                        spikeTimes = spikeResults.sp;
                    end
                    
                    %remove double-counted spikes
                    if  length(spikeTimes) >= 2
                        ISItest = diff(spikeTimes);
                        spikeTimes = spikeTimes([(ISItest > 0.0015) true]);
                    end
                    
                    if i==obj.curEpochInd
                        obj.spikeTimes = spikeTimes;
                    end
                    
                    if strcmp(obj.streamName, 'Amplifier_Ch1')
                        obj.cellData.epochs(obj.epochInd(i)).attributes('spikes_ch1') = spikeTimes;
                    else
                        obj.cellData.epochs(obj.epochInd(i)).attributes('spikes_ch2') = spikeTimes;
                    end
                end
            end
            saveAndSyncCellData(obj.cellData) %save cellData file);
            obj.updateUI();
        end
        
        function loadData(obj)
            obj.sampleRate = obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('sampleRate');
            obj.data = obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).getData(obj.streamName);
            obj.data = obj.data - mean(obj.data);
            obj.data = obj.data';
            
            
            %load spike times if they are present
            if strcmp(obj.streamName, 'Amplifier_Ch1')
                if ~isnan(obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('spikes_ch1'))
                    obj.spikeTimes = obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('spikes_ch1');
                else
                    obj.updateSpikeTimes();
                end
            else
                if ~isnan(obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('spikes_ch2'))
                    obj.spikeTimes = obj.cellData.epochs(obj.epochInd(obj.curEpochInd)).get('spikes_ch2');
                else
                    obj.updateSpikeTimes();
                end
            end
            
            obj.updateUI();
        end
        
        function updateUI(obj, varargin)
            if nargin >=2
                zoomed = varargin{1};
            else
                zoomed = false;
            end
            if zoomed %previously zoomed, then keep it.
                x_lim = get(obj.handles.ax,'xlim');
                y_lim = get(obj.handles.ax,'ylim');
            end
            plot(obj.handles.ax, 1:length(obj.data), obj.data, 'k');
            hold(obj.handles.ax, 'on');
            plot(obj.handles.ax, obj.spikeTimes, obj.data(obj.spikeTimes), 'rx');
            hold(obj.handles.ax, 'off');
            if zoomed
                zoom(gca,'reset');
                set(obj.handles.ax,'xlim',x_lim, 'ylim', y_lim);
            end
            set(obj.fig, 'Name',['Spike Detector: Epoch ' num2str(obj.epochInd(obj.curEpochInd)) ': ' num2str(length(obj.spikeTimes)) ' spikes']);
        end
        
        function keyHandler(obj, evt)
            switch evt.Key
                case 'leftarrow'
                    obj.curEpochInd = max(obj.curEpochInd-1, 1);
                    obj.loadData();
                case 'rightarrow'
                    obj.curEpochInd = min(obj.curEpochInd+1, length(obj.epochInd));
                    obj.loadData();
                case 'escape'
                    delete(obj.fig);
                otherwise
                    %disp(evt.Key);
            end
        end
        
        function jumpTo(obj)
            obj.jumpToEpochInd = str2double(get(obj.handles.jumpToEpochEdit, 'String'));
            if obj.jumpToEpochInd < 1
                obj.jumpToEpochInd =1;
            elseif obj.jumpToEpochInd > length(obj.cellData.epochs)
                obj.jumpToEpochInd = length(obj.cellData.epochs);
            end
            obj.curEpochInd = obj.jumpToEpochInd;
            obj.loadData();
        end
        function doClustering(obj)
            set(obj.fig, 'Name', 'Busy...');
            drawnow; 
            for i=1:length(obj.epochInd)
                if isCellAttached(obj,i)
                    dat = obj.cellData.epochs(obj.epochInd(i)).getData(obj.streamName);
                    peakDetector(dat);
                    2;
                end
            end
            
        end
        function cellAttached = isCellAttached(obj, i)
            cellAttached = false;
            if strcmp(obj.streamName, 'Amplifier_Ch1')
                if strcmp(obj.cellData.epochs(obj.epochInd(i)).get('ampMode'), 'Cell attached')
                    cellAttached = true;
                end
            elseif strcmp(obj.streamName, 'Amplifier_Ch2')
                if strcmp(obj.cellData.epochs(obj.epochInd(i)).get('amp2Mode'), 'Cell attached')
                    cellAttached = true;
                end
            else
                disp(['Error in detectSpikes: unknown stream name ' streamName]);
            end
        end
    end
    
end
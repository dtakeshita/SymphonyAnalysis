classdef LightStepAnalysis < AnalysisTree
    properties
        StartTime = 0;
        EndTime = 0;
    end
    
    methods
        function obj = LightStepAnalysis(cellData, dataSetName, params)
            if nargin < 3
                params.deviceName = 'Amplifier_Ch1';
            end
            if strcmp(params.deviceName, 'Amplifier_Ch1')
                params.ampModeParam = 'ampMode';
            else
                params.ampModeParam = 'amp2Mode';
            end
            
            nameStr = [cellData.savedFileName ': ' dataSetName ': LightStepAnalysis'];
            obj = obj.setName(nameStr);
            dataSet = cellData.savedDataSets(dataSetName);
            obj = obj.copyAnalysisParams(params);
            obj = obj.copyParamsFromSampleEpoch(cellData, dataSet, ...
                {'RstarIntensity', params.ampModeParam, 'spotSize', 'offsetX', 'offsetY'});%This shouldn't have a parameter for building cell tree below.
            obj = obj.buildCellTree(1, cellData, dataSet, {'RstarMean'});
            %obj = obj.buildCellTree(1, cellData, dataSet, {'pulseAmplitude'});
        end
        
        function obj = doAnalysis(obj, cellData)
            rootData = obj.get(1);
            leafIDs = obj.findleaves();
            L = length(leafIDs);
            
            for i=1:L %for each leaf node
                curNode = obj.get(leafIDs(i));
                if strcmp(rootData.(rootData.ampModeParam), 'Cell attached')
                    outputStruct = getEpochResponses_CA_PAL(cellData, curNode.epochID, ...
                        'DeviceName', rootData.deviceName,'StartTime', obj.StartTime, 'EndTime', obj.EndTime);
%                     outputStruct = getEpochResponses_CA(cellData, curNode.epochID, ...
%                         'DeviceName', rootData.deviceName,'StartTime', obj.StartTime, 'EndTime', obj.EndTime);
                    outputStruct = getEpochResponseStats(outputStruct);
                    curNode = mergeIntoNode(curNode, outputStruct);
                else %whole cell
                    outputStruct = getEpochResponses_WC(cellData, curNode.epochID, ...
                        'DeviceName', rootData.deviceName,'StartTime', obj.StartTime, 'EndTime', obj.EndTime);
                    outputStruct = getEpochResponseStats(outputStruct);
                    curNode = mergeIntoNode(curNode, outputStruct);
                end
                
                obj = obj.set(leafIDs(i), curNode);
            end
            %% DT - copied from SpotsMultiSizeAnalysis
            %obj = obj.percolateUp(leafIDs, 'splitValue', 'pulseAmplitude');
            obj = obj.percolateUp(leafIDs, 'splitValue', 'RstarMean');
            [byEpochParamList, singleValParamList, collectedParamList] = getParameterListsByType(curNode);
            %fnames = fnames{1};
            obj = obj.percolateUp(leafIDs, byEpochParamList, byEpochParamList);
            obj = obj.percolateUp(leafIDs, singleValParamList, singleValParamList);
            obj = obj.percolateUp(leafIDs, collectedParamList, collectedParamList);
            rootData = obj.get(1);
            rootData.byEpochParamList = byEpochParamList;
            rootData.singleValParamList = singleValParamList;
            rootData.collectedParamList = collectedParamList;
            %rootData.stimParameterList = {'pulseAmplitude'};
            rootData.stimParameterList = {'RstarMean'};
            obj = obj.set(1, rootData);
            %% DT-end
        end
        
    end
    
    methods(Static)
  
        function plotMeanTrace(node, cellData)
            rootData = node.get(1);
            epochInd = node.get(2).epochID;
            if strcmp(rootData.(rootData.ampModeParam), 'Cell attached')
                cellData.plotPSTH(epochInd, 10, rootData.deviceName);
                %                 hold on
                %                 firingStart = node.get(2).meanONlatency;
                %                 firingEnd = firingStart + node.get(2).meanONenhancedDuration;
                %                 plot([firingStart firingEnd], [0 0]);
                %                 hold off
            else
                cellData.plotMeanData(epochInd, true, [], rootData.deviceName);
            end
            %title(['ON latency: ',num2str(node.get(2).meanONlatency),' ste: ',num2str(node.get(2).steONlatency)]);
        end
        
        function plotEpochData(node, cellData, device, epochIndex)
            nodeData = node.get(1);
            cellData.epochs(nodeData.epochID(epochIndex)).plotData(device);
            title(['Epoch # ' num2str(nodeData.epochID(epochIndex)) ': ' num2str(epochIndex) ' of ' num2str(length(nodeData.epochID))]);
            if strcmp(device, 'Amplifier_Ch1')
                spikesField = 'spikes_ch1';
            else
                spikesField = 'spikes_ch2';
            end
            spikeTimes = cellData.epochs(nodeData.epochID(epochIndex)).get(spikesField);
            if ~isnan(spikeTimes)
                [data, xvals] = cellData.epochs(nodeData.epochID(epochIndex)).getData(device);
                hold('on');
                plot(xvals(spikeTimes), data(spikeTimes), 'rx');
                hold('off');
            end
            
            ONendTime = cellData.epochs(nodeData.epochID(epochIndex)).get('stimTime')*1E-3; %s
            ONstartTime = 0;
            if isfield(nodeData, 'ONSETlatency') && exist('data','var')
                %draw lines here
                hold on
                firingStart = node.get(1).ONSETlatency.value(epochIndex)+ONstartTime;
                firingEnd = firingStart + node.get(1).ONSETrespDuration.value(epochIndex);
                burstBound = firingStart + node.get(1).ONSETburstDuration.value(epochIndex);
                upperLim = max(data)+50;
                lowerLim = min(data)-50;
                plot([firingStart firingStart], [upperLim lowerLim], 'LineStyle','--','Color',[1 0 0]);
                plot([firingEnd firingEnd], [upperLim lowerLim], 'LineStyle','--','Color',[1 0 0]);
                plot([burstBound burstBound], [upperLim lowerLim], 'LineStyle','--');
                hold off
            end;
            if isfield(nodeData, 'OFFSETlatency') && exist('data','var')
                %draw lines here
                hold on
                firingStart = node.get(1).OFFSETlatency.value(epochIndex)+ONendTime;
                firingEnd = firingStart + node.get(1).OFFSETrespDuration.value(epochIndex);
                burstBound = firingStart + node.get(1).OFFSETburstDuration.value(epochIndex);
                upperLim = max(data)+50;
                lowerLim = min(data)-50;
                plot([firingStart firingStart], [upperLim lowerLim], 'LineStyle','--','Color',[1 0 0]);
                plot([firingEnd firingEnd], [upperLim lowerLim], 'LineStyle','--','Color',[1 0 0]);
                plot([burstBound burstBound], [upperLim lowerLim], 'LineStyle','--');
                hold off
            end  
        end
        
        
    end
end
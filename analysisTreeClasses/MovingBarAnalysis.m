classdef MovingBarAnalysis < AnalysisTree
    properties
        StartTime = 0;
        EndTime = 0;
    end
    
    methods
        function obj = MovingBarAnalysis(cellData, dataSetName, params)
            if nargin < 3
                params.deviceName = 'Amplifier_Ch1';
            end
            if strcmp(params.deviceName, 'Amplifier_Ch1')
                params.ampModeParam = 'ampMode';
                params.holdSignalParam = 'ampHoldSignal';
            else
                params.ampModeParam = 'amp2Mode';
                params.holdSignalParam = 'amp2HoldSignal';
            end            
            
            nameStr = [cellData.savedFileName ': ' dataSetName ': MovingBarAnalysis'];            
            obj = obj.setName(nameStr);
            dataSet = cellData.savedDataSets(dataSetName);
            obj = obj.copyAnalysisParams(params);
            obj = obj.copyParamsFromSampleEpoch(cellData, dataSet, ...
                {'RstarMean', 'RstarIntensity', params.ampModeParam, params.holdSignalParam, 'barLength', 'barWidth', 'distance', 'barSpeed', 'offsetX', 'offsetY'});
            obj = obj.buildCellTree(1, cellData, dataSet, {'barAngle'});
        end
        
        function obj = doAnalysis(obj, cellData)
           rootData = obj.get(1);
            leafIDs = obj.findleaves();
            L = length(leafIDs);
            for i=1:L
                curNode = obj.get(leafIDs(i));
                if strcmp(rootData.(rootData.ampModeParam), 'Cell attached')
                    outputStruct = getEpochResponses_CA(cellData, curNode.epochID, ...
                        'DeviceName', rootData.deviceName,'StartTime', obj.StartTime, 'EndTime', obj.EndTime, ...
                        'BaselineTime', 250);
                    outputStruct = getEpochResponseStats(outputStruct);
                    curNode = mergeIntoNode(curNode, outputStruct);
                else %whole cell
                    outputStruct = getEpochResponses_WC(cellData, curNode.epochID, ...
                        'DeviceName', rootData.deviceName,'StartTime', obj.StartTime, 'EndTime', obj.EndTime, ...
                        'BaselineTime', 250);
                    outputStruct = getEpochResponseStats(outputStruct);
                    curNode = mergeIntoNode(curNode, outputStruct);
                end
                
                obj = obj.set(leafIDs(i), curNode);
            end
            
            obj = obj.percolateUp(leafIDs, ...
                'splitValue', 'barAngle');
   
        %baseline subtraction and normalization (factor out in the
            %future?
            if strcmp(rootData.(rootData.ampModeParam), 'Cell attached')
                for i=1:L %for each leaf node
                    curNode = obj.get(leafIDs(i));
                    %baseline subtraction
                    grandBaselineMean = outputStruct.baselineRate.mean_c;
                    tempStruct.ONSETrespRate_grandBaselineSubtracted = curNode.ONSETrespRate;
                    tempStruct.ONSETrespRate_grandBaselineSubtracted.value = curNode.ONSETrespRate.value - grandBaselineMean;
                    tempStruct.OFFSETrespRate_grandBaselineSubtracted = curNode.OFFSETrespRate;
                    tempStruct.OFFSETrespRate_grandBaselineSubtracted.value = curNode.OFFSETrespRate.value - grandBaselineMean;
                    tempStruct.ONSETspikes_grandBaselineSubtracted = curNode.ONSETspikes;
                    tempStruct.ONSETspikes_grandBaselineSubtracted.value = curNode.ONSETspikes.value - grandBaselineMean.*curNode.ONSETrespDuration.value; %fix nan and INF here
                    tempStruct.OFFSETspikes_grandBaselineSubtracted = curNode.OFFSETspikes;
                    tempStruct.OFFSETspikes_grandBaselineSubtracted.value = curNode.OFFSETspikes.value - grandBaselineMean.*curNode.OFFSETrespDuration.value;
                    tempStruct.ONSETspikes_400ms_grandBaselineSubtracted = curNode.spikeCount_ONSET_400ms;
                    tempStruct.ONSETspikes_400ms_grandBaselineSubtracted.value = curNode.spikeCount_ONSET_400ms.value - grandBaselineMean.*0.4; %fix nan and INF here
                    tempStruct.OFFSETspikes_400ms_grandBaselineSubtracted = curNode.OFFSETspikes;
                    tempStruct.OFFSETspikes_400ms_grandBaselineSubtracted.value = curNode.OFFSETspikes.value - grandBaselineMean.*0.4;
                    tempStruct = getEpochResponseStats(tempStruct);
                    
                    curNode = mergeIntoNode(curNode, tempStruct);
                    obj = obj.set(leafIDs(i), curNode);
                end
                
                
            end
            
            [byEpochParamList, singleValParamList, collectedParamList] = getParameterListsByType(curNode);
            obj = obj.percolateUp(leafIDs, byEpochParamList, byEpochParamList);
            obj = obj.percolateUp(leafIDs, singleValParamList, singleValParamList);
            obj = obj.percolateUp(leafIDs, collectedParamList, collectedParamList);
            
            %OSI, OSang
            rootData = obj.get(1);
            rootData = addDSIandOSI(rootData, 'barAngle');
            rootData.stimParameterList = {'barAngle'};
            rootData.byEpochParamList = byEpochParamList;
            rootData.singleValParamList = singleValParamList;
            rootData.collectedParamList = collectedParamList;
            obj = obj.set(1, rootData);   

        end
    end
    
    methods(Static)
        
        function plot_barAngleVsONSETspikes(node, cellData)
            rootData = node.get(1);
            xvals = rootData.barAngle;
            yField = rootData.ONSETspikes;
            if strcmp(yField(1).units, 's')
                yvals = yField.median_c;
            else
                yvals = yField.mean_c;
            end
            errs = yField.SEM;
            polarerror(xvals*pi/180, yvals, errs);
            hold on;
            polar([0 rootData.ONSETspikes_DSang*pi/180], [0 (100*rootData.ONSETspikes_DSI)], 'r-');
            polar([0 rootData.ONSETspikes_OSang*pi/180], [0 (100*rootData.ONSETspikes_OSI)], 'g-');
            xlabel('barAngle');
            ylabel(['ONSETspikes (' yField(1).units ')']);
            title(['DSI = ' num2str(rootData.ONSETspikes_DSI) ', DSang = ' num2str(rootData.ONSETspikes_DSang) ...
                ' and OSI = ' num2str(rootData.ONSETspikes_OSI) ', OSang = ' num2str(rootData.ONSETspikes_OSang)]);
            hold off;
        end
        
        function plot_barAngleVsONSET_avgTracePeak(node, cellData)
            rootData = node.get(1);
            xvals = rootData.barAngle;
            yField = rootData.ONSET_avgTracePeak;
            yvals = yField.value;            
            polarerror(xvals*pi/180, yvals, zeros(1,length(xvals)));
            hold on;
            polar([0 rootData.ONSET_avgTracePeak_DSang*pi/180], [0 (100*rootData.ONSET_avgTracePeak_DSI)], 'r-');
            polar([0 rootData.ONSET_avgTracePeak_OSang*pi/180], [0 (100*rootData.ONSET_avgTracePeak_OSI)], 'g-');
            xlabel('barAngle');
            ylabel(['ONSET_avgTracePeak (' yField.units ')']);
            title(['DSI = ' num2str(rootData.ONSET_avgTracePeak_DSI) ', DSang = ' num2str(rootData.ONSET_avgTracePeak_DSang) ...
                ' and OSI = ' num2str(rootData.ONSET_avgTracePeak_OSI) ', OSang = ' num2str(rootData.ONSET_avgTracePeak_OSang)]);
            hold off;
        end
        
        function plotMeanTraces(node, cellData)
            rootData = node.get(1);
            chInd = node.getchildren(1);
            L = length(chInd);
            ax = axes;
            for i=1:L
                hold(ax, 'on');
                epochInd = node.get(chInd(i)).epochID;
                if strcmp(rootData.(rootData.ampModeParam), 'Cell attached')
                    cellData.plotPSTH(epochInd, 10, rootData.deviceName, ax);
                else
                    cellData.plotMeanData(epochInd, false, [], rootData.deviceName, ax);
                end
            end
            hold(ax, 'off');
        end
        
        
    end
end


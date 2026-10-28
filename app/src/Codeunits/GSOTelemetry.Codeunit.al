namespace GMSoft.InventoryPlanning;

using System.Threading;

/// <summary>
/// Central telemetry wrapper. Event IDs are prefixed INVPL so they stay unique
/// across the GMSOFT apps that share one Application Insights resource:
/// INVPL-0001 setup created on install, INVPL-0010 setup changed,
/// INVPL-0020 scheduled run completed, INVPL-0021 scheduled run failed,
/// INVPL-0030 bulk run completed, INVPL-0040 worksheet proposals applied,
/// INVPL-0050 dynamic provider computed values for a planning run.
/// The GSO0001-GSO0003 IDs of earlier versions are retired; never reuse them.
/// All dimensions are counts, codes, flags and amounts — never customer data.
/// Publisher-scope telemetry requires applicationInsightsConnectionString to
/// be set in app.json.
/// </summary>
codeunit 73030596 "GSO Telemetry"
{
    var
        SetupCreatedMsg: Label 'Inventory Planning setup created on install', Locked = true;
        SetupChangedMsg: Label 'Inventory Planning setup changed', Locked = true;
        ScheduledRunMsg: Label 'Scheduled planning recalculation completed', Locked = true;
        ScheduledRunFailedMsg: Label 'Scheduled planning recalculation failed', Locked = true;
        BulkRunMsg: Label 'Bulk planning calculation completed', Locked = true;
        WorksheetAppliedMsg: Label 'Planning worksheet proposals applied', Locked = true;
        DynamicSupplyMsg: Label 'Dynamic provider computed planning values', Locked = true;

    /// <summary>
    /// Logs the creation of the setup record with its defaults on first install.
    /// </summary>
    procedure LogSetupCreated()
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Log('INVPL-0001', SetupCreatedMsg, Dimensions);
    end;

    /// <summary>
    /// Logs the settings after a user changed the setup card. Only flags,
    /// numbers and option values are sent.
    /// </summary>
    procedure LogSetupChanged(Setup: Record "GSO Setup")
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('historyWindowDays', Format(Setup."History Window (Days)", 0, 9));
        Dimensions.Add('minDemandObservations', Format(Setup."Min Demand Observations", 0, 9));
        Dimensions.Add('includeConsumption', Format(Setup."Include Consumption Demand", 0, 9));
        Dimensions.Add('serviceLevelPct', Format(Setup."Default Service Level %", 0, 9));
        Dimensions.Add('applySafetyStock', Format(Setup."Apply Safety Stock", 0, 9));
        Dimensions.Add('applyReorderPoint', Format(Setup."Apply Reorder Point", 0, 9));
        Dimensions.Add('applyMaxInventory', Format(Setup."Apply Maximum Inventory", 0, 9));
        Dimensions.Add('applyEOQ', Format(Setup."Apply EOQ", 0, 9));
        Dimensions.Add('eoqWriteTarget', Format(Setup."EOQ Write Target".AsInteger(), 0, 9));
        Dimensions.Add('costSource', Format(Setup."Cost Source".AsInteger(), 0, 9));
        Dimensions.Add('autoUpdatePolicy', Format(Setup."Auto-Update Policy", 0, 9));
        Dimensions.Add('dynamicProvider', Format(Setup."Dynamic Provider Enabled", 0, 9));
        Dimensions.Add('logHistory', Format(Setup."Log History", 0, 9));
        Log('INVPL-0010', SetupChangedMsg, Dimensions);
    end;

    /// <summary>
    /// Logs completion of a Job Queue run.
    /// </summary>
    procedure LogScheduledRun(Mode: Text; ItemsProcessed: Integer; DurationMs: BigInteger)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('mode', Mode);
        Dimensions.Add('itemsProcessed', Format(ItemsProcessed, 0, 9));
        Dimensions.Add('durationMs', Format(DurationMs, 0, 9));
        Log('INVPL-0020', ScheduledRunMsg, Dimensions);
    end;

    /// <summary>
    /// Logs completion of an interactive bulk run.
    /// </summary>
    procedure LogBulkRun(CalcType: Text; ItemsInScope: Integer; ItemsProcessed: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('calcType', CalcType);
        Dimensions.Add('itemsInScope', Format(ItemsInScope, 0, 9));
        Dimensions.Add('itemsProcessed', Format(ItemsProcessed, 0, 9));
        Log('INVPL-0030', BulkRunMsg, Dimensions);
    end;

    /// <summary>
    /// Kept for compatibility with version 1.0.0.0.
    /// </summary>
    [Obsolete('Use LogScheduledRun(Mode, ItemsProcessed, DurationMs).', '1.29.1.0')]
    procedure LogScheduledRun(Mode: Text; ItemsProcessed: Integer)
    begin
        LogScheduledRun(Mode, ItemsProcessed, 0);
    end;

    /// <summary>
    /// Kept for compatibility with version 1.0.0.0.
    /// </summary>
    [Obsolete('Use LogBulkRun(CalcType, ItemsInScope, ItemsProcessed).', '1.29.1.0')]
    procedure LogBulkRun(CalcType: Text; ItemsProcessed: Integer)
    begin
        LogBulkRun(CalcType, ItemsProcessed, ItemsProcessed);
    end;

    /// <summary>
    /// Logs an Apply Selected run from the planning worksheet.
    /// </summary>
    procedure LogWorksheetApplied(ItemsSelected: Integer; ItemsApplied: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('itemsSelected', Format(ItemsSelected, 0, 9));
        Dimensions.Add('itemsApplied', Format(ItemsApplied, 0, 9));
        Log('INVPL-0040', WorksheetAppliedMsg, Dimensions);
    end;

    /// <summary>
    /// Logs one fresh dynamic-provider computation (at most one per item per
    /// cache lifetime). No dimensions: the event count is the measure.
    /// </summary>
    procedure LogDynamicSupply()
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Log('INVPL-0050', DynamicSupplyMsg, Dimensions);
    end;

    /// <summary>
    /// Logs a failed scheduled run. Only the error code is sent; the error text
    /// can name items or other customer data, so it stays in the Job Queue log.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Error Handler", OnAfterLogError, '', false, false)]
    local procedure LogScheduledRunFailed(var JobQueueEntry: Record "Job Queue Entry"; var JobQueueLogEntry: Record "Job Queue Log Entry")
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        if JobQueueEntry."Object Type to Run" <> JobQueueEntry."Object Type to Run"::Codeunit then
            exit;
        if JobQueueEntry."Object ID to Run" <> Codeunit::"GSO Job Queue" then
            exit;
        Dimensions.Add('mode', UpperCase(DelChr(JobQueueEntry."Parameter String", '<>', ' ')));
        Dimensions.Add('errorCode', GetLastErrorCode());
        Log('INVPL-0021', ScheduledRunFailedMsg, Dimensions);
    end;

    local procedure Log(EventId: Text; Message: Text; Dimensions: Dictionary of [Text, Text])
    begin
        Session.LogMessage(EventId, Message, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;
}

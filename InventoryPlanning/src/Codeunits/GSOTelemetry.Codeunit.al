/// <summary>
/// Central telemetry wrapper. Event IDs: GSO0001 scheduled run completed,
/// GSO0002 bulk run completed, GSO0003 dynamic provider computed values for a
/// planning run. All dimensions are counts and codes — never customer data.
/// Publisher-scope telemetry requires applicationInsightsConnectionString to
/// be set in app.json.
/// </summary>
codeunit 73030596 "GSO Telemetry"
{
    var
        ScheduledRunMsg: Label 'Scheduled planning recalculation completed', Locked = true;
        BulkRunMsg: Label 'Bulk planning calculation completed', Locked = true;
        DynamicSupplyMsg: Label 'Dynamic provider computed planning values', Locked = true;

    /// <summary>
    /// Logs completion of a Job Queue run.
    /// </summary>
    procedure LogScheduledRun(Mode: Text; ItemsProcessed: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('mode', Mode);
        Dimensions.Add('itemsProcessed', Format(ItemsProcessed));
        Session.LogMessage('GSO0001', ScheduledRunMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    /// <summary>
    /// Logs completion of an interactive bulk run.
    /// </summary>
    procedure LogBulkRun(CalcType: Text; ItemsProcessed: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('calcType', CalcType);
        Dimensions.Add('itemsProcessed', Format(ItemsProcessed));
        Session.LogMessage('GSO0002', BulkRunMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    /// <summary>
    /// Logs one fresh dynamic-provider computation (at most one per item per
    /// cache lifetime). No dimensions: the event count is the measure.
    /// </summary>
    procedure LogDynamicSupply()
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Session.LogMessage('GSO0003', DynamicSupplyMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;
}

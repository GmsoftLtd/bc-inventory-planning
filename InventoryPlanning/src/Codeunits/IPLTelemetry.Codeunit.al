/// <summary>
/// Central telemetry wrapper. Event IDs: IPL0001 scheduled run completed,
/// IPL0002 bulk run completed, IPL0003 dynamic provider served a planning run.
/// All dimensions are counts and codes — never customer data.
/// </summary>
codeunit 50521 "IPL Telemetry"
{
    var
        CategoryTxt: Label 'Inventory Planning', Locked = true;
        ScheduledRunMsg: Label 'Scheduled planning recalculation completed', Locked = true;
        BulkRunMsg: Label 'Bulk planning calculation completed', Locked = true;

    /// <summary>
    /// Logs completion of a Job Queue run.
    /// </summary>
    procedure LogScheduledRun(Mode: Text; ItemsProcessed: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('mode', Mode);
        Dimensions.Add('itemsProcessed', Format(ItemsProcessed));
        Session.LogMessage('IPL0001', ScheduledRunMsg, Verbosity::Normal,
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
        Session.LogMessage('IPL0002', BulkRunMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;
}

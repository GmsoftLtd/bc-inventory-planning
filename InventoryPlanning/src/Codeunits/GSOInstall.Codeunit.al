/// <summary>
/// First-install wiring: creates the setup record with defaults, registers the
/// calculation log with the Retention Policy module (so the log cannot grow
/// unbounded — admins choose the retention period), and lists the setup page
/// under Manual Setup so administrators can find it.
/// </summary>
codeunit 73030594 "GSO Install"
{
    Subtype = Install;
    Permissions = tabledata "GSO Setup" = ri;

    var
        SetupTitleLbl: Label 'Inventory Planning Setup';
        SetupShortTitleLbl: Label 'Inventory Planning';
        SetupDescriptionLbl: Label 'Configure the safety stock, reorder point, EOQ and policy advisor calculators: history window, service level, ordering cost, holding rate, and how results are applied.';

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "GSO Setup";
        GSOUpgrade: Codeunit "GSO Upgrade";
    begin
        Setup.GetSetup();
        GSOUpgrade.RegisterFreshInstallTags();
        AddLogToAllowedRetentionTables();
    end;

    /// <summary>
    /// Registers the calculation log as retention-policy capable. The allowed
    /// tables list is company-scoped, so this must run per company, never per
    /// database. Also invoked by the platform's refresh event so the
    /// registration survives upgrades.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reten. Pol. Allowed Tables", 'OnRefreshAllowedTables', '', false, false)]
    local procedure OnRefreshAllowedRetentionTables()
    begin
        AddLogToAllowedRetentionTables();
    end;

    local procedure AddLogToAllowedRetentionTables()
    var
        LogEntry: Record "GSO Calculation Log";
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
    begin
        RetenPolAllowedTables.AddAllowedTable(Database::"GSO Calculation Log", LogEntry.FieldNo("Calculation DateTime"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", 'OnRegisterManualSetup', '', false, false)]
    local procedure OnRegisterManualSetup(var Sender: Codeunit "Guided Experience")
    begin
        Sender.InsertManualSetup(
            SetupTitleLbl, SetupShortTitleLbl, SetupDescriptionLbl, 5,
            ObjectType::Page, Page::"GSO Setup", Enum::"Manual Setup Category"::Inventory, '');
    end;
}

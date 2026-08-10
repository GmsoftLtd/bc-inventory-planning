/// <summary>
/// Upgrade codeunit with tagged, idempotent per-version steps. Fields added to
/// the setup singleton after a company first created it do not receive their
/// InitValue, so each new setup field gets a defaulting step here.
/// </summary>
codeunit 70455020 "IPL Upgrade"
{
    Subtype = Upgrade;
    Permissions = tabledata "IPL Setup" = rm;

    trigger OnUpgradePerCompany()
    begin
        UpgradeMaxInvTrendDefaults();
    end;

    local procedure UpgradeMaxInvTrendDefaults()
    var
        Setup: Record "IPL Setup";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetMaxInvTrendTag()) then
            exit;
        if Setup.Get() then begin
            if Setup."Trend Warning Threshold %" = 0 then
                Setup."Trend Warning Threshold %" := 30;
            Setup."Apply Maximum Inventory" := true;
            Setup.Modify();
        end;
        UpgradeTag.SetUpgradeTag(GetMaxInvTrendTag());
    end;

    /// <summary>
    /// Called from the install codeunit on fresh installs: the InitValues
    /// already hold, so mark every upgrade step as done.
    /// </summary>
    procedure RegisterFreshInstallTags()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetMaxInvTrendTag()) then
            UpgradeTag.SetUpgradeTag(GetMaxInvTrendTag());
    end;

    local procedure GetMaxInvTrendTag(): Code[250]
    begin
        exit('IPL-UPG-MaxInvTrend-20260810');
    end;
}

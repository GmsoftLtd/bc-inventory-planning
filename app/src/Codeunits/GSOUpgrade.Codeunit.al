namespace GMSoft.InventoryPlanning;

using System.Upgrade;

/// <summary>
/// Upgrade codeunit with tagged, idempotent per-version steps. Fields added to
/// the setup singleton after a company first created it do not receive their
/// InitValue, so each new setup field gets a defaulting step here.
/// </summary>
codeunit 73030595 "GSO Upgrade"
{
    Subtype = Upgrade;
    Permissions = tabledata "GSO Setup" = rm;

    trigger OnUpgradePerCompany()
    begin
        UpgradeMaxInvTrendDefaults();
    end;

    local procedure UpgradeMaxInvTrendDefaults()
    var
        Setup: Record "GSO Setup";
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

    /// <summary>
    /// Lets the platform mark every step as done when a new company is created,
    /// so the steps never run against a company that starts with InitValues.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerCompanyUpgradeTags', '', false, false)]
    local procedure RegisterPerCompanyUpgradeTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        if not PerCompanyUpgradeTags.Contains(GetMaxInvTrendTag()) then
            PerCompanyUpgradeTags.Add(GetMaxInvTrendTag());
    end;

    /// <summary>
    /// No per-database steps yet. New ones add their tag here so a fresh
    /// database marks them as done. New tags use GSO-INVPL-Step-version.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerDatabaseUpgradeTags', '', false, false)]
    local procedure RegisterPerDatabaseUpgradeTags(var PerDatabaseUpgradeTags: List of [Code[250]])
    begin
    end;

    // Released tag: never rename. It predates the GSO-INVPL-Step-version pattern.
    local procedure GetMaxInvTrendTag(): Code[250]
    begin
        exit('GSO-UPG-MaxInvTrend-20260810');
    end;
}

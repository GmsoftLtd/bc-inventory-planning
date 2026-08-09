/// <summary>
/// Upgrade codeunit, present from v1 so a versioned upgrade path exists from
/// day one. Add per-version upgrade methods with upgrade tags as the schema
/// evolves.
/// </summary>
codeunit 50520 "IPL Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    begin
        // Intentionally empty at 1.0.0.0.
    end;
}

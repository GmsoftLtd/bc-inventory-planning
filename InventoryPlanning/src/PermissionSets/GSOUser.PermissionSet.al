/// <summary>
/// Planner access: run the calculators, use the worksheet, read the log and
/// setup. Writes to Item and the log happen through the calculators' own
/// Permissions elevation, so this set stays read-only on data.
/// </summary>
permissionset 73030576 "GSO - User"
{
    Caption = 'Inventory Planning - User';
    Assignable = true;

    Permissions =
        tabledata "GSO Setup" = R,
        tabledata "GSO Calculation Log" = R,
        tabledata "GSO Planning Proposal" = RIMD,
        table "GSO Setup" = X,
        table "GSO Calculation Log" = X,
        table "GSO Planning Proposal" = X,
        codeunit "GSO Demand Statistics" = X,
        codeunit "GSO Math" = X,
        codeunit "GSO Safety Stock" = X,
        codeunit "GSO Reorder Point" = X,
        codeunit "GSO EOQ" = X,
        codeunit "GSO Policy Advisor" = X,
        codeunit "GSO Run All" = X,
        codeunit "GSO Planning Provider" = X,
        codeunit "GSO Job Queue" = X,
        codeunit "GSO Install" = X,
        codeunit "GSO Upgrade" = X,
        codeunit "GSO Telemetry" = X,
        page "GSO Setup" = X,
        page "GSO Calculation Log" = X,
        page "GSO Planning Worksheet" = X;
}

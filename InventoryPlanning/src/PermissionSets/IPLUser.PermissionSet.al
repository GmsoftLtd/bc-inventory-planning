/// <summary>
/// Planner access: run the calculators, use the worksheet, read the log and
/// setup. Writes to Item and the log happen through the calculators' own
/// Permissions elevation, so this set stays read-only on data.
/// </summary>
permissionset 70455001 "IPL - User"
{
    Caption = 'Inventory Planning - User';
    Assignable = true;

    Permissions =
        tabledata "IPL Setup" = R,
        tabledata "IPL Calculation Log" = R,
        tabledata "IPL Planning Proposal" = RIMD,
        table "IPL Setup" = X,
        table "IPL Calculation Log" = X,
        table "IPL Planning Proposal" = X,
        codeunit "IPL Demand Statistics" = X,
        codeunit "IPL Math" = X,
        codeunit "IPL Safety Stock" = X,
        codeunit "IPL Reorder Point" = X,
        codeunit "IPL EOQ" = X,
        codeunit "IPL Policy Advisor" = X,
        codeunit "IPL Run All" = X,
        codeunit "IPL Planning Provider" = X,
        codeunit "IPL Job Queue" = X,
        codeunit "IPL Install" = X,
        codeunit "IPL Upgrade" = X,
        codeunit "IPL Telemetry" = X,
        page "IPL Setup" = X,
        page "IPL Calculation Log" = X,
        page "IPL Planning Worksheet" = X;
}

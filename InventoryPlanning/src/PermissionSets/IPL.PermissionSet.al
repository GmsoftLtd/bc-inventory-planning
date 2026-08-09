/// <summary>
/// Full access to Inventory Planning: setup, calculators, worksheet and log.
/// </summary>
permissionset 50500 IPL
{
    Caption = 'Inventory Planning';
    Assignable = true;

    Permissions =
        tabledata "IPL Setup" = RIMD,
        tabledata "IPL Calculation Log" = RIMD,
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

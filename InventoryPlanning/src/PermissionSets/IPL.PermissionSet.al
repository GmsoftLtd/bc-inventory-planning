/// <summary>
/// Administrator access to Inventory Planning: everything the user set grants,
/// plus editing setup and maintaining the calculation log.
/// </summary>
permissionset 70455000 IPL
{
    Caption = 'Inventory Planning - Admin';
    Assignable = true;
    IncludedPermissionSets = "IPL - User";

    Permissions =
        tabledata "IPL Setup" = RIMD,
        tabledata "IPL Calculation Log" = RIMD;
}

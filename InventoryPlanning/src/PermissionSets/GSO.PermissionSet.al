/// <summary>
/// Administrator access to Inventory Planning: everything the user set grants,
/// plus editing setup and maintaining the calculation log.
/// </summary>
permissionset 70455000 GSO
{
    Caption = 'Inventory Planning - Admin';
    Assignable = true;
    IncludedPermissionSets = "GSO - User";

    Permissions =
        tabledata "GSO Setup" = RIMD,
        tabledata "GSO Calculation Log" = RIMD;
}

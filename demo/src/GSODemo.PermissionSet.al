namespace GMSoft.InventoryPlanning.Demo;

/// <summary>
/// Runs the demo data action. The user also needs rights to create items and
/// post item journals, as in any demo or sandbox company.
/// </summary>
permissionset 60200 "GSO Demo"
{
    Assignable = true;
    Caption = 'Inventory Planning Demo Data';
    Permissions = codeunit "GSO Demo Data" = X;
}

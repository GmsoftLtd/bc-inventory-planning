namespace GMSoft.InventoryPlanning;

/// <summary>
/// Which item field the EOQ calculator writes its result to.
/// </summary>
enum 73030578 "GSO EOQ Write Target"
{
    Extensible = false;
    Caption = 'Inventory Planning EOQ Write Target';

    value(0; "Reorder Quantity")
    {
        Caption = 'Reorder Quantity';
    }
    value(1; "Order Multiple")
    {
        Caption = 'Order Multiple';
    }
}

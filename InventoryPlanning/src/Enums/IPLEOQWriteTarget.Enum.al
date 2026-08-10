/// <summary>
/// Which item field the EOQ calculator writes its result to.
/// </summary>
enum 70455003 "IPL EOQ Write Target"
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

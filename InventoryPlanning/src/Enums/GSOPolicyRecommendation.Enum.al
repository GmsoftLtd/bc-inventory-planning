/// <summary>
/// The reordering policy the advisor recommends for an item.
/// </summary>
enum 73030577 "GSO Policy Recommendation"
{
    Extensible = true;
    Caption = 'Inventory Planning Policy Recommendation';

    value(0; "Insufficient Data")
    {
        Caption = 'Insufficient Data';
    }
    value(1; Order)
    {
        Caption = 'Order';
    }
    value(2; "Lot-for-Lot")
    {
        Caption = 'Lot-for-Lot';
    }
    value(3; "Fixed Reorder Qty.")
    {
        Caption = 'Fixed Reorder Qty.';
    }
    value(4; "Maximum Qty.")
    {
        Caption = 'Maximum Qty.';
    }
}
